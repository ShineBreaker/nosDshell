pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property bool initComplete: false
  property bool nextDarkModeState: false

  Connections {
    target: LocationService.data
    enabled: Settings.data.colorSchemes.schedulingMode == "location"
    function onWeatherChanged() {
      if (LocationService.data.weather !== null) {
        const changes = root.collectWeatherChanges(LocationService.data.weather);
        if (!root.initComplete) {
          root.initComplete = true;
          root.applyCurrentMode(changes);
        }
        root.scheduleNextMode(changes);
      }
    }
  }

  Connections {
    target: Settings.data.colorSchemes
    enabled: Settings.data.colorSchemes.schedulingMode == "manual"
    function onManualSunriseChanged() {
      const changes = root.collectManualChanges();
      root.applyCurrentMode(changes);
      root.scheduleNextMode(changes);
    }
    function onManualSunsetChanged() {
      const changes = root.collectManualChanges();
      root.applyCurrentMode(changes);
      root.scheduleNextMode(changes);
    }
  }

  Connections {
    target: Settings.data.colorSchemes
    function onSchedulingModeChanged() {
      root.update();
    }
  }

  Connections {
    target: Time
    function onResumed() {
      Logger.i("DarkModeService", "System resumed - re-evaluating dark mode");
      root.update();
      resumeRetryTimer.restart();
    }
  }

  Timer {
    id: timer
    onTriggered: {
      Settings.data.colorSchemes.darkMode = root.nextDarkModeState;
      root.update();
    }
  }

  Timer {
    id: resumeRetryTimer
    interval: 2000
    repeat: false
    onTriggered: {
      Logger.i("DarkModeService", "Resume retry - re-evaluating dark mode again");
      root.update();
    }
  }

  function init() {
    Logger.i("DarkModeService", "Service started");
    root.update();
  }

  function update() {
    if (Settings.data.colorSchemes.schedulingMode == "manual") {
      const changes = collectManualChanges();
      initComplete = true;
      applyCurrentMode(changes);
      scheduleNextMode(changes);
    } else if (Settings.data.colorSchemes.schedulingMode == "location" && LocationService.data.weather) {
      const changes = collectWeatherChanges(LocationService.data.weather);
      initComplete = true;
      applyCurrentMode(changes);
      scheduleNextMode(changes);
    } else if (Settings.data.colorSchemes.schedulingMode == "system") {
      initComplete = true;
      // A pending scheduled flip from manual/location must not race the
      // system preference.
      timer.stop();
      if (!systemReadProc.running) {
        systemReadProc.running = true;
      }
      if (!systemWatchProc.running) {
        systemWatchProc.running = true;
      }
    } else {
      if (systemReadProc.running) {
        systemReadProc.running = false;
      }
      if (systemWatchProc.running) {
        systemWatchProc.running = false;
      }
    }
  }

  // "system" mode: follow the freedesktop color-scheme preference that
  // xdg-desktop-portal reports (org.freedesktop.appearance/color-scheme).
  // Values: 0 = no preference, 1 = dark, 2 = light; the conventional
  // fallback for "no preference" is light.
  function applySystemScheme(value) {
    if (Settings.data.colorSchemes.schedulingMode !== "system") {
      return;
    }
    const dark = value === 1;
    if (Settings.data.colorSchemes.darkMode !== dark) {
      Logger.i("DarkModeService", "System color-scheme changed:", value, "-> darkMode", dark);
      Settings.data.colorSchemes.darkMode = dark;
    }
  }

  // Initial read: dbus-send --print-reply prints `variant ... uint32 N`;
  // dbus-send and dbus-monitor ship in the same `dbus` package, so the two
  // paths stay available together.
  Process {
    id: systemReadProc
    command: ["dbus-send", "--session", "--print-reply", "--dest=org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop", "org.freedesktop.portal.Settings.ReadOne", "string:org.freedesktop.appearance", "string:color-scheme"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/uint32\s+(\d+)/);
        if (m) {
          root.applySystemScheme(parseInt(m[1]));
        }
      }
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0)
                  Logger.w("DarkModeService", "color-scheme read failed (code " + exitCode + "); is xdg-desktop-portal running?");
              }
  }

  // Live watch: dbus-monitor prints SettingChanged payloads line-buffered;
  // the key line is followed by a `variant ... uint32 N` line.
  property bool _pendingSchemeLine: false
  Process {
    id: systemWatchProc
    command: ["sh", "-c", "exec dbus-monitor \"type='signal',sender='org.freedesktop.portal.Desktop',interface='org.freedesktop.portal.Settings',member='SettingChanged'\""]
    running: false
    stdout: SplitParser {
      onRead: line => {
                if (!root._pendingSchemeLine) {
                  if (line.indexOf("\"color-scheme\"") !== -1)
                    root._pendingSchemeLine = true;
                  return;
                }
                root._pendingSchemeLine = false;
                const m = line.match(/uint32\s+(\d+)/);
                if (m) {
                  root.applySystemScheme(parseInt(m[1]));
                }
              }
    }
    onExited: (exitCode, exitStatus) => {
                if (Settings.data.colorSchemes.schedulingMode == "system") {
                  Logger.w("DarkModeService", "color-scheme monitor exited with code", exitCode, "- retrying");
                  systemWatchRetry.restart();
                }
              }
  }

  Timer {
    id: systemWatchRetry
    interval: 5000
    repeat: false
    onTriggered: {
      if (Settings.data.colorSchemes.schedulingMode == "system")
        systemWatchProc.running = true;
    }
  }

  function parseTime(timeString) {
    const parts = timeString.split(":").map(Number);
    return {
      "hour": parts[0],
      "minute": parts[1]
    };
  }

  function collectManualChanges() {
    const sunriseTime = parseTime(Settings.data.colorSchemes.manualSunrise);
    const sunsetTime = parseTime(Settings.data.colorSchemes.manualSunset);

    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    const day = now.getDate();

    const yesterdaysSunset = new Date(year, month, day - 1, sunsetTime.hour, sunsetTime.minute);
    const todaysSunrise = new Date(year, month, day, sunriseTime.hour, sunriseTime.minute);
    const todaysSunset = new Date(year, month, day, sunsetTime.hour, sunsetTime.minute);
    const tomorrowsSunrise = new Date(year, month, day + 1, sunriseTime.hour, sunriseTime.minute);

    return [
          {
            "time": yesterdaysSunset.getTime(),
            "darkMode": true
          },
          {
            "time": todaysSunrise.getTime(),
            "darkMode": false
          },
          {
            "time": todaysSunset.getTime(),
            "darkMode": true
          },
          {
            "time": tomorrowsSunrise.getTime(),
            "darkMode": false
          }
        ];
  }

  function collectWeatherChanges(weather) {
    const changes = [];

    if (Date.now() < Date.parse(weather.daily.sunrise[0])) {
      // The sun has not risen yet
      changes.push({
                     "time": Date.now() - 1,
                     "darkMode": true
                   });
    }

    for (var i = 0; i < weather.daily.sunrise.length; i++) {
      changes.push({
                     "time": Date.parse(weather.daily.sunrise[i]),
                     "darkMode": false
                   });
      changes.push({
                     "time": Date.parse(weather.daily.sunset[i]),
                     "darkMode": true
                   });
    }

    return changes;
  }

  function applyCurrentMode(changes) {
    const now = Date.now();
    Logger.i("DarkModeService", `Applying mode at ${new Date(now).toLocaleString()} (${now})`);

    // changes.findLast(change => change.time < now) // not available in QML...
    let lastChange = null;
    for (var i = 0; i < changes.length; i++) {
      Logger.d("DarkModeService", `Checking change: time=${changes[i].time} (${new Date(changes[i].time).toLocaleString()}), darkMode=${changes[i].darkMode}`);
      if (changes[i].time < now) {
        lastChange = changes[i];
      }
    }

    if (lastChange) {
      Logger.i("DarkModeService", `Selected change: time=${lastChange.time}, darkMode=${lastChange.darkMode}`);
      Settings.data.colorSchemes.darkMode = lastChange.darkMode;
      Logger.d("DarkModeService", `Reset: darkmode=${lastChange.darkMode}`);
    } else {
      Logger.w("DarkModeService", "No suitable change found for current time!");
    }
  }

  function scheduleNextMode(changes) {
    const now = Date.now();
    const nextChange = changes.find(change => change.time > now);
    if (nextChange) {
      root.nextDarkModeState = nextChange.darkMode;
      timer.interval = nextChange.time - now;
      timer.restart();
      Logger.d("DarkModeService", `Scheduled: darkmode=${nextChange.darkMode} in ${timer.interval} ms`);
    }
  }
}

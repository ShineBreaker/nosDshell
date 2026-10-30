pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Theming

Singleton {
  id: root

  property bool initComplete: false
  property bool nextDarkModeState: false

  // nosd-helpers portal daemon is the external authority surface for the
  // color scheme (org.freedesktop.impl.portal.Settings + the darkman
  // nl.whynothugo.darkman compat API). Every darkMode flip — scheduling,
  // IPC, settings UI — is pushed down so portal subscribers and compat
  // consumers always observe the same state. The daemon dedupes identical
  // writes, so a portal-driven flip echoed back here cannot loop.
  Connections {
    target: Settings.data.colorSchemes
    function onDarkModeChanged() {
      root.pushPortal();
    }
  }

  // Start the daemon once the helpers binary resolves; the lockfile inside
  // `portal run` makes this idempotent when it is already running (e.g.
  // dbus-activated or autostarted earlier). Without it, Settings=… queries
  // would silently go unanswered.
  property bool _portalStarted: false
  function startPortal() {
    if (root._portalStarted || TemplateRegistry.helpersBin === "") {
      return;
    }
    root._portalStarted = true;
    Quickshell.execDetached([TemplateRegistry.helpersBin, "portal", "run"]);
    root.pushPortal();
  }

  // Policy ownership, one owner at a time: the daemon's own solar timer
  // may assert only while the shell follows it (schedulingMode "system").
  // In every other mode the shell's schedule — or the user's toggles — is
  // the authority; leaving the daemon's timer armed makes the two
  // schedulers overwrite the same state on alternating ticks, each
  // overwrite running the {dark,light}-mode.d hooks. `portal scheduler`
  // writes the flag locally (lands even before the daemon starts) and
  // pokes the running daemon so a mode change applies on the current tick.
  // Flag must land before the daemon's first scheduler tick, so this runs
  // ahead of startPortal() on both entry points.
  function pushSchedulerFlag() {
    const cmd = TemplateRegistry.helperCmd("portal", ["scheduler", Settings.data.colorSchemes.schedulingMode === "system" ? "on" : "off"]);
    if (cmd !== null)
      Quickshell.execDetached(cmd);
  }

  Connections {
    target: TemplateRegistry
    function onHelpersBinChanged() {
      root.pushSchedulerFlag();
      root.startPortal();
      root.pushHooksFlag();
    }
  }
  // TemplateRegistry may resolve helpers before this singleton is
  // instantiated, in which case no change signal fires.
  Component.onCompleted: {
    root.pushSchedulerFlag();
    root.startPortal();
    root.pushHooksFlag();
  }

  // The settings toggle reaches the daemon as a flag file — `portal hooks`
  // writes it locally, so it lands even before the daemon starts; the daemon
  // re-reads it per transition (portal.rs hooks_flag_file).
  function pushHooksFlag() {
    const cmd = TemplateRegistry.helperCmd("portal", ["hooks", Settings.data.colorSchemes.runDarkmanHooks ? "on" : "off"]);
    if (cmd === null) {
      if (!root._hooksWarned) {
        root._hooksWarned = true;
        Logger.w("DarkModeService", "nosd-helpers unavailable; darkman hook flag not written");
      }
      return;
    }
    Quickshell.execDetached(cmd);
  }
  property bool _hooksWarned: false

  Connections {
    target: Settings.data.colorSchemes
    function onRunDarkmanHooksChanged() {
      root.pushHooksFlag();
    }
  }

  function pushPortal() {
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    const cmd = TemplateRegistry.helperCmd("portal", ["set", mode]);
    if (cmd === null) {
      if (!root._portalWarned) {
        root._portalWarned = true;
        Logger.w("DarkModeService", "nosd-helpers unavailable; portal clients will not see darkMode changes");
      }
      return;
    }
    Quickshell.execDetached(cmd);
  }
  property bool _portalWarned: false

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
      root.pushSchedulerFlag();
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

  // The wall-clock time the armed timer is waiting for; 0 = nothing armed.
  // scheduleNextMode is the only writer.
  property double nextChangeTime: 0

  Timer {
    id: timer
    onTriggered: {
      // Coarse QML timers may fire before the boundary (observed 2 s early
      // on a 08:30 sunrise). Re-deriving then selects the phase that is
      // still current and writes it — a real flip — after which the
      // re-armed timer flips back at the boundary (the 08:29:58 dark ->
      // 08:30:00 light pair, fanned out through portal set -> daemon
      // transition -> hooks). Re-arm for the remainder instead; a second
      // early fire just re-arms again until the wall clock is past the
      // boundary.
      const now = Date.now();
      if (root.nextChangeTime > now) {
        timer.interval = root.nextChangeTime - now + 250;
        timer.restart();
        return;
      }
      // Re-derive from the wall clock instead of blindly writing the
      // scheduled state: the old write-then-update sequence let update()'s
      // re-derivation reverse the flip within the same tick — the igniter
      // of the dark/light oscillation at schedule boundaries. The
      // scheduled value survives only as the fallback when the weather
      // needed to re-derive is unavailable.
      if (Settings.data.colorSchemes.schedulingMode == "location" && !LocationService.data.weather) {
        Settings.data.colorSchemes.darkMode = root.nextDarkModeState;
        return;
      }
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
      root.nextChangeTime = 0;
      if (!systemReadProc.running) {
        systemReadProc.running = true;
      }
      if (!systemWatchProc.running) {
        systemWatchProc.running = true;
      }
    } else {
      // "off" (and any unknown value): the shell schedules nothing; a
      // timer armed by a previous mode must not linger.
      timer.stop();
      root.nextChangeTime = 0;
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
    Logger.i("DarkModeService", `Applying mode at ${new Date(now).toLocaleString()} (${now})`); // locale-exempt 日志非界面文案

    // changes.findLast(change => change.time < now) // not available in QML...
    // Inclusive comparison: a boundary timer firing at exactly the change
    // time (Date.now() == change.time is a real outcome with second-granular
    // schedules) must already select the new phase; a strict < would pick the
    // previous phase and write the opposite value, re-igniting the same
    // boundary fight the timer handler above fixes.
    let lastChange = null;
    for (var i = 0; i < changes.length; i++) {
      Logger.d("DarkModeService", `Checking change: time=${changes[i].time} (${new Date(changes[i].time).toLocaleString()}), darkMode=${changes[i].darkMode}`); // locale-exempt 日志非界面文案
      if (changes[i].time <= now) {
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
      root.nextChangeTime = nextChange.time;
      timer.interval = nextChange.time - now;
      timer.restart();
      Logger.d("DarkModeService", `Scheduled: darkmode=${nextChange.darkMode} in ${timer.interval} ms`);
    } else {
      root.nextChangeTime = 0;
      timer.stop();
    }
  }
}

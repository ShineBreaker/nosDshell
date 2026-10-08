import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  property var timeOptions

  signal checkWlsunset

  NToggle {
    label: I18n.tr("panels.display.night-light-enable-label")
    description: I18n.tr("panels.display.night-light-enable-description")
    checked: Settings.data.nightLight.enabled
    onToggled: checked => {
                 if (checked) {
                   root.checkWlsunset();
                 } else {
                   Settings.data.nightLight.enabled = false;
                   Settings.data.nightLight.forced = false;
                   NightLightService.apply();
                   ToastService.showNotice(I18n.tr("common.night-light"), I18n.tr("common.disabled"), "nightlight-off");
                 }
               }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // Enabled group: labelled slider/combo/toggle rows share one card with the
  // 1 px seam (settingsgroup.cpp:46, DESIGN §3.5.4). Hidden manual-schedule
  // rows drop out of the sibling scan automatically.
  ColumnLayout {
    enabled: Settings.data.nightLight.enabled
    spacing: Style.settingsGroupGap
    Layout.fillWidth: true

    NValueSlider {
      id: nightSlider
      Layout.fillWidth: true
      label: I18n.tr("panels.display.night-light-temperature-night")
      description: I18n.tr("panels.display.night-light-temperature-night-description")
      from: 1000
      to: 6500
      stepSize: 1
      value: Settings.data.nightLight.nightTemp
      defaultValue: Settings.getDefaultValue("nightLight.nightTemp")
      showReset: true
      text: Math.round(value) + "K"

      onMoved: v => {
                 var dayTemp = parseInt(Settings.data.nightLight.dayTemp);
                 var x = Math.round(v);
                 if (!isNaN(dayTemp)) {
                   var maxNight = dayTemp - 500;
                   x = Math.min(maxNight, Math.max(1000, x));
                 } else {
                   x = Math.max(1000, x);
                 }
                 Settings.data.nightLight.nightTemp = x;
               }
    }

    NValueSlider {
      id: daySlider
      Layout.fillWidth: true
      label: I18n.tr("panels.display.night-light-temperature-day")
      description: I18n.tr("panels.display.night-light-temperature-day-description")
      from: 1000
      to: 6500
      stepSize: 1
      value: Settings.data.nightLight.dayTemp
      defaultValue: Settings.getDefaultValue("nightLight.dayTemp")
      showReset: true
      text: Math.round(value) + "K"

      onMoved: v => {
                 var nightTemp = parseInt(Settings.data.nightLight.nightTemp);
                 var x = Math.round(v);
                 if (!isNaN(nightTemp)) {
                   var minDay = nightTemp + 500;
                   x = Math.max(minDay, Math.min(6500, x));
                 } else {
                   x = Math.min(6500, x);
                 }
                 Settings.data.nightLight.dayTemp = x;
               }
    }

    NToggle {
      label: I18n.tr("panels.display.night-light-auto-schedule-label")
      description: I18n.tr("panels.display.night-light-auto-schedule-description", {
                             "location": LocationService.stableName
                           })
      checked: Settings.data.nightLight.autoSchedule
      onToggled: checked => Settings.data.nightLight.autoSchedule = checked
    }

    NHeader {
      label: I18n.tr("panels.display.night-light-manual-schedule-label")
      description: I18n.tr("panels.display.night-light-manual-schedule-description")
      visible: !Settings.data.nightLight.autoSchedule && !Settings.data.nightLight.forced
    }

    NComboBox {
      label: I18n.tr("panels.display.night-light-manual-schedule-sunrise")
      model: root.timeOptions
      currentKey: Settings.data.nightLight.manualSunrise
      placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-start")
      onSelected: key => Settings.data.nightLight.manualSunrise = key
      visible: !Settings.data.nightLight.autoSchedule && !Settings.data.nightLight.forced
    }

    NComboBox {
      label: I18n.tr("panels.display.night-light-manual-schedule-sunset")
      model: root.timeOptions
      currentKey: Settings.data.nightLight.manualSunset
      placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-stop")
      onSelected: key => Settings.data.nightLight.manualSunset = key
      visible: !Settings.data.nightLight.autoSchedule && !Settings.data.nightLight.forced
    }

    NToggle {
      label: I18n.tr("panels.display.night-light-force-activation-label")
      description: I18n.tr("panels.display.night-light-force-activation-description")
      checked: Settings.data.nightLight.forced
      onToggled: checked => {
                   Settings.data.nightLight.forced = checked;
                   if (checked && !Settings.data.nightLight.enabled) {
                     root.checkWlsunset();
                   } else {
                     NightLightService.apply();
                   }
                 }
    }
  }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  // Helper functions to update arrays immutably
  function addMonitor(list, name) {
    const arr = (list || []).slice();
    if (!arr.includes(name))
      arr.push(name);
    return arr;
  }
  function removeMonitor(list, name) {
    return (list || []).filter(function (n) {
      return n !== name;
    });
  }

  // File pickers for sound sub-tab
  function openUnifiedSoundPicker() {
    unifiedSoundFilePicker.open();
  }
  function openLowSoundPicker() {
    lowSoundFilePicker.open();
  }
  function openNormalSoundPicker() {
    normalSoundFilePicker.open();
  }
  function openCriticalSoundPicker() {
    criticalSoundFilePicker.open();
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: false // this is too cramped on this tab to split evenly
    currentIndex: tabView.currentIndex

    NSubTabsPane {
      bar: subTabBar
      NSubTabsPane.Title {
        text: I18n.tr("common.appearance")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.duration")
        shown: Settings.data.notifications.enabled
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.history")
        shown: Settings.data.notifications.enabled
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.sound")
        shown: Settings.data.notifications.enabled
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.toast")
        shown: Settings.data.notifications.enabled
      }
      NSubTabsPane.Title {
        text: I18n.tr("panels.notifications.rules-tab")
        shown: Settings.data.notifications.enabled
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    GeneralSubTab {
      addMonitor: root.addMonitor
      removeMonitor: root.removeMonitor
    }
    DurationSubTab {}
    HistorySubTab {}
    SoundSubTab {
      onOpenUnifiedPicker: root.openUnifiedSoundPicker()
      onOpenLowPicker: root.openLowSoundPicker()
      onOpenNormalPicker: root.openNormalSoundPicker()
      onOpenCriticalPicker: root.openCriticalSoundPicker()
    }
    ToastSubTab {}
    RulesSubTab {}
  }

  // Those pages have no switch of their own. When notifications are off,
  // the tabs hide (DESIGN §3.5.3) and the view returns to the switch.
  readonly property bool notificationsOn: Settings.data.notifications.enabled !== false
  onNotificationsOnChanged: {
    if (!notificationsOn && tabView.currentIndex !== 0)
      tabView.currentIndex = 0;
  }

  // File Pickers for Sound Files
  NFilePicker {
    id: unifiedSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-unified-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    const soundPath = paths[0];
                    Settings.data.notifications.sounds.normalSoundFile = soundPath;
                    Settings.data.notifications.sounds.lowSoundFile = soundPath;
                    Settings.data.notifications.sounds.criticalSoundFile = soundPath;
                  }
                }
  }

  NFilePicker {
    id: lowSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-low-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.notifications.sounds.lowSoundFile = paths[0];
                  }
                }
  }

  NFilePicker {
    id: normalSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-normal-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.notifications.sounds.normalSoundFile = paths[0];
                  }
                }
  }

  NFilePicker {
    id: criticalSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-critical-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.notifications.sounds.criticalSoundFile = paths[0];
                  }
                }
  }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../../../Helpers/QtObj2JS.js" as QtObj2JS
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  // Profile section
  // The section head is the NTabBar strip in GeneralTab.qml (groupMode), which
  // heads this sub-tab; a second NHeader here would just repeat it.
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true

    // Identity hero row: avatar + display name inside the group's first row —
    // a framed profile card like the Apple-ID row, not text floating on the
    // panel background.
    NDccRow {
      Layout.fillWidth: true
      spacing: Style.marginL

      NImageRounded {
        Layout.preferredWidth: 56 * Style.uiScaleRatio
        Layout.preferredHeight: width
        radius: width / 2
        imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
        fallbackIcon: "person"
        borderColor: Colors.accent
        borderWidth: Style.borderM
        Layout.alignment: Qt.AlignVCenter
      }

      NText {
        text: HostService.displayName
        pointSize: Style.fontSizeM
        color: Colors.accent
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }
    }

    // The field is a normal settings row under the identity block, not
    // beside the avatar — a row surface keeps it aligned with the others.
    NTextInputButton {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.profile-picture-label")
      // Read-only basename: the raw stored path is an internal detail;
      // picking a different avatar goes through the file picker button.
      inputReadOnly: true
      text: {
        const path = Settings.data.general.avatarImage;
        return path ? path.split("/").pop() : "";
      }
      placeholderText: '~/.face' // don't translate path
      buttonIcon: "photo"
      buttonTooltip: I18n.tr("panels.general.profile-tooltip")
      onButtonClicked: {
        avatarPicker.openFilePicker();
      }
    }

    NFilePicker {
      id: avatarPicker
      title: I18n.tr("panels.general.profile-select-avatar")
      selectionMode: "files"
      initialPath: Settings.preprocessPath(Settings.data.general.avatarImage).substr(0, Settings.preprocessPath(Settings.data.general.avatarImage).lastIndexOf("/")) || Quickshell.env("HOME")
      nameFilters: ImageCacheService.basicImageFilters
      onAccepted: paths => {
        if (paths.length > 0) {
          Settings.data.general.avatarImage = paths[0];
        }
      }
    }
  }

  // Fonts

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // Font configuration section
  NSettingsGroup {
    Layout.fillWidth: true

    NSearchableComboBox {
      label: I18n.tr("panels.general.fonts-default-label")
      model: FontService.availableFonts
      currentKey: Settings.data.ui.fontDefault
      placeholder: I18n.tr("panels.general.fonts-default-placeholder")
      searchPlaceholder: I18n.tr("panels.general.fonts-default-search-placeholder")
      popupHeight: 420
      defaultValue: Settings.getDefaultValue("ui.fontDefault")
      settingsPath: "ui.fontDefault"
      onSelected: key => Settings.data.ui.fontDefault = key
    }

    NSearchableComboBox {
      label: I18n.tr("panels.general.fonts-monospace-label")
      model: FontService.monospaceFonts
      currentKey: Settings.data.ui.fontFixed
      placeholder: I18n.tr("panels.general.fonts-monospace-placeholder")
      searchPlaceholder: I18n.tr("panels.general.fonts-monospace-search-placeholder")
      popupHeight: 320
      defaultValue: Settings.getDefaultValue("ui.fontFixed")
      settingsPath: "ui.fontFixed"
      onSelected: key => Settings.data.ui.fontFixed = key
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.fonts-default-scale-label")
      from: 0.75
      to: 1.25
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.fontDefaultScale
      defaultValue: Settings.getDefaultValue("ui.fontDefaultScale")
      onMoved: value => Settings.data.ui.fontDefaultScale = value
      text: Math.floor(Settings.data.ui.fontDefaultScale * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.fonts-monospace-scale-label")
      from: 0.75
      to: 1.25
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.fontFixedScale
      defaultValue: Settings.getDefaultValue("ui.fontFixedScale")
      onMoved: value => Settings.data.ui.fontFixedScale = value
      text: Math.floor(Settings.data.ui.fontFixedScale * 100) + "%"
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 3: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.reverse-scrolling-label")
      checked: Settings.data.general.reverseScroll
      defaultValue: Settings.getDefaultValue("general.reverseScroll")
      onToggled: checked => Settings.data.general.reverseScroll = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.smooth-scrolling-label")
      checked: Settings.data.general.smoothScrollEnabled
      defaultValue: Settings.getDefaultValue("general.smoothScrollEnabled")
      onToggled: checked => Settings.data.general.smoothScrollEnabled = checked
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 4: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  // Action rows: one clickable row per action, icon + label (the
  // custom-add pattern in Idle/CustomSubTab.qml).
  NSettingsGroup {
    Layout.fillWidth: true

    NDccRow {
      Layout.fillWidth: true
      clickable: true
      onClicked: {
        var targetScreen = PanelService.openedPanel ? PanelService.openedPanel.screen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        if (!targetScreen) {
          return;
        }
        var setupPanel = PanelService.getPanel("setupWizardPanel", targetScreen);
        if (setupPanel) {
          setupPanel.telemetryOnlyMode = false;
          setupPanel.open();
        } else {
          Qt.callLater(() => {
            var sp = PanelService.getPanel("setupWizardPanel", targetScreen);
            if (sp) {
              sp.telemetryOnlyMode = false;
              sp.open();
            }
          });
        }
      }
      NIcon {
        icon: "wand"
        color: Colors.onShell
      }
      NText {
        text: I18n.tr("panels.general.launch-setup-wizard")
        Layout.fillWidth: true
      }
    }

    NDccRow {
      Layout.fillWidth: true
      clickable: true
      onClicked: {
        Qt.openUrlExternally("https://github.com/ShineBreaker/nosDshell");
      }
      NIcon {
        icon: "external-link"
        color: Colors.onShell
      }
      NText {
        text: I18n.tr("common.documentation")
        Layout.fillWidth: true
      }
    }

    NDccRow {
      Layout.fillWidth: true
      clickable: true
      onClicked: {
        var plainData = QtObj2JS.qtObjectToPlainObject(Settings.data);
        var json = JSON.stringify(plainData, null, 2);
        Quickshell.execDetached(["wl-copy", json]);
        ToastService.showNotice(I18n.tr("panels.general.settings-copied"));
      }
      NIcon {
        icon: "json"
        color: Colors.onShell
      }
      NText {
        text: I18n.tr("panels.general.copy-settings")
        Layout.fillWidth: true
      }
    }
  }
}

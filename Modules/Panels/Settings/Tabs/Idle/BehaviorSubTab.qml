import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Power
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // Master enable

  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.idle.enable-label")
      description: I18n.tr("panels.idle.enable-description")
      checked: Settings.data.idle.enabled
      defaultValue: Settings.getDefaultValue("idle.enabled")
      onToggled: checked => Settings.data.idle.enabled = checked
    }

    // Live idle status
    NDccRow {
      Layout.fillWidth: true
      enabled: Settings.data.idle.enabled
      interactive: false
      visible: IdleService.nativeIdleMonitorAvailable

      NLabel {
        label: I18n.tr("panels.idle.status-label")
        description: I18n.tr("panels.idle.status-description")
        labelWeight: Style.fontWeightRegular
        Layout.fillWidth: true
      }

      NText {
        Layout.alignment: Qt.AlignVCenter
        text: IdleService.idleSeconds > 0 ? I18n.trp("common.second", IdleService.idleSeconds) : I18n.tr("common.active")
        family: Settings.data.ui.fontFixed
        pointSize: Style.fontSizeM
        color: IdleService.idleSeconds > 0 ? Color.accent : Color.onShellTertiary
      }
    }

    NDccRow {
      Layout.fillWidth: true
      interactive: false
      visible: !IdleService.nativeIdleMonitorAvailable

      NLabel {
        description: I18n.tr("panels.idle.unavailable")
        Layout.fillWidth: true
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 2: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    IdleCommandEditPopup {
      id: editPopup
      parent: Overlay.overlay
    }

    function openEdit(actionName, cmdVal, resumeCmdVal, onSaveCmd, onSaveResume) {
      editPopup.editIndex = -1;
      editPopup.showCommand = true;
      editPopup.showTimeout = false;
      editPopup.titleText = I18n.tr("common.edit") + " " + actionName;
      editPopup.timeoutValue = 0;
      editPopup.commandValue = cmdVal;
      editPopup.resumeCommandValue = resumeCmdVal;

      try {
        editPopup.saved.disconnect(editPopup._savedSlot);
      } catch (e) {}

      editPopup._savedSlot = function (timeout, cmd, resumeCmd, name) {
        onSaveCmd(cmd);
        onSaveResume(resumeCmd);
      };

      editPopup.saved.connect(editPopup._savedSlot);
      editPopup.open();
    }

    // Timeout spinboxes and resume commands
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap
      enabled: Settings.data.idle.enabled

      NHeader {
        label: I18n.tr("panels.idle.timeouts-label")
        description: I18n.tr("panels.idle.timeouts-description")
      }

      DefaultActionRow {
        actionName: I18n.tr("panels.idle.screen-off-label")
        actionDescription: I18n.tr("panels.idle.screen-off-description")
        timeoutValue: Settings.data.idle.screenOffTimeout
        defaultValue: Settings.getDefaultValue("idle.screenOffTimeout")
        command: Settings.data.idle.screenOffCommand
        resumeCommand: Settings.data.idle.resumeScreenOffCommand
        onActionTimeoutChanged: val => Settings.data.idle.screenOffTimeout = val
        onActionCommandChanged: cmd => {
                                  Settings.data.idle.screenOffCommand = cmd;
                                  Settings.saveImmediate();
                                }
        onActionResumeCommandChanged: cmd => {
                                        Settings.data.idle.resumeScreenOffCommand = cmd;
                                        Settings.saveImmediate();
                                      }
      }

      DefaultActionRow {
        actionName: I18n.tr("panels.idle.lock-label")
        actionDescription: I18n.tr("panels.idle.lock-description")
        timeoutValue: Settings.data.idle.lockTimeout
        defaultValue: Settings.getDefaultValue("idle.lockTimeout")
        command: Settings.data.idle.lockCommand
        resumeCommand: Settings.data.idle.resumeLockCommand
        onActionTimeoutChanged: val => Settings.data.idle.lockTimeout = val
        onActionCommandChanged: cmd => {
                                  Settings.data.idle.lockCommand = cmd;
                                  Settings.saveImmediate();
                                }
        onActionResumeCommandChanged: cmd => {
                                        Settings.data.idle.resumeLockCommand = cmd;
                                        Settings.saveImmediate();
                                      }
      }

      DefaultActionRow {
        actionName: I18n.tr("common.suspend")
        actionDescription: I18n.tr("panels.idle.suspend-description")
        timeoutValue: Settings.data.idle.suspendTimeout
        defaultValue: Settings.getDefaultValue("idle.suspendTimeout")
        command: Settings.data.idle.suspendCommand
        resumeCommand: Settings.data.idle.resumeSuspendCommand
        onActionTimeoutChanged: val => Settings.data.idle.suspendTimeout = val
        onActionCommandChanged: cmd => {
                                  Settings.data.idle.suspendCommand = cmd;
                                  Settings.saveImmediate();
                                }
        onActionResumeCommandChanged: cmd => {
                                        Settings.data.idle.resumeSuspendCommand = cmd;
                                        Settings.saveImmediate();
                                      }
      }

      NSpinBox {
        label: I18n.tr("panels.idle.fade-duration-label")
        description: I18n.tr("panels.idle.fade-duration-description")
        from: 1
        to: 60
        suffix: "s"
        value: Settings.data.idle.fadeDuration
        defaultValue: Settings.getDefaultValue("idle.fadeDuration")
        onValueChanged: Settings.data.idle.fadeDuration = value
      }
    }
  }

  // A spin row plus its "edit commands" gear — the button drops into the
  // NSpinBox's own dcc row content (NDccRow forwards children there), so the
  // gear shares the row chrome instead of floating outside it.
  component DefaultActionRow: NSpinBox {
    id: rowRoot
    Layout.fillWidth: true

    property string actionName
    property string actionDescription
    property string command
    property string resumeCommand
    property alias timeoutValue: rowRoot.value

    signal actionTimeoutChanged(int newValue)
    signal actionCommandChanged(string newCmd)
    signal actionResumeCommandChanged(string newCmd)

    label: rowRoot.actionName
    description: rowRoot.actionDescription
    from: 0
    to: 86400
    suffix: "s"
    onValueChanged: rowRoot.actionTimeoutChanged(value)

    NIconButton {
      Layout.alignment: Qt.AlignVCenter
      icon: "settings"
      tooltipText: I18n.tr("common.edit")
      onClicked: root.openEdit(rowRoot.actionName, rowRoot.command, rowRoot.resumeCommand, rowRoot.actionCommandChanged, rowRoot.actionResumeCommandChanged)
    }
  }
}

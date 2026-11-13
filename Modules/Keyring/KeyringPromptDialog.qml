import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Keyring
import qs.Services.UI
import qs.Widgets

// Keyring unlock dialog (DESIGN §3.11): the same DDialog shape as the polkit
// prompt — 380 px wide, 48 px icon, 24 px password field, an inline error line
// instead of a toast, and a bottom button strip with 1 px separators. Backed
// by libgcr's SystemPrompter through KeyringPrompterService; the exchange
// protocol never leaves the C++ side, so this file only collects a password or
// a yes/no.
PanelWindow {
  id: root

  readonly property bool isConfirm: KeyringPrompterService.promptType === "confirm"
  readonly property bool hasWarning: KeyringPrompterService.warning !== "" && !root.warningDismissed
  // AuthDialog.cpp: a wrong password puts the field in alert state; typing
  // again clears it. warning belongs to the caller, so dismissal is local.
  property bool warningDismissed: false

  visible: KeyringPrompterService.isActive
  screen: PanelService.findScreenForPanels()

  // Layer above everything else (critical system prompt)
  WlrLayershell.namespace: "nosdshell-keyring"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  color: "transparent"
  implicitWidth: Style.dialogNarrowWidth
  implicitHeight: contentColumn.implicitHeight

  // maskShell assumes a blurred backdrop (DESIGN §1.2): publish the dialog
  // rect so the compositor follows it exactly.
  BackgroundEffect.blurRegion: dialogBlurRegion.region

  NSurfaceRegion {
    id: dialogBlurRegion
    trackedItem: dialogBackground
    radius: Style.radiusWindow
    activeWhen: Colors.blurActive && root.visible
  }

  Connections {
    target: KeyringPrompterService

    // Every retry reuses the same prompt object on the backend side, so a new
    // round always arrives as isActive flipping back on: reset the field and
    // the error line here rather than relying on a component reload.
    function onIsActiveChanged() {
      if (!KeyringPrompterService.isActive)
        return;
      passwordInput.text = "";
      root.warningDismissed = false;
      Qt.callLater(function () {
        passwordInput.forceActiveFocus();
      });
    }
  }

  Rectangle {
    id: dialogBackground
    anchors.fill: parent
    radius: Style.radiusWindow
    color: Colors.maskShell
    border.color: root.hasWarning ? Colors.alert : Colors.borderShell
    border.width: Style.borderM

    Behavior on border.color {
      enabled: !Colors.isTransitioning
      NColorAnim {
        duration: Style.motionSwitch
        curve: "swift"
      }
    }
  }

  FocusScope {
    anchors.fill: parent
    focus: true

    Keys.onPressed: function (event) {
      if (event.key === Qt.Key_Escape) {
        KeyringPrompterService.cancel();
        event.accepted = true;
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.submit();
        event.accepted = true;
      }
    }

    ColumnLayout {
      id: contentColumn
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 0

      // ── Header + fields (padded) ────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Style.marginL
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NImageRounded {
            Layout.preferredWidth: Style.dialogIconSize
            Layout.preferredHeight: Style.dialogIconSize
            Layout.alignment: Qt.AlignTop
            imagePath: ""
            fallbackIcon: "dialog-password"
            borderWidth: 0
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
              text: KeyringPrompterService.message || I18n.tr("keyring.unlock")
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightMedium
              color: Colors.onShell
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }

            NText {
              visible: text !== ""
              text: KeyringPrompterService.description
              pointSize: Style.fontSizeXS
              color: Colors.onShellTertiary
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
          }
        }

        // Password field — the same 24 px box as the polkit dialog.
        Rectangle {
          id: passwordFrame
          visible: !root.isConfirm
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(24 * Style.uiScaleRatio)
          radius: Style.settingsFieldRadius
          color: Colors.overlay("field")
          border.color: root.hasWarning ? Colors.alert : (passwordInput.activeFocus ? Colors.accent : "transparent")
          border.width: Style.borderS

          TextField {
            id: passwordInput
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            verticalAlignment: TextInput.AlignVCenter
            topPadding: 0
            bottomPadding: 0
            leftPadding: 0
            rightPadding: 0
            background: null
            echoMode: TextInput.Password
            placeholderText: KeyringPrompterService.passwordNew ? I18n.tr("keyring.new-password") : I18n.tr("keyring.password")
            placeholderTextColor: Colors.onShellTertiary
            color: Colors.onShell
            font.family: Settings.data.ui.fontDefault
            font.pointSize: Style.fontSizeS * Style.uiScaleRatio
            selectByMouse: true

            onAccepted: root.submit()
            onTextChanged: {
              // The alert clears as soon as the user types again.
              root.warningDismissed = true;
            }
          }
        }

        // Inline error under the field (AuthDialog's ErrorTooltip role).
        NText {
          visible: root.hasWarning
          text: KeyringPrompterService.warning
          pointSize: Style.fontSizeS
          color: Colors.alert
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }
      }

      // ── Button strip: full width, 1 px separators (§3.11) ────────────────
      Rectangle {
        Layout.fillWidth: true
        height: Math.max(1, Style.borderM)
        color: Colors.separator
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.dialogButtonHeight
        spacing: 0

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Style.radiusRow
            color: cancelHover.hovered ? Colors.overlay("hover") : "transparent"
          }

          HoverHandler {
            id: cancelHover
          }

          NText {
            anchors.centerIn: parent
            text: I18n.tr("common.cancel")
            pointSize: Style.fontSizeM
            color: Colors.onShell
          }

          MouseArea {
            anchors.fill: parent
            onClicked: KeyringPrompterService.cancel()
          }
        }

        Rectangle {
          Layout.fillHeight: true
          Layout.topMargin: Style.marginS
          Layout.bottomMargin: Style.marginS
          width: Math.max(1, Style.borderM)
          color: Colors.separator
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Style.radiusRow
            color: confirmHover.hovered ? Colors.overlay("hover") : "transparent"
          }

          HoverHandler {
            id: confirmHover
          }

          NText {
            anchors.centerIn: parent
            text: I18n.tr("common.confirm")
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightMedium
            color: Colors.accent
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.submit()
          }
        }
      }
    }
  }

  function submit() {
    if (root.isConfirm) {
      KeyringPrompterService.confirm();
      return;
    }
    if (passwordInput.text === "")
      return;
    var value = passwordInput.text;
    passwordInput.text = "";
    KeyringPrompterService.respond(value);
  }
}

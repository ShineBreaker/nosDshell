import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Polkit
import qs.Services.UI
import qs.Widgets

// DDE polkit authentication dialog (DESIGN §3.11): DDialog shape after
// gxde-polkit-agent/AuthDialog.cpp — 380 px wide, 48 px app icon, admin-user
// combo only when multiple identities are offered, 24 px password field,
// wrong password sets the field's alert state and shows an inline error line
// instead of a toast, bottom button strip spans the dialog with 1 px
// separators and an accent recommended action.
PanelWindow {
  id: root

  readonly property var flow: PolkitService.flow
  visible: PolkitService.isActive && flow !== null
  screen: PanelService.findScreenForPanels()

  // Layer above everything else (critical system prompt)
  WlrLayershell.namespace: "nosdshell-polkit"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  color: "transparent"
  implicitWidth: 380 * Style.uiScaleRatio
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

  property string resolvedMessage: ""
  property var transientMatch: null
  // Request token for the transient-name resolution: the shared Process
  // cannot apply a new command while the previous cat is still running
  // (setting running=true on a running quickshell Process is a no-op), so
  // each request advances _resolveToken, stream output is tagged with the
  // token the process actually serves and stale output is dropped instead
  // of being spliced into the newer request's message.
  property int _resolveToken: 0
  property int _runningToken: 0
  property bool _resolveBusy: false
  // AuthDialog.cpp: a wrong password puts the field in alert state; typing
  // again clears it. flow.failed is readonly, so dismissal is tracked here.
  property bool errorDismissed: false

  onFlowChanged: {
    root.errorDismissed = false;
    resolveTransientServiceName(flow?.message);
  }

  // Resolve transient service names (run-PID-random.service) to the actual
  // command so the prompt tells the user what is really asking for auth.
  Process {
    id: cmdLineProcess
    command: ["cat", "/proc/0/cmdline"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: function () {
        // Drop output of an outdated request: the process may still be the
        // previous one when a newer flow replaced the match under it.
        if (root._runningToken !== root._resolveToken)
          return;
        var args = this.text.split(String.fromCharCode(0)).filter(function (s) {
          return s.length > 0;
        });
        if (args.length > 0 && root.transientMatch) {
          var resolvedCmd = args.join(' ');
          var isCommand = args.length > 1 || args[0].includes('/');
          root.resolvedMessage = root.resolvedMessage.replace(root.transientMatch[0], resolvedCmd);
          if (isCommand) {
            root.resolvedMessage = root.resolvedMessage.replace(/transient unit/i, 'run command');
          }
        }
      }
    }

    onExited: {
      root._resolveBusy = false;
      // A request that arrived while the previous cat was still running
      // never started (see _launchResolve); replay it now that the process
      // slot is free.
      if (root._runningToken !== root._resolveToken && root.transientMatch)
        Qt.callLater(root._launchResolve);
    }
  }

  function resolveTransientServiceName(message) {
    if (!message) {
      root.resolvedMessage = "";
      root.transientMatch = null;
      return;
    }
    var match = message.match(/run-p?(\d+)-[^.]+\.service/);
    root.resolvedMessage = message;
    root.transientMatch = match;
    if (!match)
      return;
    root._resolveToken++;
    _launchResolve();
  }

  function _launchResolve() {
    // transientMatch may have been cleared while this was queued via
    // Qt.callLater (the flow went away in between) — nothing to resolve then.
    if (root._resolveBusy || !root.transientMatch || root._runningToken === root._resolveToken)
      return;
    root._runningToken = root._resolveToken;
    root._resolveBusy = true;
    cmdLineProcess.command = ["cat", "/proc/" + root.transientMatch[1] + "/cmdline"];
    cmdLineProcess.running = true;
  }

  Rectangle {
    id: dialogBackground
    anchors.fill: parent
    radius: Style.radiusWindow
    color: Colors.maskShell
    border.color: (root.flow && ((root.flow.failed && !root.errorDismissed) || root.flow.supplementaryIsError)) ? Colors.alert : Colors.borderShell
    border.width: Style.borderM

    Behavior on border.color {
      enabled: !Colors.isTransitioning
      ColorAnimation {
        duration: Style.motionSwitch
      }
    }
  }

  FocusScope {
    anchors.fill: parent
    focus: true

    Keys.onPressed: function (event) {
      if (!root.flow)
        return;
      if (event.key === Qt.Key_Escape) {
        root.flow.cancelAuthenticationRequest();
        event.accepted = true;
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.submitPassword();
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
        Layout.topMargin: Style.marginL
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NImageRounded {
            Layout.preferredWidth: 48 * Style.uiScaleRatio
            Layout.preferredHeight: 48 * Style.uiScaleRatio
            Layout.alignment: Qt.AlignTop
            imagePath: (root.flow && root.flow.iconName) ? Quickshell.iconPath(root.flow.iconName) : ""
            fallbackIcon: "lock"
            borderWidth: 0
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
              text: root.resolvedMessage || (root.flow ? root.flow.message : I18n.tr("authentication.required"))
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightMedium
              color: Colors.onShell
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }

            NText {
              text: root.flow ? root.flow.actionId : ""
              pointSize: Style.fontSizeXS
              color: Colors.onShellTertiary
              wrapMode: Text.Wrap
              Layout.fillWidth: true
              visible: text !== ""
            }
          }
        }

        // Supplementary message (error or prompt text from the conversation)
        NText {
          visible: root.flow && root.flow.supplementaryMessage !== ""
          text: root.flow ? root.flow.supplementaryMessage : ""
          pointSize: Style.fontSizeS
          color: (root.flow && root.flow.supplementaryIsError) ? Colors.alert : Colors.onShellSecondary
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }

        // Identity picker — AuthDialog.cpp: only shown when more than one
        // identity is offered.
        NComboBox {
          visible: (root.flow?.identities?.length ?? 0) > 1
          Layout.fillWidth: true
          model: {
            var list = [];
            var ids = root.flow?.identities ?? [];
            for (var i = 0; i < ids.length; i++) {
              list.push({
                          "key": String(i),
                          "name": ids[i].displayName || ids[i].name || String(ids[i].id)
                        });
            }
            return list;
          }
          currentKey: {
            var ids = root.flow?.identities ?? [];
            for (var i = 0; i < ids.length; i++) {
              if (ids[i] === root.flow?.selectedIdentity)
                return String(i);
            }
            return "0";
          }
          onSelected: key => {
                        if (root.flow && root.flow.identities) {
                          var idx = parseInt(key);
                          if (idx >= 0 && idx < root.flow.identities.length)
                          root.flow.selectedIdentity = root.flow.identities[idx];
                        }
                      }
        }

        // Password field — AuthDialog.cpp: fixed 24 px, Password echo, alert
        // state on a wrong password.
        Rectangle {
          id: passwordFrame
          visible: root.flow && root.flow.isResponseRequired
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(24 * Style.uiScaleRatio)
          radius: Style.settingsFieldRadius
          color: Colors.overlay("field")
          border.color: (root.flow && root.flow.failed && !root.errorDismissed) ? Colors.alert : (passwordInput.activeFocus ? Colors.accent : "transparent")
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
            echoMode: (root.flow && root.flow.responseVisible) ? TextInput.Normal : TextInput.Password
            placeholderText: root.flow ? root.flow.inputPrompt : ""
            placeholderTextColor: Colors.onShellTertiary
            color: Colors.onShell
            font.family: Settings.data.ui.fontDefault
            font.pointSize: Style.fontSizeS * Style.uiScaleRatio
            selectByMouse: true

            onAccepted: root.submitPassword()
            onTextChanged: {
              // AuthDialog clears the alert as soon as the user types again.
              root.errorDismissed = true;
            }
          }
        }

        // Inline error under the field (AuthDialog's ErrorTooltip role) —
        // only when the server didn't already send a supplementary error.
        NText {
          visible: root.flow && root.flow.failed && !root.errorDismissed && !(root.flow.supplementaryIsError && root.flow.supplementaryMessage !== "")
          text: I18n.tr("authentication.wrong-password")
          pointSize: Style.fontSizeS
          color: Colors.alert
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
        Layout.preferredHeight: Math.round(40 * Style.uiScaleRatio)
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
            onClicked: {
              if (root.flow)
                root.flow.cancelAuthenticationRequest();
            }
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
            color: (root.flow && root.flow.isResponseRequired) ? Colors.accent : Colors.onShellTertiary
          }

          MouseArea {
            anchors.fill: parent
            enabled: root.flow && root.flow.isResponseRequired
            onClicked: root.submitPassword()
          }
        }
      }
    }
  }

  function submitPassword() {
    if (!root.flow || !root.flow.isResponseRequired || passwordInput.text === "")
      return;
    var value = passwordInput.text;
    passwordInput.text = "";
    root.flow.submit(value);
  }

  onVisibleChanged: {
    if (visible) {
      // No resolvedMessage reset here: visible is bound to
      // PolkitService.isActive && flow !== null, and isActive is exactly
      // activeFlow() != nullptr (quickshell-nosd qml.cpp), so every show
      // path has already run onFlowChanged → resolveTransientServiceName.
      // The old clear ran after that handler (downstream visible handlers
      // fire last) and silently wiped the just-resolved message.
      Qt.callLater(function () {
        passwordInput.forceActiveFocus();
      });
    }
  }
}

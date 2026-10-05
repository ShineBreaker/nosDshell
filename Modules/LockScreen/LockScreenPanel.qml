import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.Location
import qs.Services.Media
import qs.Services.System
import qs.Widgets
import qs.Widgets.AudioSpectrum

Item {
  id: root
  anchors.fill: parent

  required property var lockControl
  required property TextInput passwordInput

  // Whether to enable lock screen animations (smooth cursor blink).
  // Defaults to false to reduce GPU usage.  Set Settings.data.general.lockScreenAnimations = true to restore.
  readonly property bool animationsEnabled: Settings.data.general.lockScreenAnimations || false

  Component.onCompleted: {
    if (Settings.data.general.autoStartAuth) {
      doUnlock();
    }
  }

  function doUnlock() {
    if (lockControl) {
      lockControl.tryUnlock();
    }
  }

  // Timer properties
  readonly property int timerDuration: Settings.data.general.lockScreenCountdownDuration
  property string pendingAction: ""
  property bool timerActive: false
  property int timeRemaining: 0
  readonly property bool weatherReady: Settings.data.location.weatherEnabled && (LocationService.data.weather !== null)

  // Timer management functions
  function startTimer(action) {
    // Check if global countdown is disabled
    if (!Settings.data.general.enableLockScreenCountdown) {
      executeAction(action);
      return;
    }

    if (timerActive && pendingAction === action) {
      // Second click - execute immediately
      executeAction(action);
      return;
    }

    pendingAction = action;
    timeRemaining = timerDuration;
    timerActive = true;
    countdownTimer.start();
  }

  function cancelTimer() {
    timerActive = false;
    pendingAction = "";
    timeRemaining = 0;
    countdownTimer.stop();
  }

  function executeAction(action) {
    // Stop timer but don't reset other properties yet
    countdownTimer.stop();

    // Execute the action
    switch (action) {
    case "logout":
      CompositorService.logout();
      break;
    case "suspend":
      CompositorService.suspend();
      break;
    case "hibernate":
      CompositorService.hibernate();
      break;
    case "reboot":
      CompositorService.reboot();
      break;
    case "userspaceReboot":
      CompositorService.userspaceReboot();
      break;
    case "shutdown":
      CompositorService.shutdown();
      break;
    }

    // Reset timer state
    cancelTimer();
  }

  // Countdown timer
  Timer {
    id: countdownTimer
    interval: 100
    repeat: true
    onTriggered: {
      timeRemaining -= interval;
      if (timeRemaining <= 0) {
        executeAction(pendingAction);
      }
    }
  }

  // Bottom container with the DDE centre block: avatar, user name, password
  // field and the session controls.
  Rectangle {
    id: bottomContainer

    // DDE band (DESIGN §3.9, lockframe.cpp): 132 px tall, 33 px above the
    // bottom. The auth block is vertically centred in the space left above it.
    readonly property int bandHeight: Math.round(132 * Style.uiScaleRatio)
    readonly property int bandEdgeMargin: Math.round(33 * Style.uiScaleRatio)

    // Let the content size the container; a fixed height clipped/overlapped the
    // rows once the DDE centre block was added (avatar + name + field).
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -bandHeight / 2
    radius: Style.radiusL
    color: "transparent"

    width: Settings.data.general.showHibernateOnLockScreen ? 860 : 810

    ColumnLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 14
      spacing: Style.marginL


      // DDE centre block (DESIGN §3.9, userinputwidget.cpp): 100 px ringless
      // avatar, user name 16 px 25 px below, then the password field 20 px below.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: 0

        NImageRounded {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 100
          Layout.preferredHeight: 100
          Layout.bottomMargin: 25
          radius: width / 2
          imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
          fallbackIcon: "person"
          fallbackIconSize: Math.round(Style.fontSizeXXXL * Style.uiScaleRatio)
        }

        NText {
          Layout.alignment: Qt.AlignHCenter
          Layout.bottomMargin: 20
          text: HostService.displayName
          pointSize: 16
          color: "white"
          horizontalAlignment: Text.AlignHCenter
        }
      }

      // Password input (20 px below the user name, DESIGN §3.9)
      RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Item {
          Layout.fillWidth: true
        }

        Rectangle {
          id: passwordInputContainer
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 280
          Layout.preferredHeight: 36
          radius: Math.min(Style.iRadiusL, height / 2)
          color: Color.overlay("field")
          border.color: lockControl.showFailure ? Color.alert : (passwordInput.activeFocus ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.3))
          border.width: 1

          property bool passwordVisible: false

          // Error tooltip (DESIGN §3.9, widgets/errortooltip.cpp): white card
          // below the field, alert-coloured message, arrow pointing up.
          NArrowRect {
            id: errorTooltip
            anchors.top: parent.bottom
            anchors.topMargin: Style.marginS
            anchors.horizontalCenter: parent.horizontalCenter
            arrowEdge: "top"
            arrowWidth: Style.marginM
            arrowHeight: Style.marginS
            radius: Style.radiusPopup
            fillColor: "white"
            borderColor: Color.alert
            borderWidth: 1
            visible: lockControl.showFailure && (lockControl.errorMessage || "").length > 0
            z: 3

            RowLayout {
              spacing: Style.marginM

              NIcon {
                icon: "alert-circle"
                pointSize: Style.fontSizeL
                color: Color.alert
              }

              NText {
                text: lockControl.errorMessage || "Authentication failed"
                color: Color.alert
                pointSize: Style.fontSizeM
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          // Ctrl + A to highlight the portion
          Shortcut {
            sequence: StandardKey.SelectAll
            enabled: passwordInput.activeFocus
            onActivated: passwordInput.selectAll()
          }

          // Esc to clear selection
          Shortcut {
            sequences: [StandardKey.Cancel]
            enabled: passwordInput.activeFocus && passwordInput.selectionStart !== passwordInput.selectionEnd
            onActivated: passwordInput.deselect()
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.marginS

            // Caps-lock glyph, left of the dots (DESIGN §3.9,
            // userinputwidget.cpp qlineedit icon).
            NIcon {
              id: capsLockGlyph
              icon: "arrow-bar-up"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
              visible: LockKeysService.capsLockOn
            }

            Row {
              spacing: 0
              Layout.alignment: Qt.AlignLeft

              Rectangle {
                width: 2
                height: 20
                color: Color.mPrimary
                visible: passwordInput.activeFocus && passwordInput.text.length === 0
                anchors.verticalCenter: parent.verticalCenter

                // Smooth fade animation (when animations enabled)
                SequentialAnimation on opacity {
                  loops: Animation.Infinite
                  running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
                  NumberAnimation {
                    to: 0
                    duration: 530
                  }
                  NumberAnimation {
                    to: 1
                    duration: 530
                  }
                }

                // Simple toggle (when animations disabled) — no per-frame repaints
                Timer {
                  interval: 530
                  running: !root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
                  repeat: true
                  onTriggered: parent.opacity = parent.opacity > 0.5 ? 0 : 1
                }
              }

              // Authenticating: spinner replaces the dots (DESIGN §3.9,
              // userinputwidget.cpp loadingIndicator). NBusyIndicator always
              // renders its frame, so it must be hidden while idle.
              NBusyIndicator {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                running: lockControl.unlockInProgress
                visible: lockControl.unlockInProgress
              }

              // Placeholder for the idle field. With fprintd enabled DDE waits
              // for a fingerprint first, so the fprintd text shows until the
              // user types (DESIGN §3.9, brief §2).
              NText {
                anchors.verticalCenter: parent.verticalCenter
                text: lockControl.waitingForPassword ? I18n.tr("authentication.fingerprint-or-password") : I18n.tr("authentication.password")
                color: Qt.alpha("white", 0.5)
                pointSize: Style.fontSizeM
                visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
              }

              // Authenticating hides the dot host so the two never overlap.
              Item {
                id: passwordVisualHost
                height: 20
                width: passwordInputContainer.passwordVisible ? Math.min(visiblePasswordPlainText.implicitWidth, 550) : Math.min(passwordDisplayContent.width, 550)
                anchors.verticalCenter: parent.verticalCenter
                visible: !lockControl.unlockInProgress

                readonly property real caretVisualX: {
                  const len = passwordInput.text.length;
                  if (len <= 0)
                    return 0;
                  if (passwordInputContainer.passwordVisible) {
                    const adv = passwordCaretFontMetrics.advanceWidth(passwordInput.text.substring(0, passwordInput.cursorPosition));
                    return Math.max(0, Math.min(adv, width));
                  }
                  const w = passwordDisplayContent.width;
                  if (w <= 0)
                    return 0;
                  return Math.max(0, Math.min((passwordInput.cursorPosition / len) * w, width));
                }

                // Password dots display with selection support
                Item {
                  width: Math.min(passwordDisplayContent.width, 550)
                  height: 20
                  visible: passwordInput.text.length > 0 && !passwordInputContainer.passwordVisible
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  clip: true

                  // Proportional selection highlight behind the dots
                  Rectangle {
                    id: selectionHighlight
                    visible: passwordInput.selectionStart !== passwordInput.selectionEnd && passwordInput.text.length > 0
                    color: Qt.alpha(Color.mPrimary, 0.8)
                    height: parent.height + Style.marginS
                    anchors.verticalCenter: parent.verticalCenter
                    x: (passwordInput.selectionStart / passwordInput.text.length) * passwordDisplayContent.width
                    width: ((passwordInput.selectionEnd - passwordInput.selectionStart) / passwordInput.text.length) * passwordDisplayContent.width
                  }

                  Row {
                    id: passwordDisplayContent
                    spacing: Style.marginXXXS
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                      id: iconRepeater
                      model: ScriptModel {
                        values: Array(passwordInput.text.length)
                      }

                      property list<string> passwordChars: ["circle-filled", "pentagon-filled", "michelin-star-filled", "square-rounded-filled", "guitar-pick-filled", "blob-filled", "triangle-filled"]

                      NIcon {
                        id: icon

                        required property int index
                        // This will be called with index = -1 when the TextInput is deleted
                        // So we make sur index is positive to avoid warning on array accesses
                        property bool drawCustomChar: index >= 0 && Settings.data.general.passwordChars
                        // Flip color when this dot falls inside the active selection range
                        property bool isSelected: index >= 0 && passwordInput.selectionStart !== passwordInput.selectionEnd && index >= passwordInput.selectionStart && index < passwordInput.selectionEnd

                        icon: drawCustomChar ? iconRepeater.passwordChars[index % iconRepeater.passwordChars.length] : "circle-filled"
                        pointSize: Style.fontSizeL
                        color: isSelected ? Color.mOnPrimary : Color.mPrimary
                        opacity: 1.0
                        scale: animationsEnabled ? 0.5 : 1
                        ParallelAnimation {
                          id: iconAnim
                          NumberAnimation {
                            target: icon
                            properties: "scale"
                            to: 1
                            duration: Style.animationFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Easing.OutInBounce
                          }
                        }
                        Component.onCompleted: {
                          if (animationsEnabled) {
                            iconAnim.start();
                          }
                        }
                      }
                    }
                  }

                  // Mouse area for click-to-position and drag-to-select
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor

                    property int dragStartPos: 0
                    property bool pendingSelectAll: false

                    // Resets double-click state if user pauses too long between clicks
                    Timer {
                      id: doubleClickResetTimer
                      interval: 600
                      onTriggered: parent.pendingSelectAll = false
                    }

                    function charIndexFromX(mouseX) {
                      if (passwordInput.text.length === 0)
                        return 0;
                      var charWidth = passwordDisplayContent.width / passwordInput.text.length;
                      // floor so clicking anywhere on a dot selects that dot, not the next
                      return Math.max(0, Math.min(passwordInput.text.length - 1, Math.floor(mouseX / charWidth)));
                    }

                    onPressed: function (mouse) {
                      doubleClickResetTimer.stop();
                      passwordInput.forceActiveFocus();
                      dragStartPos = charIndexFromX(mouse.x);
                      passwordInput.cursorPosition = dragStartPos;
                    }

                    onPositionChanged: function (mouse) {
                      pendingSelectAll = false;
                      var curPos = charIndexFromX(mouse.x);
                      if (curPos <= dragStartPos) {
                        passwordInput.select(curPos, dragStartPos + 1);
                      } else {
                        passwordInput.select(dragStartPos, curPos + 1);
                      }
                    }

                    onDoubleClicked: function (mouse) {
                      passwordInput.forceActiveFocus();
                      if (pendingSelectAll) {
                        passwordInput.selectAll();
                        pendingSelectAll = false;
                      } else {
                        var pos = charIndexFromX(mouse.x);
                        passwordInput.select(pos, Math.min(pos + 1, passwordInput.text.length));
                        pendingSelectAll = true;
                        doubleClickResetTimer.restart();
                      }
                    }
                  }
                }

                NText {
                  id: visiblePasswordPlainText
                  text: passwordInput.text
                  color: Color.mPrimary
                  pointSize: Style.fontSizeM
                  visible: passwordInput.text.length > 0 && passwordInputContainer.passwordVisible
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, 550)
                }

                FontMetrics {
                  id: passwordCaretFontMetrics
                  font: visiblePasswordPlainText.font
                }

                Rectangle {
                  width: 2
                  height: 20
                  x: passwordVisualHost.caretVisualX
                  color: Color.mPrimary
                  // Hide the cursor when text is selected
                  visible: passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
                  anchors.verticalCenter: parent.verticalCenter

                  // Smooth fade animation (when animations enabled)
                  SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
                    NumberAnimation {
                      to: 0
                      duration: 530
                    }
                    NumberAnimation {
                      to: 1
                      duration: 530
                    }
                  }

                  // Simple toggle (when animations disabled) — no per-frame repaints
                  Timer {
                    interval: 530
                    running: !root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
                    repeat: true
                    onTriggered: parent.opacity = parent.opacity > 0.5 ? 0 : 1
                  }
                }
              }
            }
          }

          // Eye button to toggle password visibility
          Rectangle {
            anchors.right: submitButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: Math.min(Style.iRadiusL, width / 2)
            color: eyeButtonArea.containsMouse ? Color.mPrimary : "transparent"
            visible: passwordInput.text.length > 0
            enabled: !lockControl || !lockControl.unlockInProgress

            NIcon {
              anchors.centerIn: parent
              icon: parent.parent.passwordVisible ? "eye-off" : "eye"
              pointSize: Style.fontSizeM
              color: eyeButtonArea.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }
            }

            MouseArea {
              id: eyeButtonArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: parent.parent.passwordVisible = !parent.parent.passwordVisible
            }

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
              }
            }
          }

          // Submit button
          Rectangle {
            id: submitButton
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: Math.min(Style.iRadiusL, width / 2)
            color: submitButtonArea.containsMouse ? Color.mPrimary : "transparent"
            border.color: Color.mPrimary
            border.width: Style.borderS
            enabled: !lockControl || !lockControl.unlockInProgress

            NIcon {
              anchors.centerIn: parent
              icon: "arrow-forward"
              pointSize: Style.fontSizeM
              color: submitButtonArea.containsMouse ? Color.mOnPrimary : Color.mPrimary

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }
            }

            MouseArea {
              id: submitButtonArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.doUnlock()
            }

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
              }
            }
          }

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }
        }

        Item {
          Layout.fillWidth: true
        }
      }

      // Session control buttons
      RowLayout {
        id: sessionButtonRow
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM
        visible: Settings.data.general.showSessionButtonsOnLockScreen

        readonly property int buttonCount: Settings.data.general.showHibernateOnLockScreen ? 5 : 4
        readonly property real availableWidth: bottomContainer.width - 48
        readonly property real buttonWidth: (availableWidth - (buttonCount - 1) * spacing) / buttonCount
        readonly property real buttonHeight: sessionButtonRow.height

        Item {
          Layout.preferredWidth: sessionButtonRow.buttonWidth
          Layout.preferredHeight: sessionButtonRow.buttonHeight

          NButton {
            anchors.fill: parent
            icon: "logout"
            text: I18n.tr("common.logout")
            outlined: true
            backgroundColor: Color.mOnSurfaceVariant
            textColor: Color.mOnPrimary
            fontSize: Style.fontSizeM
            iconSize: Style.fontSizeL
            horizontalAlignment: Qt.AlignHCenter
            buttonRadius: Style.radiusL
            onClicked: startTimer("logout")
          }
        }

        Item {
          Layout.preferredWidth: sessionButtonRow.buttonWidth
          Layout.preferredHeight: sessionButtonRow.buttonHeight

          NButton {
            anchors.fill: parent
            icon: "suspend"
            text: I18n.tr("common.suspend")
            outlined: true
            backgroundColor: Color.mOnSurfaceVariant
            textColor: Color.mOnPrimary
            fontSize: Style.fontSizeM
            iconSize: Style.fontSizeL
            horizontalAlignment: Qt.AlignHCenter
            buttonRadius: Style.radiusL
            onClicked: startTimer("suspend")
          }
        }

        Item {
          Layout.preferredWidth: sessionButtonRow.buttonWidth
          Layout.preferredHeight: sessionButtonRow.buttonHeight
          visible: Settings.data.general.showHibernateOnLockScreen

          NButton {
            anchors.fill: parent
            icon: "hibernate"
            text: I18n.tr("common.hibernate")
            outlined: true
            backgroundColor: Color.mOnSurfaceVariant
            textColor: Color.mOnPrimary
            fontSize: Style.fontSizeM
            iconSize: Style.fontSizeL
            horizontalAlignment: Qt.AlignHCenter
            buttonRadius: Style.radiusL
            onClicked: startTimer("hibernate")
          }
        }

        Item {
          Layout.preferredWidth: sessionButtonRow.buttonWidth
          Layout.preferredHeight: sessionButtonRow.buttonHeight

          NButton {
            anchors.fill: parent
            icon: "reboot"
            text: I18n.tr("common.reboot")
            outlined: true
            backgroundColor: Color.mOnSurfaceVariant
            textColor: Color.mOnPrimary
            fontSize: Style.fontSizeM
            iconSize: Style.fontSizeL
            horizontalAlignment: Qt.AlignHCenter
            buttonRadius: Style.radiusL
            onClicked: startTimer("reboot")
          }
        }

        Item {
          Layout.preferredWidth: sessionButtonRow.buttonWidth
          Layout.preferredHeight: sessionButtonRow.buttonHeight

          NButton {
            anchors.fill: parent
            icon: "shutdown"
            text: I18n.tr("common.shutdown")
            outlined: true
            backgroundColor: Color.mError
            textColor: Color.mOnError
            fontSize: Style.fontSizeM
            iconSize: Style.fontSizeL
            horizontalAlignment: Qt.AlignHCenter
            buttonRadius: Style.radiusL
            onClicked: startTimer("shutdown")
          }
        }
      }
    }
  }
}

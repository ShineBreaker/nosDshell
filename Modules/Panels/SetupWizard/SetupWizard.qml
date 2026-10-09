import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.LockScreen
import qs.Services.Plugins
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// First-run setup wizard (DESIGN §3.11): the DDE shape is a blurred wallpaper
// with a single centred DDialog on top -- maskDark, radius 8, a 20 px drop, 640
// wide because the steps carry settings rows, page dots for the step count and
// "Next" in the bottom-right. The trigger (Settings.shouldOpenSetupWizard) is
// untouched; only the presentation is DDE's.
//
// A standalone fullscreen PanelWindow (like SessionMenu), not a SmartPanel:
// SmartPanel clamps every panel to the screen minus Style.marginL per side
// and minus the taskbar height, which left a sharp unblurred band around
// the wallpaper. Full-screen anchors let LockScreenBackground cover the
// whole output, taskbar included.
PanelWindow {
  id: root

  // Screen property is inherited from PanelWindow; MainScreen assigns it.
  color: "transparent"

  WlrLayershell.namespace: "nosdshell-setup-wizard-" + (root.screen?.name || "unknown")
  // Modal over the whole screen, above the taskbar (same as SessionMenu).
  WlrLayershell.layer: WlrLayer.Overlay
  // Never reserve space — the wizard must not push the taskbar around.
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: root.isPanelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  implicitWidth: root.screen?.width || 0
  implicitHeight: root.screen?.height || 0

  // Window state follows the PanelService contract (same shape as SessionMenu,
  // minus its fade-out dance: the wizard is modal first-run UI, close maps
  // the surface off at once instead of leaving a transparent zombie mapped).
  // isPanelOpen drives everything; MainScreen/PanelService only ever call
  // open()/close() and read isPanelOpen.
  property bool isPanelOpen: false

  visible: isPanelOpen

  function open() {
    if (isPanelOpen)
      return;
    isPanelOpen = true;
    PanelService.willOpenPanel(root);
  }

  function close() {
    if (!isPanelOpen)
      return;
    isPanelOpen = false;
    PanelService.closedPanel(root);
  }

  function closeImmediately() {
    close();
  }

  function toggle() {
    if (isPanelOpen) {
      close();
    } else {
      open();
    }
  }

  Component.onCompleted: PanelService.registerPanel(root)

  Item {
    id: panelContent
    anchors.fill: parent

    // Wizard state (lazy-loaded with panelContent)
    property int currentStep: 0
    readonly property int totalSteps: 5
    property bool isCompleting: false

    // Setup wizard data
    property string selectedWallpaperDirectory: Settings.defaultWallpapersDirectory
    property string selectedWallpaper: ""
    property real selectedScaleRatio: 1.0
    property string selectedBarPosition: "top"

    // DDialog header per step. The step components used to draw their own
    // 40 px icon + coloured title; §3.11 puts a 48 px icon, a Medium title and a
    // white@0.8 message in the dialog's own top layout instead, so the header
    // moved up here and the steps are body content only.
    readonly property var steps: [
      {
        "icon": "sparkles",
        "title": I18n.tr("setup.welcome-title"),
        "description": I18n.tr("setup.welcome-subtitle"),
        "component": welcomeStep
      },
      {
        "icon": "image",
        "title": I18n.tr("setup.wallpaper.header"),
        "description": I18n.tr("setup.wallpaper.subheader"),
        "component": wallpaperStep
      },
      {
        "icon": "palette",
        "title": I18n.tr("common.appearance"),
        "description": I18n.tr("setup.appearance.subheader"),
        "component": appearanceStep
      },
      {
        "icon": "settings",
        "title": I18n.tr("setup.customize.header"),
        "description": I18n.tr("setup.customize.subheader"),
        "component": customizeStep
      },
      {
        "icon": "device-desktop",
        "title": I18n.tr("panels.dock.title"),
        "description": I18n.tr("setup.dock.subheader"),
        "component": dockStep
      }
    ]

    readonly property var currentStepData: steps[Math.min(currentStep, steps.length - 1)]

    Component.onCompleted: {
      selectedScaleRatio = Settings.data.general.scaleRatio;
      selectedBarPosition = Settings.data.dock.position;
      selectedWallpaperDirectory = Settings.data.wallpaper.directory || Settings.defaultWallpapersDirectory;
    }

    Connections {
      target: Settings
      function onSettingsSaved() {
        if (panelContent.isCompleting) {
          Logger.i("SetupWizard", "Settings saved, closing panel");
          panelContent.isCompleting = false;
          root.close();
        }
      }
    }

    Timer {
      id: closeTimer
      interval: 2000
      onTriggered: {
        if (panelContent.isCompleting) {
          Logger.w("SetupWizard", "Settings save timeout, closing panel anyway");
          panelContent.isCompleting = false;
          root.close();
        }
      }
    }

    function completeSetup() {
      if (isCompleting) {
        Logger.w("SetupWizard", "completeSetup() called while already completing, ignoring");
        return;
      }

      try {
        Logger.i("SetupWizard", "Completing setup with selected options");
        isCompleting = true;

        if (typeof WallpaperService !== "undefined" && WallpaperService.refreshWallpapersList) {
          if (selectedWallpaperDirectory !== Settings.data.wallpaper.directory) {
            Settings.data.wallpaper.directory = selectedWallpaperDirectory;
            WallpaperService.refreshWallpapersList();
          }

          if (selectedWallpaper !== "") {
            WallpaperService.changeWallpaper(selectedWallpaper, undefined);
          }
        }

        Settings.data.general.scaleRatio = selectedScaleRatio;
        Settings.data.dock.position = selectedBarPosition;

        // Save settings immediately and wait for settingsSaved signal before closing
        Settings.saveImmediate();
        Logger.i("SetupWizard", "Setup completed successfully, waiting for settings save confirmation");

        // Fallback: if settingsSaved signal doesn't fire within 2 seconds, close anyway
        closeTimer.start();
      } catch (error) {
        Logger.e("SetupWizard", "Error completing setup:", error);
        isCompleting = false;
      }
    }

    function applyWallpaperSettings() {
      if (typeof WallpaperService !== "undefined" && WallpaperService.refreshWallpapersList) {
        if (selectedWallpaperDirectory !== Settings.data.wallpaper.directory) {
          Settings.data.wallpaper.directory = selectedWallpaperDirectory;
          WallpaperService.refreshWallpapersList();
        }

        if (selectedWallpaper !== "") {
          WallpaperService.changeWallpaper(selectedWallpaper, undefined);
        }
      }
    }

    function applyUISettings() {
      Settings.data.general.scaleRatio = selectedScaleRatio;
      Settings.data.dock.position = selectedBarPosition;
    }

    // Blurred wallpaper (DESIGN §1.8). LockScreenBackground already owns
    // wallpaper resolution plus the nosd-blur / MultiEffect fallback, so the
    // wizard reuses it instead of duplicating that; SessionMenu does the same.
    LockScreenBackground {
      anchors.fill: parent
      screen: root.screen
      tintColor: "transparent"
    }

    // The five step bodies, kept as lazy Components: only the one the Loader is
    // showing gets built. The header above the body comes from `steps`, so a
    // step component is content only.
    Component {
      id: welcomeStep
      Item {
        ColumnLayout {
          anchors.centerIn: parent
          width: parent.width
          spacing: Style.marginXL

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(120 * Style.uiScaleRatio)
            Layout.alignment: Qt.AlignHCenter

            Rectangle {
              anchors.centerIn: parent
              width: 120
              height: 120
              radius: width / 2
              color: Color.mPrimary
              opacity: 0.08
              scale: 1.3
            }

            Image {
              anchors.centerIn: parent
              width: 110
              height: 110
              source: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/nosdshell.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true

              Rectangle {
                anchors.fill: parent
                color: Color.mSurfaceVariant
                radius: width / 2
                border.color: Color.mOutline
                border.width: Style.borderM
                visible: parent.status === Image.Error

                NIcon {
                  icon: "sparkles"
                  pointSize: Style.fontSizeXXL * 1.5
                  color: Color.mPrimary
                  anchors.centerIn: parent
                }
              }

              // Subtle pulse animation
              SequentialAnimation on scale {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                  from: 1.0
                  to: 1.05
                  duration: 2000
                  easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                  from: 1.05
                  to: 1.0
                  duration: 2000
                  easing.type: Easing.InOutQuad
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: welcomeNoteText.implicitHeight + Style.margin2M
            color: Color.overlay("strong")
            radius: Style.radiusL

            NText {
              id: welcomeNoteText
              // verticalCenter, not centerIn: the height comes from this text's
              // implicitHeight, so anchoring both edges to the rectangle would
              // make the two chase each other.
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.margin2L
              text: I18n.tr("setup.welcome-note")
              pointSize: Style.fontSizeM
              color: Color.onShellSecondary
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }

    Component {
      id: wallpaperStep
      SetupWallpaperStep {
        selectedDirectory: panelContent.selectedWallpaperDirectory
        selectedWallpaper: panelContent.selectedWallpaper
        onDirectoryChanged: function (directory) {
          panelContent.selectedWallpaperDirectory = directory;
          panelContent.applyWallpaperSettings();
        }
        onWallpaperChanged: function (wallpaper) {
          panelContent.selectedWallpaper = wallpaper;
          panelContent.applyWallpaperSettings();
        }
      }
    }

    Component {
      id: appearanceStep
      SetupAppearanceStep {}
    }

    Component {
      id: customizeStep
      SetupCustomizeStep {
        selectedScaleRatio: panelContent.selectedScaleRatio
        selectedBarPosition: panelContent.selectedBarPosition
        onScaleRatioChanged: function (ratio) {
          panelContent.selectedScaleRatio = ratio;
          panelContent.applyUISettings();
        }
        onBarPositionChanged: function (position) {
          panelContent.selectedBarPosition = position;
          panelContent.applyUISettings();
        }
      }
    }

    Component {
      id: dockStep
      SetupDockStep {}
    }

    // The DDialog. The card is the shadow area (20 px of bleed on every side so
    // the drop is not clipped) and the face inside it is the visible dialog.
    // Both sizes come straight from the tokens: deriving the height from the
    // step content instead makes the column and the face chase each other and
    // the dialog collapses to nothing.
    Item {
      id: dialogCard
      anchors.centerIn: parent
      readonly property int bleed: Math.round(Style.shadowDialog.blur * Style.uiScaleRatio)
      width: Math.min(Style.dialogWidth + bleed * 2, parent.width)
      height: Math.min(Style.dialogHeight + bleed * 2, parent.height)

      Rectangle {
        id: dialogFace
        anchors.centerIn: parent
        width: parent.width - parent.bleed * 2
        height: parent.height - parent.bleed * 2
        // maskDark straight from the token (DESIGN §1.2): black over the
        // blurred wallpaper, 0.4 with blur and 0.8 without. Forcing it opaque
        // was wrong -- next to a pure-black face the translucent drop shadow
        // reads as a *lighter* halo, and DDE's dialog is a mask over the
        // wallpaper, not a solid plate.
        color: Color.maskDark
        radius: Style.radiusWindow
        clip: true

        // Anchored sections, not one ColumnLayout: a column has to hand the
        // leftover height to a child, and this dialog has three sections with
        // different rules -- the header sits on the top edge, the step body
        // takes whatever is left, and the dots/hairline/buttons sit on the
        // bottom edge. In a column the leftover went to the button row (the
        // only section whose own children ask to fill) and the step body was
        // left 11 px tall, so every step spilled out of the dialog.
        Item {
          id: dialogInner
          anchors.fill: parent
          anchors.margins: Style.marginM

          // DDialog top layout: 48 px icon, Medium title, white@0.8 message
          // (DESIGN §3.11; ddialog.cpp:80-85, 106-112).
          RowLayout {
            id: dialogHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.marginM

            NIcon {
              // Style.dialogIconSize is the 48 px the DDialog spec asks for;
              // NIcon takes points and this repo's 96 dpi convention is
              // px = pt * 4/3 (see the font scale note in Style.qml).
              icon: panelContent.currentStepData.icon
              pointSize: Style.dialogIconSize * 0.75
              color: Color.onShell
              Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.dialogTitleSpacing

              NText {
                Layout.fillWidth: true
                text: panelContent.currentStepData.title
                pointSize: Style.fontSizeSubtitle
                font.weight: Style.fontWeightMedium
                color: Color.onShell
                wrapMode: Text.WordWrap
              }

              NText {
                Layout.fillWidth: true
                text: panelContent.currentStepData.description
                pointSize: Style.fontSizeBody
                color: Color.onShellSecondary
                wrapMode: Text.WordWrap
              }
            }
          }

          // Step body. A Loader, not a StackLayout: StackLayout instantiates and
          // lays out all five steps so it can size itself, so a step whose own
          // layout misbehaves takes the dialog's implicit size down with it.
          // Only the step on screen exists here.
          Loader {
            id: stepLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: dialogHeader.bottom
            anchors.bottom: dialogFooter.top
            anchors.topMargin: Style.marginL
            anchors.bottomMargin: Style.marginL
            sourceComponent: panelContent.currentStepData.component
          }

          // DDialog bottom block: the step count, then the action row.
          ColumnLayout {
            id: dialogFooter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Style.marginL

            // Page dots for the step count (DESIGN §3.11). Same 8 px dots and
            // white@0.8 / white@0.3 alphas the control centre page indicator uses.
            Row {
              Layout.alignment: Qt.AlignHCenter
              spacing: Style.marginS

              Repeater {
                model: panelContent.totalSteps

                delegate: Rectangle {
                  required property int index
                  readonly property bool active: panelContent.currentStep === index
                  width: 8
                  height: 8
                  radius: width / 2
                  color: active ? Qt.alpha(Color.onWallpaper, Style.pageDotCurrent) : Qt.alpha(Color.onWallpaper, Style.pageDotOther)

                  Behavior on color {
                    ColorAnimation {
                      duration: Style.animationNormal
                    }
                  }
                }
              }
            }

            // The 1 px white@0.1 line above the action row. ddialog.cpp:536-551
            // keeps a hidden 1 px "VLine" after every button and only shows it
            // when the next button is appended (ddialog.cpp:539-543), so a gap
            // in the row gets no line -- hence the single separator below.
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              Layout.minimumHeight: 1
              Layout.maximumHeight: 1
              color: Color.overlayWallpaper("hover")
            }

            RowLayout {
              Layout.fillWidth: true
              // Pinned on all three axes: this row is a fixed-height strip in
              // DDE (ddialog.cpp:521 gives every button setFixedHeight) and it
              // must not absorb slack, or it grows over the step body.
              Layout.preferredHeight: Style.dialogButtonHeight
              Layout.minimumHeight: Style.dialogButtonHeight
              Layout.maximumHeight: Style.dialogButtonHeight
              spacing: 0

              // Skip: a plain action, left of the row. A DDialog action button is
              // flat text on the dialog face, not a pill (dialogs.qss:20-28 gives
              // #ActionButton a transparent background and white text).
              NButton {
                text: I18n.tr("setup.skip-setup")
                backgroundColor: "transparent"
                textColor: Color.onShell
                hoverColor: Color.overlay("hover")
                buttonRadius: 0
                Layout.fillHeight: true
                onClicked: {
                  panelContent.completeSetup();
                }
              }

              Item {
                Layout.fillWidth: true
              }

              NButton {
                text: I18n.tr("common.back")
                backgroundColor: "transparent"
                textColor: Color.onShell
                hoverColor: Color.overlay("hover")
                buttonRadius: 0
                visible: panelContent.currentStep > 0
                Layout.fillHeight: true
                onClicked: {
                  if (panelContent.currentStep > 0) {
                    panelContent.currentStep--;
                  }
                }
              }

              Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.maximumHeight: Style.dialogButtonHeight
                color: Color.overlayWallpaper("hover")
                visible: panelContent.currentStep > 0
              }

              // Recommended action. §3.11 only gives the recommended button an
              // accent *label*, and dialogs.qss:20-28 gives every #ActionButton a
              // transparent background -- so this stays flat and only the text
              // turns accent, instead of taking NButton's pill fill.
              NButton {
                text: panelContent.currentStep === panelContent.totalSteps - 1 ? I18n.tr("setup.all-done") : I18n.tr("common.continue")
                backgroundColor: "transparent"
                textColor: Color.accent
                textHoverColor: Color.accent
                hoverColor: "transparent"
                buttonRadius: 0
                Layout.fillHeight: true
                onClicked: {
                  if (panelContent.currentStep < panelContent.totalSteps - 1) {
                    panelContent.currentStep++;
                  } else {
                    panelContent.completeSetup();
                  }
                }
              }
            }
          }
        }
      }

      // The drop, declared after the face on purpose: NDropShadow's layer paints
      // its `source` back out over the same rectangle, so it has to sit on top of
      // the face (same order as Notification.qml:423-428 and
      // LauncherOverlayWindow.qml:112-116). Put behind it with z: -1 and the
      // copy shows through the translucent face as a second, offset dialog.
      // It is anchored to the face and not to the card: the effect maps `source`
      // onto the item's own rect, so a larger rect would scale the copy off.
      // autoPaddingEnabled grows this item by the blur instead, which is what
      // fills the card's bleed.
      NDropShadow {
        anchors.fill: dialogFace
        source: dialogFace
        autoPaddingEnabled: true
        shadow: Style.shadowDialog
      }
    }
  }
}

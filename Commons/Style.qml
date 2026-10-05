pragma Singleton

import QtQuick
import Quickshell
import qs.Services.Power

Singleton {
  id: root

  // Font size (points; DDE base = 9pt)
  readonly property real fontSizeXXS: 7
  readonly property real fontSizeXS: 8
  readonly property real fontSizeS: 8.5
  readonly property real fontSizeM: 9
  readonly property real fontSizeL: 10.5
  readonly property real fontSizeXL: 12
  readonly property real fontSizeXXL: 14
  readonly property real fontSizeXXXL: 18

  // Font weight
  readonly property int fontWeightLight: 300
  readonly property int fontWeightRegular: 400
  readonly property int fontWeightMedium: 500
  readonly property int fontWeightSemiBold: 600
  readonly property int fontWeightBold: 700

  // Container Radii: major layout sections (sidebars, cards, content panels)
  readonly property int radiusXXXS: Math.round(2 * Settings.data.general.radiusRatio)
  readonly property int radiusXXS: Math.round(3 * Settings.data.general.radiusRatio)
  readonly property int radiusXS: Math.round(4 * Settings.data.general.radiusRatio)
  readonly property int radiusS: Math.round(5 * Settings.data.general.radiusRatio)
  readonly property int radiusM: Math.round(6 * Settings.data.general.radiusRatio)
  readonly property int radiusL: Math.round(8 * Settings.data.general.radiusRatio)

  // Input radii: interactive elements (buttons, toggles, text fields)
  readonly property int iRadiusXXXS: Math.round(2 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusXXS: Math.round(3 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusXS: Math.round(4 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusS: Math.round(5 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusM: Math.round(6 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusL: Math.round(8 * Settings.data.general.iRadiusRatio)

  readonly property int screenRadius: Math.round(20 * Settings.data.general.screenRadiusRatio)

  // Border
  readonly property int borderS: Math.max(1, Math.round(1 * uiScaleRatio))
  readonly property int borderM: Math.max(1, Math.round(2 * uiScaleRatio))
  readonly property int borderL: Math.max(1, Math.round(3 * uiScaleRatio))

  // Margins (for margins and spacing)
  readonly property int marginXXXS: Math.round(1 * uiScaleRatio)
  readonly property int marginXXS: Math.round(2 * uiScaleRatio)
  readonly property int marginXS: Math.round(4 * uiScaleRatio)
  readonly property int marginS: Math.round(6 * uiScaleRatio)
  readonly property int marginM: Math.round(9 * uiScaleRatio)
  readonly property int marginL: Math.round(13 * uiScaleRatio)
  readonly property int marginXL: Math.round(18 * uiScaleRatio)

  // Double margins, for proper container sizing only (e.g. height: id.implicitHeight + Style.margin2M)
  readonly property int margin2XXXS: marginXXXS * 2
  readonly property int margin2XXS: marginXXS * 2
  readonly property int margin2XS: marginXS * 2
  readonly property int margin2S: marginS * 2
  readonly property int margin2M: marginM * 2
  readonly property int margin2L: marginL * 2
  readonly property int margin2XL: marginXL * 2

  // Opacity
  readonly property real opacityNone: 0.0
  readonly property real opacityLight: 0.25
  readonly property real opacityMedium: 0.5
  readonly property real opacityHeavy: 0.75
  readonly property real opacityAlmost: 0.95
  readonly property real opacityFull: 1.0

  readonly property real effectivePanelOpacity: PowerProfileService.performanceMode ? 1.0 : Color.adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity)
  readonly property real effectiveBarOpacity: PowerProfileService.performanceMode ? 1.0 : Settings.data.bar.backgroundOpacity

  // Shadows
  readonly property real shadowOpacity: 0.85
  readonly property real shadowBlur: 1.0
  readonly property int shadowBlurMax: 22
  readonly property real shadowHorizontalOffset: Settings.data.general.shadowOffsetX
  readonly property real shadowVerticalOffset: Settings.data.general.shadowOffsetY

  // Animation duration (ms)
  readonly property int animationFaster: (Settings.data.general.animationDisabled || PowerProfileService.performanceMode) ? 0 : Math.round(75 / Settings.data.general.animationSpeed)
  readonly property int animationFast: (Settings.data.general.animationDisabled || PowerProfileService.performanceMode) ? 0 : Math.round(150 / Settings.data.general.animationSpeed)
  readonly property int animationNormal: (Settings.data.general.animationDisabled || PowerProfileService.performanceMode) ? 0 : Math.round(300 / Settings.data.general.animationSpeed)
  readonly property int animationSlow: (Settings.data.general.animationDisabled || PowerProfileService.performanceMode) ? 0 : Math.round(450 / Settings.data.general.animationSpeed)
  readonly property int animationSlowest: (Settings.data.general.animationDisabled || PowerProfileService.performanceMode) ? 0 : Math.round(750 / Settings.data.general.animationSpeed)

  // Delays
  readonly property int tooltipDelay: 300
  readonly property int tooltipDelayLong: 1200
  readonly property int pillDelay: 500

  // Widgets base size
  readonly property real baseWidgetSize: 33
  readonly property real sliderWidth: 200

  readonly property real uiScaleRatio: Settings.data.general.scaleRatio

  // Bar Height
  // Efficient (DDE taskbar) mode: thickness = dock.iconSize x 1.2 (36 -> 43), density is inert
  readonly property string _barEffectivePosition: Settings.data.dock.mode === "efficient" ? Settings.data.dock.position : Settings.data.bar.position
  readonly property bool _barEffectiveVertical: _barEffectivePosition === "left" || _barEffectivePosition === "right"
  readonly property real barHeight: {
    if (Settings.data.dock.mode === "efficient")
    return Math.round(Settings.data.dock.iconSize * 1.2);
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = _barEffectiveVertical ? 23 : 21;
      break;
      case "compact":
      h = _barEffectiveVertical ? 27 : 25;
      break;
      case "comfortable":
      h = _barEffectiveVertical ? 39 : 37;
      break;
      case "spacious":
      h = _barEffectiveVertical ? 49 : 47;
      break;
      default:
      case "default":
      h = _barEffectiveVertical ? 33 : 31;
    }
    return toOdd(h);
  }

  // Capsule Height
  // Note: capsule must always be smaller than barHeight to account for border rendering
  // Qt Quick Rectangle borders are drawn centered on edges (half inside, half outside)
  readonly property real capsuleHeight: {
    if (Settings.data.dock.mode === "efficient")
    return Math.round(Settings.data.dock.iconSize);
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = Math.round(barHeight * 0.90);
      break;
      case "compact":
      h = Math.round(barHeight * 0.85);
      break;
      case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
      case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
      default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  // The base/default font size for all texts in the bar
  readonly property real _barBaseFontSize: Math.max(1, (Style.barHeight / Style.capsuleHeight) * Style.fontSizeXXS)
  readonly property real barFontSize: _barEffectiveVertical ? _barBaseFontSize * 0.9 * Settings.data.bar.fontScale : _barBaseFontSize * Settings.data.bar.fontScale

  // Efficient mode never draws capsules (DESIGN §3.1.3: no capsules on the taskbar)
  readonly property color capsuleColor: (Settings.data.dock.mode === "efficient" || !Settings.data.bar.showCapsule) ? "transparent" : Qt.alpha(Settings.data.bar.capsuleColorKey !== "none" ? Color.resolveColorKey(Settings.data.bar.capsuleColorKey) : Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity)

  readonly property color capsuleBorderColor: (Settings.data.dock.mode !== "efficient" && Settings.data.bar.showOutline) ? Color.mPrimary : "transparent"
  readonly property int capsuleBorderWidth: Settings.data.bar.showOutline ? Style.borderS : 0

  readonly property color boxBorderColor: Settings.data.ui.boxBorderEnabled ? Color.mOutline : "transparent"

  // Pixel-perfect utility for centering content without subpixel positioning
  function pixelAlignCenter(containerSize, contentSize) {
    return Math.round((containerSize - contentSize) / 2);
  }

  // Ensures a number is always odd (rounds down to nearest odd)
  function toOdd(n) {
    return Math.floor(n / 2) * 2 + 1;
  }

  // Ensures a number is always even (rounds down to nearest even)
  function toEven(n) {
    return Math.floor(n / 2) * 2;
  }

  // Get bar height for a specific density and orientation
  function getBarHeightForDensity(density, isVertical) {
    let h;
    switch (density) {
    case "mini":
      h = isVertical ? 23 : 21;
      break;
    case "compact":
      h = isVertical ? 27 : 25;
      break;
    case "comfortable":
      h = isVertical ? 39 : 37;
      break;
    case "spacious":
      h = isVertical ? 49 : 47;
      break;
    default:
    case "default":
      h = isVertical ? 33 : 31;
    }
    return toOdd(h);
  }

  // Get capsule height for a specific density and bar height
  function getCapsuleHeightForDensity(density, barHeight) {
    let h;
    switch (density) {
    case "mini":
      h = Math.round(barHeight * 0.90);
      break;
    case "compact":
      h = Math.round(barHeight * 0.85);
      break;
    case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
    case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
    default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  // Get bar font size for a specific bar height, capsule height, and orientation
  function getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical) {
    const baseFontSize = Math.max(1, (barHeight / capsuleHeight) * Style.fontSizeXXS);
    return isVertical ? baseFontSize * 0.9 * Settings.data.bar.fontScale : baseFontSize * Settings.data.bar.fontScale;
  }

  // Convenience functions for per-screen bar sizing
  function getBarHeightForScreen(screenName) {
    if (Settings.data.dock.mode === "efficient")
      return Math.round(Settings.data.dock.iconSize * 1.2);
    var density = Settings.getBarDensityForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarHeightForDensity(density, isVertical);
  }

  function getCapsuleHeightForScreen(screenName) {
    if (Settings.data.dock.mode === "efficient")
      return Math.round(Settings.data.dock.iconSize);
    var barHeight = getBarHeightForScreen(screenName);
    var density = Settings.getBarDensityForScreen(screenName);
    return getCapsuleHeightForDensity(density, barHeight);
  }

  function getBarFontSizeForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var capsuleHeight = getCapsuleHeightForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical);
  }

  // ----------------------------------------------------------------
  // DDE 15 tokens (DESIGN.md §1.4–1.7, §3)
  // ----------------------------------------------------------------

  // Radii — never above 10 except true circles
  readonly property int radiusRow: Math.round(4 * Settings.data.general.radiusRatio)
  readonly property int radiusItem: Math.round(5 * Settings.data.general.radiusRatio)
  readonly property int radiusPopup: Math.round(6 * Settings.data.general.radiusRatio)
  readonly property int radiusWindow: Math.round(8 * Settings.data.general.radiusRatio)
  readonly property int radiusLarge: Math.round(10 * Settings.data.general.radiusRatio)

  // Arrow popups (DockPopupWindow geometry)
  readonly property int popupArrowWidth: 18
  readonly property int popupArrowHeight: 10
  readonly property int popupGap: 2

  // DDE menu row metrics: rows are font-height + 8, padded 20px on each side
  readonly property int menuItemPadding: Math.round(20 * uiScaleRatio)

  // Capsule radius — only the switch and RoundedButton-style buttons may use it (DESIGN §7)
  readonly property int radiusPill: 15

  // Shadows — feed into NDropShadow; plain {blur, x, y, color} objects (DESIGN §1.6)
  readonly property var shadowPopup: ({
                                        "blur": 20,
                                        "x": 0,
                                        "y": 2,
                                        "color": Qt.rgba(0, 0, 0, 0.5)
                                      })
  // Control centre frame: shadow cast to the left side only (DESIGN §3.5.1)
  readonly property var shadowControlCenter: ({
                                                "blur": 20,
                                                "x": -20,
                                                "y": 0,
                                                "color": Qt.rgba(0, 0, 0, 0.5)
                                              })
  readonly property var shadowOsd: ({
                                      "blur": 16,
                                      "x": 0,
                                      "y": 4,
                                      "color": Qt.rgba(0, 0, 0, 70 / 255)
                                    })
  readonly property var shadowBubble: ({
                                         "blur": 14,
                                         "x": 0,
                                         "y": 4,
                                         "color": Qt.rgba(0, 0, 0, 100 / 255)
                                       })
  readonly property var shadowMenuLight: ({
                                            "blur": 12,
                                            "x": 0,
                                            "y": 6,
                                            "color": Qt.rgba(0, 0, 0, 0.2)
                                          })

  // Motion (ms) — 0 when animations are off or in performance mode;
  // panel/enter motions fall back to 150 ms when blur is disabled (DESIGN §1.7)
  function _motion(baseMs, noBlurMs) {
    if (Settings.data.general.animationDisabled || PowerProfileService.performanceMode)
      return 0;
    const ms = (noBlurMs !== undefined && !Color.blurActive) ? noBlurMs : baseMs;
    return Math.round(ms / Settings.data.general.animationSpeed);
  }

  readonly property int motionPanel: _motion(300, 150)
  readonly property int motionEnter: _motion(300, 150)
  readonly property int motionBubbleIn: _motion(180)
  readonly property int motionBubbleOut: _motion(300)
  readonly property int motionOsdIn: _motion(160)
  readonly property int motionOsdOut: _motion(120)
  readonly property int motionFade: _motion(1000)
  readonly property int motionNavZoom: _motion(300)
  readonly property int motionSwitch: _motion(150)

  // Timeouts (ms)
  readonly property int tooltipDelayDock: 500
  readonly property int osdTimeout: 1000
  readonly property int bubbleTimeout: 5000

  // DDE type scale (points, same unit as the other fontSize* tokens)
  readonly property real fontSizeBody: 9
  readonly property real fontSizeTitle: 10.5
  readonly property real fontSizeSubtitle: 12
  readonly property real fontSizeClockCC: 34.5
  readonly property real fontSizeLockClock: 51

  // ----------------------------------------------------------------
  // §3.6 notification bubble / toast (gxde-session-ui bubble.h: Padding=20,
  // BubbleWidth=300, BubbleHeight=70; appicon 48 at (11,11); body at x=70,
  // width 220 (150 when actions exist); ActionButton 70 wide)
  // ----------------------------------------------------------------
  readonly property int bubbleBaseWidth: 300
  readonly property int bubbleBaseHeight: 70
  readonly property int bubbleEdgeOffset: 20
  readonly property int bubbleStackSpacing: 10
  readonly property int bubbleIconSize: 48
  readonly property int bubbleIconInset: 11
  readonly property int bubbleTextInset: 70
  readonly property int bubbleTextWidth: 220
  readonly property int bubbleTextWidthWithActions: 150
  readonly property int bubbleActionsWidth: 70
  readonly property int bubbleMaxBodyLines: 3

  // ----------------------------------------------------------------
  // §3.7 OSD tile (dde-osd/container.cpp: contentSize 140x140,
  // moveToCenter keeps the tile 180 px above the screen bottom)
  // ----------------------------------------------------------------
  readonly property int osdTileSize: 140
  readonly property int osdBottomOffset: 180
  readonly property int osdIconOffset: 40 // icon only
  readonly property int osdIconOffsetWithText: 25
  readonly property int osdIconOffsetWithProgress: 30
  readonly property int osdProgressWidth: 80
  readonly property int osdProgressHeight: 4
  readonly property int osdProgressOffset: 110
  readonly property int osdOverdriveMax: 150 // percent
  readonly property int osdTickWidth: 1
  readonly property int osdTickHeight: 5

  // ----------------------------------------------------------------
  // §3.8 shutdown row (rounditembutton.cpp: 140x140, icon 75, spacing 10,
  // checked = black @0.41 rounded 10)
  // ----------------------------------------------------------------
  readonly property int shutdownButtonSize: 140
  readonly property int shutdownButtonIcon: 75
  readonly property int shutdownButtonSpacing: 10
  readonly property int shutdownCountdownOffset: 40
  // rounditembutton.cpp:104-111 — leading spacing before the 75x75 icon, the
  // wrapping label sits right under it
  readonly property int shutdownButtonIconTextGap: 10

  // ----------------------------------------------------------------
  // §3.9 lock screen (sessionbasewindow.cpp: bottom widget 132 tall;
  // constants.h: PASSWDLINEEIDT_WIDTH=280, PASSWDLINEEDIT_HEIGHT=36;
  // useravatar LARGE = 100; controlwidget spacing 26 / trailing 60)
  // ----------------------------------------------------------------
  readonly property int lockBandHeight: 132
  readonly property int lockBandMargin: 33
  readonly property int lockClockInset: 48
  readonly property int lockControlSpacing: 26
  readonly property int lockControlTrailing: 60
  readonly property int lockAvatarSize: 100
  readonly property int lockNameGap: 25
  readonly property int lockPasswordWidth: 280
  readonly property int lockPasswordHeight: 36
  readonly property int lockPasswordGap: 20
  // DESIGN §3.9: the field is a 6 px rounded rectangle, not a pill
  readonly property int lockPasswordFieldRadius: 6

  // Control center home (DESIGN §3.5.1–3.5.2)
  // 408 px frame, flush right edge, full screen height (gxde-control-center frame.h:53)
  readonly property int controlCenterWidth: Math.round(408 * uiScaleRatio)
  readonly property int controlCenterHeaderHeight: Math.round(140 * uiScaleRatio)
  readonly property int controlCenterHeaderMarginLeft: Math.round(40 * uiScaleRatio)
  readonly property int controlCenterHeaderMarginTop: Math.round(10 * uiScaleRatio)
  // Module grid cell inset (navdelegate.cpp:41-57) and icon 24 px
  readonly property int moduleCellInset: Math.round(5 * uiScaleRatio)
  readonly property int moduleCellIcon: Math.round(24 * uiScaleRatio)
  // QuickSwitchButton: 70x60, glyph bottom-aligned 20 px above the bottom
  // (quickswitchbutton.cpp:41-46), on-state block radiusPopup + 5 px bottom margin
  readonly property int quickSwitchWidth: Math.round(70 * uiScaleRatio)
  readonly property int quickSwitchHeight: Math.round(60 * uiScaleRatio)
  // Basic page slider track height (gxde-control-center basicsettingspage.cpp)
  readonly property int sliderBasicHeight: Math.round(35 * uiScaleRatio)
  // Quick-control basic page height: volume + brightness sliders + switch row
  readonly property int quickControlPanelHeight: sliderBasicHeight * 3 + Style.marginM * 2
  readonly property int quickSwitchIconBottomMargin: Math.round(20 * uiScaleRatio)
  readonly property int quickSwitchBlockBottomMargin: Math.round(5 * uiScaleRatio)
  // Page indicator: height 40, dot alphas from DESIGN §3.5.2
  readonly property int pageIndicatorHeight: Math.round(40 * uiScaleRatio)
  readonly property real pageDotCurrent: 0.8
  readonly property real pageDotOther: 0.3
  // Wheel page switching is debounced by 200 ms (indicatorwidget.cpp:72-74)
  readonly property int pageSwitchDebounce: 200
  // Detail list rows are 36 px tall (wifilistmodel.cpp:95)
  readonly property int detailRowHeight: Math.round(36 * uiScaleRatio)

  // Settings pages inside the control center (DESIGN §3.5.3–3.5.4)
  // 56 px icon rail, spacing 20; content 352 (frame mode) / 640 (window mode)
  readonly property int settingsRailWidth: Math.round(56 * uiScaleRatio)
  readonly property int settingsRailSpacing: Math.round(20 * uiScaleRatio)
  readonly property int settingsModuleContentWidth: Math.round(352 * uiScaleRatio)
  readonly property int settingsWindowContentWidth: Math.round(640 * uiScaleRatio)
  // Content header: back button, centred title 14/500, separator 15 px below
  readonly property int settingsModuleTitleSize: Math.round(14 * uiScaleRatio)
  readonly property int settingsModuleSeparatorGap: Math.round(15 * uiScaleRatio)
  // SettingsGroup: 1 px row gap, outer corners radiusItem; SettingsHead 24 high
  readonly property int settingsGroupGap: Math.round(1 * uiScaleRatio)
  readonly property int settingsHeadHeight: Math.round(24 * uiScaleRatio)
  readonly property real settingsHeadAlpha: 0.15
  // SettingsItem (DESIGN §3.5.4): row 36, padding (20, 10)
  readonly property int settingsRowHeight: detailRowHeight
  readonly property int settingsRowPaddingH: Math.round(20 * uiScaleRatio)
  readonly property int settingsRowPaddingV: Math.round(10 * uiScaleRatio)
  // DSwitchButton: 40x22 capsule, 18 px knob, 150 ms (only capsule-type control)
  readonly property int switchWidth: Math.round(40 * uiScaleRatio)
  readonly property int switchHeight: Math.round(22 * uiScaleRatio)
  readonly property int switchKnob: Math.round(18 * uiScaleRatio)
  readonly property int switchDuration: 150
  // Text fields (LineEditWidget / ComboBoxWidget / spin box): 30 high, radiusItem
  readonly property int settingsFieldHeight: Math.round(30 * uiScaleRatio)
  readonly property int settingsFieldRadius: radiusItem
  // LineEditWidget fixes its title column at 140 px (lineeditwidget.cpp:83); the
  // gap between the title and the field is 0 there, we use marginXS so long
  // titles stay readable.
  readonly property int settingsFieldTitleWidth: Math.round(140 * uiScaleRatio)
  readonly property int settingsFieldGap: Math.round(4 * uiScaleRatio)
  // NextPageWidget: 5 px between value and chevron, 10 px trailing margin
  // (nextpagewidget.cpp:50-51); the chevron is a 16 px enter_details glyph.
  readonly property int settingsNextGap: Math.round(5 * uiScaleRatio)
  readonly property int settingsNextChevronSize: Math.round(16 * uiScaleRatio)
  // Spacing between two SettingsGroups (settingsgroup.cpp has no such token —
  // derived from the 15 px separator under the module head in the frame).
  readonly property int settingsGroupSpacing: Math.round(15 * uiScaleRatio)
  // DCCSlider row: the groove sits under the title, 6 px of breathing room
  // (dccslider.cpp:44 fixes the whole control at 35 px).
  readonly property int settingsSliderTitleGap: Math.round(6 * uiScaleRatio)

  // ----------------------------------------------------------------
  // §3.4.1 fullscreen launcher (gxde-launcher fullscreenframe.cpp:1319-1341,
  // searchwidget.cpp:81-103, calculate_util.cpp:47-54,104-145, constants.h)
  // ----------------------------------------------------------------
  // Search row: 30 px band, left/right margins 30, 30 px between the right-hand
  // buttons (searchwidget.cpp:82-102); top band 30, + dock height when the taskbar
  // sits on top (fullscreenframe.cpp:1321-1334)
  readonly property int launcherTopBand: 30
  readonly property int launcherSearchWidth: 290
  readonly property int launcherSearchButtonSize: 22 // category / unfullscreen
  readonly property int launcherSearchButtonSizeAlt: 24 // settings
  readonly property int launcherSearchButtonGap: 30
  readonly property int launcherAppsAreaTopMargin: 20 // APPS_AREA_TOP_MARGIN
  // calculateBesidePadding(): 180 px, 130 px when the screen is <= 1366 wide
  readonly property int launcherSidePaddingWide: 180
  readonly property int launcherSidePaddingNarrow: 130
  readonly property int launcherSidePaddingBreakpoint: 1366
  // calculateAppLayout(): cell budget 170/200 and spacing 10/14 at the 1440 breakpoint
  readonly property int launcherCellBudgetWide: 200
  readonly property int launcherCellBudgetNarrow: 170
  readonly property int launcherCellBudgetBreakpoint: 1440
  readonly property int launcherCellSpacingWide: 14
  readonly property int launcherCellSpacingNarrow: 10
  readonly property int launcherGridBottomMargin: 60 // VIEWLIST_BOTTOM_MARGIN
  readonly property int launcherGradientBand: 60 // §1.8 fade band

  // Category navigation (navigationwidget.cpp, categorybutton.cpp, constants.h)
  readonly property int launcherCategoryIconSize: 22 // *_22px.svg
  readonly property int launcherCategoryRowHeight: 42 // NAVIGATION_ICON_HEIGHT 50/1.2
  readonly property int launcherCategoryTitleHeight: 50 // CATEGORY_TITLE_WIDGET_HEIGHT
  readonly property real launcherNavZoom: 1.2 // enterEvent zoom level

  // ----------------------------------------------------------------
  // §3.4.2 mini launcher (windowedframe.cpp:158-171, miniframerightbar.cpp:144,
  // avatar.cpp:42, datetimewidget.cpp:35, miniframebutton.cpp:43-48)
  // ----------------------------------------------------------------
  readonly property int launcherMiniHeight: 502
  readonly property int launcherMiniLeftPaneWidth: 320
  readonly property int launcherMiniRightPaneWidth: 160
  readonly property int launcherMiniDockGap: 1 // adjustPosition(): +1 px off the taskbar
  readonly property int launcherMiniRowHeight: 36 // app rows and the switch button
  readonly property int launcherMiniAvatarSize: 60 // avatar.cpp:42
  readonly property int launcherMiniTopBand: 30 // right bar top spacing
  readonly property int launcherMiniModeToggleSize: 24 // fullscreen_normal.png
  readonly property int launcherMiniPaddingLeft: 18 // miniframerightbar.cpp:144
  readonly property int launcherMiniPaddingRight: 12
  readonly property int launcherMiniPaddingBottom: 18
  // Left pane bottom band (windowedframe.cpp:156 addSpacing(15))
  readonly property int launcherMiniBottomGap: 15
  // MiniFrameButton::updateFont(): max(base px + 2, 14). 14 px at 96 dpi == 10.5 pt
  readonly property real launcherMiniButtonFontSize: 10.5
  // Row pitch measured off the DDE 15.5 mini launcher (references/menu2.png):
  // the six place rows sit 30 px apart (14 px label + 2/2 px padding from
  // skin/qss/miniframe.qss `#MiniFrameButton`)
  readonly property int launcherMiniButtonRowHeight: 30
  // DatetimeWidget: 40 px clock, then the long-format date at white 0.6
  readonly property real launcherMiniClockSize: 40
  readonly property real launcherMiniClockDateAlpha: 0.6
  readonly property int launcherMiniPlaceIconSize: 22

  // Dock icon size presets
  readonly property int dockIconSmall: 30
  readonly property int dockIconMedium: 36
  readonly property int dockIconLarge: 48

  // DDE fashion dock item metrics (gxde-dock appitem.cpp: thickness = iconSize*1.5,
  // length = thickness*1.1, icon = 0.8*min(w,h))
  readonly property int dockItemThickness: Math.round(Settings.data.dock.iconSize * 1.5)
  readonly property int dockItemLength: Math.round(dockItemThickness * 1.1)
  readonly property int dockIconContent: Math.round(Math.min(dockItemThickness, dockItemLength) * 0.8)

  // DDE fashion clock face geometry, verbatim from
  // gxde-dock/plugins/datetime/datetimewidget.cpp:123-186. Every step there is
  // integer arithmetic on int, so the ratios are truncated the same way here.
  readonly property real dockClockFaceRatio: 0.8 // perfectIconSize = min(w, h) * 0.8
  readonly property real dockClockBigNumHeightRatio: 0.4 // bigNumHeight = perfectIconSize / 2.5
  readonly property real dockClockBigNumWidthRatio: 4 / 9 // bigNumWidth = bigNumHeight * 8 / 18
  readonly property real dockClockSmallNumHeightRatio: 0.5 // smallNumHeight = bigNumHeight / 2
  readonly property real dockClockSmallNumWidthRatio: 5 / 9 // smallNumWidth = smallNumHeight * 5 / 9
  readonly property int dockClockBigNumGap: 1 // between the two big digits (line 146)
  readonly property int dockClockSmallNumGap: 1 // between the two small digits (line 160, 185)
  readonly property int dockClockBigSmallGap: 2 // big block to small block / am-pm tips (line 154, 173, 179)
  readonly property int dockClockBigNumLeftBias: 1 // "… - bigNumWidth * 2 + 1" (line 140)
  readonly property int dockClockAmPmLeftInset: 1 // 12h branch drops the small digits by 1 px (line 154)
}

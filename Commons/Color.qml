pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.Power

/*
Noctalia is not strictly a Material Design project, it supports both some predefined
color schemes and dynamic color generation from the wallpaper.

We ultimately decided to use a restricted set of colors that follows the
Material Design 3 naming convention.

NOTE: All color names are prefixed with 'm' (e.g., mPrimary) to prevent QML from
misinterpreting them as signals (e.g., the 'onPrimary' property name).
*/
Singleton {
  id: root

  property bool reloadColors: false

  // Debounce external reload requests (file watcher + directory watcher)
  // so atomic replacements only trigger one reload.
  Timer {
    id: externalColorReloadTimer
    running: false
    interval: 200
    onTriggered: {
      if (customColorsFile.path !== undefined) {
        Logger.d("Color", "Reloading colors from disk");
        reloadColors = true;
        customColorsFile.reload();
      }
    }
  }

  function scheduleExternalColorReload() {
    if (!Settings.directoriesCreated || customColorsFile.path === undefined) {
      return;
    }
    externalColorReloadTimer.restart();
  }

  // Suppress transition animations until the first colors.json load completes
  property bool skipTransition: true

  // Flag indicating theme colors are currently transitioning (for widgets to disable their own animations)
  property bool isTransitioning: false

  // Timer to reset isTransitioning after animation completes
  Timer {
    id: transitionTimer
    interval: Style.animationSlowest + 50 // Small buffer after animation
    onTriggered: root.isTransitioning = false
  }

  // --- Key Colors: These are the main accent colors that define your app's style.
  // The accent roles (primary/secondary/tertiary/hover) split into a raw
  // scheme value (_*Raw, written by the colors.json FileView connections) and
  // the public m* token, which resolves through ui.accentOverride (DESIGN §5):
  // a pinned accent overrides all four roles, and their on-colors are derived
  // from the accent's luminance so text stays readable.
  property color _primaryRaw: defaultColors.mPrimary
  property color _onPrimaryRaw: defaultColors.mOnPrimary
  property color _secondaryRaw: defaultColors.mSecondary
  property color _onSecondaryRaw: defaultColors.mOnSecondary
  property color _tertiaryRaw: defaultColors.mTertiary
  property color _onTertiaryRaw: defaultColors.mOnTertiary
  property color _hoverRaw: defaultColors.mHover
  property color _onHoverRaw: defaultColors.mOnHover

  readonly property color mPrimary: accentOverridden ? _accentOverride : _primaryRaw
  readonly property color mSecondary: accentOverridden ? _accentOverride : _secondaryRaw
  readonly property color mTertiary: accentOverridden ? _accentOverride : _tertiaryRaw
  readonly property color mHover: accentOverridden ? _accentOverride : _hoverRaw
  // Text on accent: white on the dark side, #303030 once the accent is bright
  // enough for it to read (≈0.6 relative luminance keeps Deepin blue on white).
  readonly property color _onAccentColor: {
    const c = mPrimary;
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.6 ? "#303030" : "#FFFFFF";
  }
  readonly property color mOnPrimary: accentOverridden ? _onAccentColor : _onPrimaryRaw
  readonly property color mOnSecondary: accentOverridden ? _onAccentColor : _onSecondaryRaw
  readonly property color mOnTertiary: accentOverridden ? _onAccentColor : _onTertiaryRaw
  readonly property color mOnHover: accentOverridden ? _onAccentColor : _onHoverRaw

  // --- Utility Colors: These colors serve specific, universal purposes like indicating errors
  property color mError: defaultColors.mError
  property color mOnError: defaultColors.mOnError

  // --- Surface and Variant Colors: These provide additional options for surfaces and their contents, creating visual hierarchy
  property color mSurface: defaultColors.mSurface
  property color mOnSurface: defaultColors.mOnSurface

  property color mSurfaceVariant: defaultColors.mSurfaceVariant
  property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant

  property color mOutline: defaultColors.mOutline
  property color mShadow: defaultColors.mShadow

  // --- Color transition animations ---
  Behavior on _primaryRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onPrimaryRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _secondaryRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onSecondaryRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _tertiaryRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onTertiaryRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOutline {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mShadow {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _hoverRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onHoverRaw {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }

  // Helper to start transition and update a color
  function startTransition() {
    root.isTransitioning = true;
    transitionTimer.restart();
  }

  // Update colors when customColorsData changes (imperative assignment enables Behavior animations)
  Connections {
    target: customColorsData
    function onMPrimaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._primaryRaw = customColorsData.mPrimary;
    }
    function onMOnPrimaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._onPrimaryRaw = customColorsData.mOnPrimary;
    }
    function onMSecondaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._secondaryRaw = customColorsData.mSecondary;
    }
    function onMOnSecondaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._onSecondaryRaw = customColorsData.mOnSecondary;
    }
    function onMTertiaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._tertiaryRaw = customColorsData.mTertiary;
    }
    function onMOnTertiaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._onTertiaryRaw = customColorsData.mOnTertiary;
    }
    function onMErrorChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mError = customColorsData.mError;
    }
    function onMOnErrorChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnError = customColorsData.mOnError;
    }
    function onMSurfaceChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSurface = customColorsData.mSurface;
    }
    function onMOnSurfaceChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSurface = customColorsData.mOnSurface;
    }
    function onMSurfaceVariantChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSurfaceVariant = customColorsData.mSurfaceVariant;
    }
    function onMOnSurfaceVariantChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSurfaceVariant = customColorsData.mOnSurfaceVariant;
    }
    function onMOutlineChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOutline = customColorsData.mOutline;
    }
    function onMShadowChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mShadow = customColorsData.mShadow;
    }
    function onMHoverChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._hoverRaw = customColorsData.mHover;
    }
    function onMOnHoverChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root._onHoverRaw = customColorsData.mOnHover;
    }
  }

  function resolveColorKey(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return root.mOnSurface;
    }
  }

  function resolveOnColorKey(key) {
    switch (key) {
    case "primary":
      return root.mOnPrimary;
    case "secondary":
      return root.mOnSecondary;
    case "tertiary":
      return root.mOnTertiary;
    case "error":
      return root.mOnError;
    default:
      return root.mSurface;
    }
  }

  function resolveColorKeyOptional(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return "transparent";
    }
  }

  // Adaptive opacity calculation: automatically makes light mode more transparent
  function adaptiveOpacity(baseOpacity) {
    if (PowerProfileService.performanceMode)
      return 1.0;
    return Settings.data.colorSchemes.darkMode ? baseOpacity : Math.pow(baseOpacity, 1.5);
  }

  function smartAlpha(baseColor, minAlpha = 0.4) {
    if (PowerProfileService.performanceMode)
      return baseColor;

    if (!Settings.data.ui.translucentWidgets)
      return baseColor;

    let alpha = Math.max(adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity), minAlpha);

    // Combine with the base color's existing alpha
    let resultAlpha = Math.max(0, baseColor.a - (1.0 - alpha));
    return Qt.alpha(baseColor, resultAlpha);
  }

  readonly property var colorKeyModel: [
    {
      "key": "none",
      "name": I18n.tr("common.none")
    },
    {
      "key": "primary",
      "name": I18n.tr("common.primary")
    },
    {
      "key": "secondary",
      "name": I18n.tr("common.secondary")
    },
    {
      "key": "tertiary",
      "name": I18n.tr("common.tertiary")
    },
    {
      "key": "error",
      "name": I18n.tr("common.error")
    }
  ]

  // --------------------------------
  // DDE 15 semantic layer (DESIGN.md §1.1–1.3)
  // --------------------------------

  // Accents resolve through the active color scheme so other schemes still work.
  // ui.accentOverride (DESIGN §5): a non-empty valid #hex color pins the whole
  // accent family; invalid values are ignored with a warning.
  readonly property color _accentOverride: {
    const s = Settings.data.ui.accentOverride;
    if (typeof s !== "string" || s === "")
      return "transparent";
    if (!/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s)) {
      if (!_accentWarned) {
        _accentWarned = true;
        Logger.w("Color", "Ignoring invalid ui.accentOverride:", s);
      }
      return "transparent";
    }
    return s; // string coerced to color by the property type
  }
  property bool _accentWarned: false
  readonly property bool accentOverridden: _accentOverride.a > 0

  // The accent family aliases the accent-role m* tokens, which already resolve
  // ui.accentOverride (declared above) — so a pinned accent reaches every
  // consumer, including places that read mPrimary/mTertiary directly.
  readonly property color accent: root.mPrimary
  readonly property color accentAlt: root.mSecondary
  readonly property color accentAction: root.mTertiary
  readonly property color onAccent: root.mOnPrimary

  readonly property color attention: "#F18A2E"
  readonly property color alert: "#F9704F"
  readonly property color lowPower: "#FF8000"
  readonly property color textDisabledDark: "#646464"
  readonly property color pressDim: Qt.rgba(0, 0, 0, 0.41)

  // True when the compositor-side blur path is enabled (controls mask alpha).
  // DESIGN §1.2: the setting alone is not enough, the compositor must also
  // advertise ext-background-effect-v1 (probed once at startup, §4.1).
  readonly property bool blurActive: Settings.data.general.enableBlurBehind && CompositorService.blurSupported && !PowerProfileService.performanceMode
  // Dark/light mode source of truth, same as the scheme system.
  readonly property bool shellIsDark: Settings.data.colorSchemes.darkMode

  // Surfaces: more opaque when blur is off (DESIGN §1.2 fallback)
  readonly property color maskDark: Qt.rgba(0, 0, 0, blurActive ? Settings.data.ui.panelBackgroundOpacity : 0.8)
  readonly property color maskLight: Qt.rgba(1, 1, 1, blurActive ? Settings.data.ui.panelBackgroundOpacity : 0.8)
  readonly property color popupDark: Qt.rgba(36 / 255, 36 / 255, 36 / 255, 0.86)

  // Panel borders: visible hairlines over blur (DESIGN §1.2), scaled by
  // ui.borderEmphasis (0-2; 0 disables). Solid fallbacks stay solid at
  // emphasis >= 1 and fade proportionally below it.
  function _border(base, blurredAlpha) {
    const c = blurActive ? Qt.rgba(base.r, base.g, base.b, blurredAlpha) : base;
    return Qt.alpha(c, Math.min(1, c.a * Settings.data.ui.borderEmphasis));
  }
  readonly property color borderDark: _border("#2C3238", 0.10)
  readonly property color borderLight: _border("#E5E5E5", 0.08)

  readonly property color maskShell: shellIsDark ? maskDark : maskLight
  readonly property color popupShell: shellIsDark ? popupDark : Qt.rgba(1, 1, 1, 0.9)

  // Transient tiles (OSD, notification/toast bubbles) — DESIGN §1.2.
  // ui.transientSurface: "light" = DDE's opaque #F8F8F8 tile, "dark" = dark
  // glass on popupDark, "auto" follows shellIsDark. ui.transientOpacity
  // scales the tile alpha; without compositor blur the floor is 0.9 so a
  // translucent tile never floats over sharp wallpaper (muddy, low contrast).
  readonly property bool transientIsDark: {
    const s = Settings.data.ui.transientSurface;
    return s === "dark" ? true : s === "light" ? false : shellIsDark;
  }
  readonly property real _transientAlpha: {
    const base = transientIsDark ? 0.86 : 1.0;
    const a = base * Settings.data.ui.transientOpacity;
    return blurActive ? Math.max(0.5, a) : Math.max(0.9, a);
  }
  readonly property color maskTransient: transientIsDark ? Qt.rgba(36 / 255, 36 / 255, 36 / 255, _transientAlpha) : Qt.alpha("#F8F8F8", _transientAlpha)

  readonly property color borderShell: shellIsDark ? borderDark : borderLight
  readonly property color borderTransient: transientIsDark ? borderDark : borderLight

  readonly property color onShell: shellIsDark ? "#FFFFFF" : "#303030"
  readonly property color onShellSecondary: Qt.alpha(onShell, 0.8)
  // Light side needs more ink: 0.6×#303030 ≈ #828282 is only ~3.8:1 on the
  // light frame; 0.7 lands ≈ #6E6E6E (~5.2:1), matching the light scheme's
  // mOnSurfaceVariant (#6B6B6B). Dark side keeps the DDE spec's 0.6.
  readonly property color onShellTertiary: Qt.alpha(onShell, shellIsDark ? 0.6 : 0.7)

  // Text/icons drawn on the blurred wallpaper itself (fullscreen launcher,
  // shutdown UI, lock screen). Those surfaces stay dark in both modes, so the
  // foreground never follows shellIsDark (DESIGN §1.5).
  readonly property color onWallpaper: "#FFFFFF"
  readonly property color onWallpaperSecondary: Qt.alpha("#FFFFFF", 0.8)
  readonly property color onWallpaperTertiary: Qt.alpha("#FFFFFF", 0.6)
  // Text shadow on wallpaper: rgba(0,0,0,0.31) offset (0,1) → Text.Sunken
  readonly property color onWallpaperShadow: Qt.rgba(0, 0, 0, 0.31)
  readonly property color onTransient: transientIsDark ? "#FFFFFF" : "#303030"
  readonly property color onTransientBody: transientIsDark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.9)

  // Track/tick marks on transient tiles (OSD progress groove, volume
  // graduation). Light tiles use DDE's literal black @0.1/@0.5
  // (dde-osd/common.cpp DrawProgressBar / DrawVolumeGraduation); dark tiles
  // flip to the white ladder (DESIGN §1.2).
  readonly property color onTransientTrack: transientIsDark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.1)
  readonly property color onTransientTick: transientIsDark ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.5)

  // Action-button text on transient tiles: accentAction (the light-tile
  // blue) reads dim on dark glass, so dark tiles take the brighter accent.
  readonly property color transientAction: transientIsDark ? accent : accentAction

  // Module header separator: 1 px line, white x 0.15 in dark mode (DESIGN
  // §3.5.4). Adaptive via onShell so light mode reads black x 0.15.
  readonly property color separator: Qt.alpha(onShell, 0.15)

  // White overlay ladder on dark surfaces (black on light) — DESIGN §1.3
  readonly property var overlayLevels: ({
                                          "idle": 0.03,
                                          "subtle": 0.05,
                                          "hover": 0.10,
                                          "field": 0.15,
                                          "strong": 0.20,
                                          "checked": 0.30,
                                          "press": 0.50,
                                          // DDE fashion running-indicator bar (white @0.25, gxde-dock indicator.png)
                                          "indicator": 0.25
                                        })

  property var _overlayWarned: ({})

  function overlay(level) {
    return _overlay(level, shellIsDark ? "#FFFFFF" : "#000000");
  }

  // White ladder that never follows the theme — tiles on the blurred
  // wallpaper (fullscreen launcher) sit on a dark surface in both modes.
  function overlayWallpaper(level) {
    return _overlay(level, "#FFFFFF");
  }

  function overlayTransient(level) {
    return _overlay(level, transientIsDark ? "#FFFFFF" : "#000000");
  }

  // Multiply a token's alpha by an extra factor — unlike Qt.alpha(), which
  // overwrites the alpha outright and would clobber tokens that already
  // carry one (maskTransient, popupDark).
  function stackAlpha(base, factor) {
    return Qt.rgba(base.r, base.g, base.b, Math.min(1, base.a * factor));
  }

  function _overlay(level, base) {
    const a = overlayLevels[level];
    if (a === undefined) {
      if (!_overlayWarned[level]) {
        _overlayWarned[level] = true;
        Logger.w("Color", "Unknown overlay level:", level);
      }
      return "transparent";
    }
    return Qt.alpha(base, a);
  }

  // --------------------------------
  // Default colors: Deepin dark — must match Assets/ColorScheme/Deepin
  QtObject {
    id: defaultColors

    readonly property color mPrimary: "#2CA7F8"
    readonly property color mOnPrimary: "#FFFFFF"

    readonly property color mSecondary: "#01BDFF"
    readonly property color mOnSecondary: "#FFFFFF"

    readonly property color mTertiary: "#0087FF"
    readonly property color mOnTertiary: "#FFFFFF"

    readonly property color mError: "#F9704F"
    readonly property color mOnError: "#FFFFFF"

    readonly property color mSurface: "#181818"
    readonly property color mOnSurface: "#FFFFFF"

    readonly property color mSurfaceVariant: "#2A2A2A"
    readonly property color mOnSurfaceVariant: "#B4B4B4"

    readonly property color mOutline: "#3A3A3A"
    readonly property color mShadow: "#000000"

    readonly property color mHover: "#2CA7F8"
    readonly property color mOnHover: "#FFFFFF"
  }

  // ----------------------------------------------------------------
  // FileView to load custom colors data from colors.json
  FileView {
    id: customColorsFile
    path: Settings.directoriesCreated ? (Settings.configDir + "colors.json") : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
    onAdapterUpdated: {
      Logger.d("Color", "Writing colors to disk");
      writeAdapter();
    }

    onLoaded: {
      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }
    }

    // Trigger initial load when path changes from empty to actual path
    onPathChanged: {
      if (path !== undefined) {
        reload();
      }
    }
    onLoadFailed: function (error) {
      if (reloadColors) {
        reloadColors = false;
        return;
      }

      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }

      // Error code 2 = ENOENT (No such file or directory)
      if (error === 2 || error.toString().includes("No such file")) {
        // File doesn't exist, create it with default values
        writeAdapter();
      }
    }
    JsonAdapter {
      id: customColorsData

      property color mPrimary: defaultColors.mPrimary
      property color mOnPrimary: defaultColors.mOnPrimary

      property color mSecondary: defaultColors.mSecondary
      property color mOnSecondary: defaultColors.mOnSecondary

      property color mTertiary: defaultColors.mTertiary
      property color mOnTertiary: defaultColors.mOnTertiary

      property color mError: defaultColors.mError
      property color mOnError: defaultColors.mOnError

      property color mSurface: defaultColors.mSurface
      property color mOnSurface: defaultColors.mOnSurface

      property color mSurfaceVariant: defaultColors.mSurfaceVariant
      property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant

      property color mOutline: defaultColors.mOutline
      property color mShadow: defaultColors.mShadow

      property color mHover: defaultColors.mHover
      property color mOnHover: defaultColors.mOnHover
    }
  }

  // Watch parent config directory as a fallback for declarative setups where
  // colors.json may be replaced atomically (e.g., symlink/store-path swap).
  FileView {
    id: colorsDirWatcher
    path: Settings.directoriesCreated ? Settings.configDir : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
  }
}

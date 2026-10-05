import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.UI

// Full-screen launcher background (DESIGN §1.8 / §3.4.1): pre-blurred current
// wallpaper scaled cover with a solid black layer underneath, falling back to a
// live MultiEffect blur while the cached image is not ready (or nosd-blur is
// missing). Same approach as Modules/LockScreen/LockScreenBackground.qml.
Item {
  id: root

  property string resolvedWallpaperPath: ""
  property string resolvedBlurredPath: ""

  required property var screen

  readonly property bool preBlurAvailable: ImageCacheService.blurToolAvailable

  Component.onCompleted: Qt.callLater(requestWallpaper)

  onWidthChanged: if (width > 0 && height > 0)
                    Qt.callLater(requestWallpaper)
  onHeightChanged: if (width > 0 && height > 0)
                     Qt.callLater(requestWallpaper)

  Connections {
    target: WallpaperService
    function onWallpaperChanged(screenName, path) {
      if (screen && screenName === screen.name)
        Qt.callLater(requestWallpaper);
    }
  }

  function requestWallpaper() {
    if (!screen || width <= 0 || height <= 0)
      return;

    const originalPath = WallpaperService.getWallpaper(screen.name) || "";
    if (originalPath === "" || WallpaperService.isSolidColorPath(originalPath)) {
      resolvedWallpaperPath = "";
      resolvedBlurredPath = "";
      return;
    }

    // Sharp source for the live-blur fallback: without it the launcher surface
    // stays translucent until nosd-blur has produced the cached variant
    // (DESIGN §1.8).
    resolvedWallpaperPath = originalPath;

    const compositorScale = CompositorService.getDisplayScale(screen.name);
    const targetWidth = Math.round(width * compositorScale);
    const targetHeight = Math.round(height * compositorScale);
    if (targetWidth <= 0 || targetHeight <= 0)
      return;

    ImageCacheService.getBlurred(originalPath, targetWidth, targetHeight, function (cachedPath, success) {
      if (success)
        resolvedBlurredPath = cachedPath;
    });
  }

  // Pre-blurred variant: sharp wallpaper under a live blur while not ready
  Image {
    id: liveImage
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    source: root.resolvedBlurredPath !== "" ? "" : root.resolvedWallpaperPath
    cache: false
    asynchronous: true
    smooth: true
    mipmap: false
    antialiasing: true
    visible: source !== "" && !usePreBlurred

    readonly property bool usePreBlurred: preBlurAvailable && Settings.data.general.enableBlurBehind && !PowerProfileService.performanceMode

    layer.enabled: visible && Settings.data.general.enableBlurBehind && !PowerProfileService.performanceMode
    layer.smooth: false
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 48
    }
  }

  // Pre-blurred variant (nosd-blur output, exact screen size)
  Image {
    id: blurredImage
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    source: liveImage.usePreBlurred ? root.resolvedBlurredPath : ""
    cache: false
    asynchronous: true
    smooth: true
    mipmap: false
    antialiasing: true
    visible: source !== "" && status === Image.Ready
  }

  // Top and bottom fade bands (DESIGN §1.8). Upstream copies the wallpaper
  // strip and masks it with a white -> transparent gradient
  // (gradientlabel.cpp:41-72, TOP_BOTTOM_GRADIENT_HEIGHT in constants.h:41);
  // over the black base that reads as a fade to black on both ends.
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.launcherGradientBand
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Color.mShadow
      }
      GradientStop {
        position: 1.0
        color: Qt.alpha(Color.mShadow, 0)
      }
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.launcherGradientBand
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.alpha(Color.mShadow, 0)
      }
      GradientStop {
        position: 1.0
        color: Color.mShadow
      }
    }
  }
}

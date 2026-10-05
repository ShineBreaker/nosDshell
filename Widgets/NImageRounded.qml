import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Commons

Item {
  id: root

  property real radius: 0
  property string imagePath: ""
  property string fallbackImagePath: ""
  property string fallbackIcon: ""
  property real fallbackIconSize: Style.fontSizeXXL
  property real borderWidth: 0
  property color borderColor: "transparent"
  property int imageFillMode: Image.PreserveAspectCrop

  // Latched so a failed primary image cannot bounce back once the fallback is showing
  property bool _primaryFailed: false
  onImagePathChanged: _primaryFailed = false

  readonly property bool _useFallback: fallbackImagePath !== "" && (imagePath === "" || _primaryFailed)
  readonly property string _effectiveSource: _useFallback ? fallbackImagePath : imagePath
  readonly property bool _isAnimated: _effectiveSource.toLowerCase().endsWith(".gif")
  readonly property Item imageSource: imageSourceLoader.item
  // The glyph is the last resort: no image at all, or the fallback image itself failed
  readonly property bool showFallback: {
    if (fallbackIcon === "") {
      return false;
    }
    if (_effectiveSource === "") {
      return true;
    }
    return _useFallback && status === Image.Error;
  }
  readonly property int status: imageSource ? imageSource.status : Image.Null

  // The Loader only tracks component load, so the image status has to report back here
  function noteImageStatus(imageStatus) {
    if (imageStatus === Image.Error && !root._useFallback) {
      root._primaryFailed = true;
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    border.width: root.borderWidth
    border.color: root.borderColor

    Loader {
      id: imageSourceLoader
      anchors.fill: parent
      anchors.margins: root.borderWidth
      active: root._effectiveSource !== ""
      sourceComponent: root._isAnimated ? animatedComponent : staticComponent
    }

    Component {
      id: staticComponent
      Image {
        visible: false
        source: root._effectiveSource
        mipmap: true
        smooth: true
        asynchronous: true
        antialiasing: true
        fillMode: root.imageFillMode
        onStatusChanged: root.noteImageStatus(status)
      }
    }

    Component {
      id: animatedComponent
      AnimatedImage {
        visible: false
        source: root._effectiveSource
        mipmap: true
        smooth: true
        asynchronous: true
        antialiasing: true
        fillMode: root.imageFillMode
        playing: true
        onStatusChanged: root.noteImageStatus(status)
      }
    }

    // Fallback texture provider to avoid null source warnings
    ShaderEffectSource {
      id: _safeFallback
      sourceItem: Rectangle {
        width: 1
        height: 1
        color: "transparent"
      }
      visible: false
      live: false
    }

    ShaderEffect {
      anchors.fill: parent
      anchors.margins: root.borderWidth
      visible: !root.showFallback && root.imageSource !== null && root.status === Image.Ready
      property var source: root.imageSource ?? _safeFallback
      property real itemWidth: width
      property real itemHeight: height
      property real sourceWidth: root.imageSource?.sourceSize.width ?? 0
      property real sourceHeight: root.imageSource?.sourceSize.height ?? 0
      property real cornerRadius: Math.max(0, root.radius - root.borderWidth)
      property real imageOpacity: 1.0
      property int fillMode: root.imageFillMode

      fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/rounded_image.frag.qsb")
      supportsAtlasTextures: false
      blending: true
    }

    NIcon {
      anchors.fill: parent
      anchors.margins: root.borderWidth
      visible: root.showFallback
      icon: root.fallbackIcon
      pointSize: root.fallbackIconSize
    }
  }
}

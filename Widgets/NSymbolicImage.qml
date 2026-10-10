import QtQuick
import Quickshell
import qs.Commons

// Symbolic monochrome artwork (DESIGN §1.9): repaints the source's alpha as a
// flat silhouette in `color`, so baked-white DDE glyphs follow the surface
// foreground like NIcon does. Single-color assets only — multicolor artwork
// would lose its hues to the tint.
Image {
  id: root

  // Surface ink: Color.onShell on theme surfaces, Color.onWallpaper on the
  // always-dark wallpaper surfaces (DESIGN §1.3/§1.5).
  property color color: Color.onShell
  // Set false to render the source pixels untouched (multicolor assets).
  property bool symbolic: true

  layer.enabled: root.symbolic && root.source.toString() !== ""
  layer.effect: ShaderEffect {
    property color targetColor: root.color
    property real colorizeMode: 3.0
    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
  }
}

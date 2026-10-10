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
  // When true, tint only freedesktop *-symbolic sources
  // (ThemeIcons.isSymbolicPath); colored icons and photos pass through.
  property bool detectSymbolic: false

  // Symbol glyphs and icons must never be cropped or stretched.
  fillMode: Image.PreserveAspectFit

  layer.enabled: root.source.toString() !== "" && (root.detectSymbolic ? ThemeIcons.isSymbolicPath(root.source) : root.symbolic)
  layer.effect: ShaderEffect {
    property color targetColor: root.color
    property real colorizeMode: 3.0
    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
  }
}

import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

// The shared fashion-dock tile (DESIGN §3.1.4): a single icon on a rounded
// chip inside a tile+pluginSpacing cell. Widgets whose bar content (text
// pills, live graphs, multi-glyph rows) has no fashion equivalent hide their
// bar content in fashion mode and expose only the icon plus their primary
// action through this tile. The NIconButton-based plugins express the same
// tile inline (Trash, DarkMode, ...).
NIconButton {
  id: root

  applyUiScale: false
  baseSize: Style.dockPluginCellSize
  bgSize: Style.dockPluginTileSize
  iconRatio: 0.45
  customRadius: Style.radiusPopup
  colorBg: Settings.data.dock.fusedPlugins ? "transparent" : Colors.overlay("subtle")
  colorBgHover: Colors.overlay("hover")
  colorFg: Colors.onShell
  border.width: 0
}

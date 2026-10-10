import qs.Commons
import qs.Widgets

// Shared displayMode picker for bar pill widget settings. KeyboardLayout is
// the one variant: it offers forceOpen instead of alwaysShow (consumed
// together with showIcon in Modules/Bar/Widgets/KeyboardLayout.qml:85).
NComboBox {
  id: root

  property bool useForceOpen: false

  label: I18n.tr("common.display-mode")
  description: I18n.tr("common.display-mode-description")
  minimumWidth: 200
  model: [
    {
      "key": "onhover",
      "name": I18n.tr("display-modes.on-hover")
    },
    {
      "key": root.useForceOpen ? "forceOpen" : "alwaysShow",
      "name": I18n.tr(root.useForceOpen ? "display-modes.force-open" : "display-modes.always-show")
    },
    {
      "key": "alwaysHide",
      "name": I18n.tr("display-modes.always-hide")
    }
  ]
}

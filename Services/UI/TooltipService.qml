pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Tooltip

// TooltipService — one shared Tooltip popup for the whole shell.
//
// The instance is created once and never destroyed: it is only shown and
// hidden. Destroying a PopupWindow on the hover path (per-icon
// create/destroy while sweeping across dock items) frees windows that Qt's
// hover delivery still references and segfaults inside
// QQuickItem::isVisible(). Retargeting the live instance is always safe:
// Tooltip.show() already stops its timers and restarts the show delay.
Singleton {
  id: root

  // Currently visible tooltip, or null. Read by live-value cards
  // (SystemMonitorCard) to refresh the text of the tooltip they own.
  property var activeTooltip: null

  property Component tooltipComponent: Component {
    Tooltip {}
  }

  // The single shared instance, created lazily on first show.
  property var _instance: null

  function _ensureInstance() {
    if (!_instance) {
      _instance = tooltipComponent.createObject(null);
      if (_instance) {
        _instance.visibleChanged.connect(() => {
          if (!_instance.visible && activeTooltip === _instance) {
            activeTooltip = null;
          }
        });
      } else {
        Logger.e("Tooltip", "Failed to create tooltip instance");
      }
    }
    return _instance;
  }

  function show(target, content, direction, delay, fontFamily) {
    if (!Settings.data.ui.tooltipsEnabled) {
      return null;
    }

    // Don't create if no content
    if (!target || !content || (Array.isArray(content) && content.length === 0)) {
      Logger.i("Tooltip", "No target or content");
      return null;
    }

    const tip = _ensureInstance();
    if (!tip) {
      return null;
    }

    // If we already have a tooltip for this target, just update it
    if (tip.targetItem === target && tip.visible) {
      tip.updateContent(content);
    } else {
      tip.show(target, content, direction || "auto", delay || Style.tooltipDelay, fontFamily);
    }
    activeTooltip = tip;
    return tip;
  }

  function hide(target) {
    // If target is provided, only hide if tooltip belongs to that target
    if (!_instance) {
      return;
    }
    if (target) {
      if (_instance.targetItem === target) {
        _instance.hide();
      }
    } else {
      _instance.hide();
    }
  }

  function hideImmediately() {
    if (_instance) {
      _instance.hideImmediately();
    }
  }

  function updateContent(newContent) {
    if (activeTooltip) {
      activeTooltip.updateContent(newContent);
    }
  }

  // Backward compatibility alias
  function updateText(newText) {
    updateContent(newText);
  }
}

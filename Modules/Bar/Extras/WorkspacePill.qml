import QtQuick
import "../../../Commons/WorkspaceQuery.js" as WorkspaceQuery
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

Item {
  id: pillContainer

  required property var workspace
  required property bool isVertical

  // These must be provided by the parent Workspace widget
  required property real baseDimensionRatio
  required property real capsuleHeight
  required property real barHeight
  required property string labelMode
  required property int fontWeight
  required property int characterCount
  required property real textRatio
  required property bool showLabelsOnlyWhenOccupied
  required property string focusedColor
  required property string occupiedColor
  required property string emptyColor
  required property real masterProgress
  required property bool effectsActive
  required property color effectColor
  required property var getWorkspaceWidth
  required property var getWorkspaceHeight

  // Fixed dimension (cross-axis) for visual pill
  readonly property real fixedDimension: Style.toOdd(capsuleHeight * baseDimensionRatio)

  // Animated pill dimensions (for visual pill, not container). The active
  // widening is a plain binding on ws.isActive — a State+Transition pair
  // once carried it, but the transitions named a never-declared "inactive"
  // state so they never matched and the width snapped. Behaviors below
  // animate every change (switch, occupancy, label) uniformly.
  property real pillWidth: isVertical ? fixedDimension : getWorkspaceWidth(workspace)
  property real pillHeight: isVertical ? getWorkspaceHeight(workspace) : fixedDimension

  // Container uses full barHeight on cross-axis for larger click area
  width: isVertical ? barHeight : getWorkspaceWidth(workspace)
  height: isVertical ? getWorkspaceHeight(workspace) : barHeight

  Rectangle {
    id: pill
    width: pillContainer.pillWidth
    height: pillContainer.pillHeight
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    radius: Style.radiusM
    z: 0

    color: {
      if (pillMouseArea.containsMouse)
        return Colors.mHover;
      if (workspace.isFocused)
        return Colors.resolveColorKey(focusedColor);
      if (workspace.isUrgent)
        return Colors.mError;
      if (workspace.isOccupied)
        return Colors.resolveColorKey(occupiedColor);
      return Qt.alpha(Colors.resolveColorKey(emptyColor), 0.3);
    }

    Behavior on color {
      enabled: !Colors.isTransitioning
      NColorAnim {
        duration: Style.motionSwitch
        curve: "swift"
      }
    }

    Loader {
      active: (labelMode !== "none") && (!showLabelsOnlyWhenOccupied || workspace.isOccupied || workspace.isFocused)
      anchors.fill: parent
      sourceComponent: Component {
        NText {
          // compact: vertical pill shows "序号+名字首字符", horizontal "序号 截断名"
          text: WorkspaceQuery.labelFor(workspace, labelMode, characterCount, isVertical)
          family: Settings.data.ui.fontFixed
          // Size based on the fixed dimension (cross-axis) of the visual pill
          pointSize: (isVertical ? pillContainer.pillWidth : pillContainer.pillHeight) * textRatio
          applyUiScale: false
          font.capitalization: Font.AllUppercase
          font.weight: fontWeight
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.Wrap
          color: {
            if (pillMouseArea.containsMouse)
              return Colors.mOnHover;
            if (workspace.isFocused)
              return Colors.resolveOnColorKey(focusedColor);
            if (workspace.isUrgent)
              return Colors.mOnError;
            if (workspace.isOccupied)
              return Colors.resolveOnColorKey(occupiedColor);
            return Colors.resolveOnColorKey(emptyColor);
          }

          Behavior on color {
            enabled: !Colors.isTransitioning
            NColorAnim {
              duration: Style.motionSwitch
              curve: "swift"
            }
          }
        }
      }
    }

    // Material 3-inspired smooth animations
    Behavior on scale {
      NAnim {
        duration: Style.motionSwitch
        curve: "overshoot"
      }
    }
    Behavior on opacity {
      NAnim {
        duration: Style.motionExpand
        curve: "out"
      }
    }
    Behavior on radius {
      NAnim {
        duration: Style.motionExpand
        curve: "expand"
      }
    }
  }

  Behavior on width {
    NAnim {
      duration: Style.motionExpand
      curve: "expand"
    }
  }
  Behavior on height {
    NAnim {
      duration: Style.motionExpand
      curve: "expand"
    }
  }
  Behavior on pillWidth {
    NAnim {
      duration: Style.motionExpand
      curve: "expand"
    }
  }
  Behavior on pillHeight {
    NAnim {
      duration: Style.motionExpand
      curve: "expand"
    }
  }

  // Full-height click area
  MouseArea {
    id: pillMouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onClicked: {
      CompositorService.switchToWorkspace(workspace);
    }
  }

  // Burst effect overlay for focused pill
  Rectangle {
    id: pillBurst
    anchors.centerIn: pill
    width: pillContainer.pillWidth + 18 * masterProgress * scale
    height: pillContainer.pillHeight + 18 * masterProgress * scale
    radius: width / 2
    color: "transparent"
    border.color: effectColor
    border.width: Math.max(1, Math.round((2 + 6 * (1.0 - masterProgress))))
    opacity: effectsActive && workspace.isFocused ? (1.0 - masterProgress) * 0.7 : 0
    visible: effectsActive && workspace.isFocused
    z: 1
  }
}

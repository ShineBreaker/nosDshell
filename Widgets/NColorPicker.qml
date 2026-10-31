import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property var screen
  property color selectedColor: "black"

  signal colorSelected(color color)

  // Dialog lifecycle mirrors NSectionEditor: one live instance, destroyed on close.
  property var _activeDialog: null

  Layout.margins: Style.borderS
  implicitWidth: Style.settingsFieldWidth
  implicitHeight: Math.round(Style.baseWidgetSize * 1.1)

  radius: Style.radiusItem
  color: Colors.overlay("field")
  border.color: Colors.borderShell
  border.width: Style.borderS

  // Minimized Look
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      var component = Qt.createComponent("NColorPickerDialog.qml");

      function instantiateAndOpen() {
        if (root._activeDialog) {
          try {
            root._activeDialog.close();
            root._activeDialog.destroy();
          } catch (e) {}
          root._activeDialog = null;
        }

        var dialog = component.createObject(root, {
                                               "selectedColor": selectedColor,
                                               "parent": Overlay.overlay,
                                               "screen": root.screen
                                             });

        if (dialog) {
          root._activeDialog = dialog;
          // Connect the dialog's signal to the picker's signal
          dialog.colorSelected.connect(function (color) {
            root.selectedColor = color;
            root.colorSelected(color);
          });
          dialog.closed.connect(() => {
                                  if (root._activeDialog === dialog) {
                                    root._activeDialog = null;
                                    dialog.destroy();
                                  }
                                });
          dialog.open();
        } else {
          Logger.e("NColorPicker", "Failed to create color picker dialog instance");
        }
      }

      if (component.status === Component.Ready) {
        instantiateAndOpen();
      } else if (component.status === Component.Error) {
        Logger.e("NColorPicker", component.errorString());
      } else {
        component.statusChanged.connect(function () {
          if (component.status === Component.Ready) {
            instantiateAndOpen();
          } else if (component.status === Component.Error) {
            Logger.e("NColorPicker", component.errorString());
          }
        });
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors {
        leftMargin: Style.marginL
        rightMargin: Style.marginL
      }
      spacing: Style.marginS

      // Color preview circle
      Rectangle {
        Layout.preferredWidth: root.height * 0.6
        Layout.preferredHeight: root.height * 0.6
        radius: Math.min(Style.iRadiusL, Layout.preferredWidth / 2)
        color: root.selectedColor
        border.color: Colors.borderShell
        border.width: Style.borderS
      }

      NText {
        text: root.selectedColor.toString().toUpperCase()
        family: Settings.data.ui.fontFixed
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      NIcon {
        icon: "color-picker"
        // Glyph box, not a wider slot. A larger icon centered in the row
        // left the pencil 2 px further from the right edge than the swatch
        // is from the left (both sides are marginL).
        pointSize: Style.fontSizeM
        color: Colors.onShellTertiary
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
      }
    }
  }
}

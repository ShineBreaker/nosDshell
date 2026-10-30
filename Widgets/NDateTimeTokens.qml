import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Rectangle {
  id: root

  // Live "now": the example column renders against the current time.
  // Same source as NClock — the Time singleton ticks every second.
  property var sampleDate: Time.now

  signal tokenClicked(string token)

  Layout.margins: Style.borderS
  color: Colors.overlay("field")
  border.color: Colors.borderShell
  border.width: Style.borderS
  radius: Style.radiusItem

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginS

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentHeight: tokensColumn.implicitHeight
      clip: true

      Column {
        id: tokensColumn
        width: parent.width

        Repeater {
          model: [
            // Common format combinations
            {
              "category": "Common",
              "token": "h:mm AP",
              "description": I18n.tr("widgets.datetime-tokens.common-12hour-time-minutes"),
              "example": "2:30 PM"
            },
            {
              "category": "Common",
              "token": "HH:mm",
              "description": I18n.tr("widgets.datetime-tokens.common-24hour-time-minutes"),
              "example": "14:30"
            },
            {
              "category": "Common",
              "token": "HH:mm:ss",
              "description": I18n.tr("widgets.datetime-tokens.common-24hour-time-seconds"),
              "example": "14:30:45"
            },
            {
              "category": "Common",
              "token": "ddd MMM d",
              "description": I18n.tr("widgets.datetime-tokens.common-weekday-month-day"),
              "example": "Mon Dec 25"
            },
            {
              "category": "Common",
              "token": "yyyy-MM-dd",
              "description": I18n.tr("widgets.datetime-tokens.common-iso-date"),
              "example": "2023-12-25"
            },
            {
              "category": "Common",
              "token": "MM/dd/yyyy",
              "description": I18n.tr("widgets.datetime-tokens.common-us-date"),
              "example": "12/25/2023"
            },
            {
              "category": "Common",
              "token": "dd.MM.yyyy",
              "description": I18n.tr("widgets.datetime-tokens.common-european-date"),
              "example": "25.12.2023"
            },
            {
              "category": "Common",
              "token": "ddd, MMM dd",
              "description": I18n.tr("widgets.datetime-tokens.common-weekday-date"),
              "example": "Fri, Dec 12"
            } // Hour tokens
            ,
            {
              "category": "Hour",
              "token": "H",
              "description": I18n.tr("widgets.datetime-tokens.hour-no-leading-zero"),
              "example": "14"
            },
            {
              "category": "Hour",
              "token": "HH",
              "description": I18n.tr("widgets.datetime-tokens.hour-leading-zero"),
              "example": "14"
            } // Minute tokens
            ,
            {
              "category": "Minute",
              "token": "m",
              "description": I18n.tr("widgets.datetime-tokens.minute-no-leading-zero"),
              "example": "30"
            },
            {
              "category": "Minute",
              "token": "mm",
              "description": I18n.tr("widgets.datetime-tokens.minute-leading-zero"),
              "example": "30"
            } // Second tokens
            ,
            {
              "category": "Second",
              "token": "s",
              "description": I18n.tr("widgets.datetime-tokens.second-no-leading-zero"),
              "example": "45"
            },
            {
              "category": "Second",
              "token": "ss",
              "description": I18n.tr("widgets.datetime-tokens.second-leading-zero"),
              "example": "45"
            } // AM/PM tokens
            ,
            {
              "category": "AM/PM",
              "token": "AP",
              "description": I18n.tr("widgets.datetime-tokens.ampm-uppercase"),
              "example": "PM"
            },
            {
              "category": "AM/PM",
              "token": "ap",
              "description": I18n.tr("widgets.datetime-tokens.ampm-lowercase"),
              "example": "pm"
            } // Timezone tokens
            ,
            {
              "category": "Timezone",
              "token": "t",
              "description": I18n.tr("widgets.datetime-tokens.timezone-abbreviation"),
              "example": "UTC"
            } // Year tokens
            ,
            {
              "category": "Year",
              "token": "yy",
              "description": I18n.tr("widgets.datetime-tokens.year-two-digit"),
              "example": "23"
            },
            {
              "category": "Year",
              "token": "yyyy",
              "description": I18n.tr("widgets.datetime-tokens.year-four-digit"),
              "example": "2023"
            } // Month tokens
            ,
            {
              "category": "Month",
              "token": "M",
              "description": I18n.tr("widgets.datetime-tokens.month-number-no-zero"),
              "example": "12"
            },
            {
              "category": "Month",
              "token": "MM",
              "description": I18n.tr("widgets.datetime-tokens.month-number-leading-zero"),
              "example": "12"
            },
            {
              "category": "Month",
              "token": "MMM",
              "description": I18n.tr("widgets.datetime-tokens.month-abbreviated"),
              "example": "Dec"
            },
            {
              "category": "Month",
              "token": "MMMM",
              "description": I18n.tr("widgets.datetime-tokens.month-full"),
              "example": "December"
            } // Day tokens
            ,
            {
              "category": "Day",
              "token": "d",
              "description": I18n.tr("widgets.datetime-tokens.day-no-leading-zero"),
              "example": "25"
            },
            {
              "category": "Day",
              "token": "dd",
              "description": I18n.tr("widgets.datetime-tokens.day-leading-zero"),
              "example": "25"
            },
            {
              "category": "Day",
              "token": "ddd",
              "description": I18n.tr("widgets.datetime-tokens.day-abbreviated"),
              "example": "Mon"
            },
            {
              "category": "Day",
              "token": "dddd",
              "description": I18n.tr("widgets.datetime-tokens.day-full"),
              "example": "Monday"
            }
          ]

          delegate: Rectangle {
            id: tokenDelegate
            width: tokensColumn.width
            height: layout.implicitHeight + Style.marginS
            radius: Style.radiusItem
            color: tokenMouseArea.containsMouse ? Colors.overlay("checked") : Colors.overlay("strong")

            // Mouse area for the entire delegate
            MouseArea {
              id: tokenMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: {
                root.tokenClicked(modelData.token);
                clickAnimation.start();
              }
            }

            // Click animation
            SequentialAnimation {
              id: clickAnimation
              NColorAnim {
                target: tokenDelegate
                property: "color"
                to: Qt.alpha(Colors.accent, 0.3)
                duration: Style.motionPointer
              }
              NColorAnim {
                target: tokenDelegate
                property: "color"
                to: tokenMouseArea.containsMouse ? Colors.overlay("checked") : Colors.overlay("strong")
                duration: Style.motionPointer
              }
            }

            RowLayout {
              id: layout
              anchors.fill: parent
              anchors.margins: Style.marginXS
              spacing: Style.marginM

              // Category badge
              Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 70
                height: 22
                color: getCategoryColor(modelData.category)[0]
                radius: Style.radiusItem
                opacity: tokenMouseArea.containsMouse ? 0.9 : 1.0

                NText {
                  anchors.centerIn: parent
                  text: modelData.category
                  color: getCategoryColor(modelData.category)[1]
                  pointSize: Style.fontSizeXS
                }
              }

              // Token - Made more prominent and clickable
              Rectangle {
                id: tokenButton
                Layout.alignment: Qt.AlignVCenter // Added this line
                width: 100
                height: 22
                color: tokenMouseArea.containsMouse ? Colors.accent : Colors.overlay("checked")
                radius: Style.radiusItem

                NText {
                  anchors.centerIn: parent
                  text: modelData.token
                  color: tokenMouseArea.containsMouse ? Colors.onAccent : Colors.onShell
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightSemiBold
                }
              }

              // Description
              NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter // Added this line
                text: modelData.description
                color: tokenMouseArea.containsMouse ? Colors.onShell : Colors.onShellTertiary
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
              }

              // Live example
              Rectangle {
                Layout.alignment: Qt.AlignVCenter // Added this line
                width: 90
                height: 22
                color: tokenMouseArea.containsMouse ? Colors.accent : Colors.overlay("checked")
                radius: Style.radiusItem
                border.color: tokenMouseArea.containsMouse ? Colors.accent : Colors.borderShell
                border.width: Style.borderS

                NText {
                  anchors.centerIn: parent
                  text: I18n.locale.toString(root.sampleDate, modelData.token)
                  color: tokenMouseArea.containsMouse ? Colors.onAccent : Colors.onShellTertiary
                  pointSize: Style.fontSizeS
                }
              }
            }
          }
        }
      }
    }
  }

  function getCategoryColor(category) {
    switch (category) {
    case "Year":
      return [Colors.accent, Colors.onAccent];
    case "Month":
      return [Colors.accentAlt, Colors.onAccent];
    case "Day":
      return [Colors.accentAction, Colors.onAccent];
    case "Hour":
      return [Colors.accent, Colors.onAccent];
    case "Minute":
      return [Colors.accentAlt, Colors.onAccent];
    case "Second":
      return [Colors.accentAction, Colors.onAccent];
    case "AM/PM":
      return [Colors.alert, Colors.onAccent];
    case "Timezone":
      return [Colors.overlay("checked"), Colors.onShell];
    case "Common":
      return [Colors.alert, Colors.onAccent];
    default:
      return [Colors.overlay("strong"), Colors.onShellTertiary];
    }
  }
}

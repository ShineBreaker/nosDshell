import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Cards
import qs.Modules.MainScreen
import qs.Services.Location
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// DDE datetime dock applet: calendar grid + optional weather section.
// Driven by Settings.data.calendar.cards like the old card panel.
SmartPanel {
  id: root

  dimsBackground: false

  panelContent: Item {
    id: panelContent

    anchors.fill: parent

    readonly property real contentPreferredWidth: Math.round((Settings.data.location.showWeekNumberInCalendar ? 330 : 300) * Style.uiScaleRatio)
    readonly property real contentPreferredHeight: Math.min(content.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    function cardEnabled(cardId) {
      for (let i = 0; i < Settings.data.calendar.cards.length; i++) {
        const c = Settings.data.calendar.cards[i];
        if (c.id === cardId)
          return c.enabled;
      }
      return cardId !== "weather-card" ? true : Settings.data.location.weatherEnabled;
    }

    NScrollView {
      id: scrollView
      anchors.fill: parent
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      contentWidth: availableWidth

      ColumnLayout {
        id: content
        width: scrollView.availableWidth
        spacing: Style.marginS

        // ---- Date header ----
        Loader {
          active: panelContent.cardEnabled("calendar-header-card")
          visible: active
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          Layout.topMargin: Style.marginM

          sourceComponent: Item {
            readonly property var now: Time.now

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginM
              spacing: Style.marginS

              NText {
                text: Time.now.getDate()
                pointSize: Style.fontSizeXXL
                font.weight: Style.fontWeightBold
                color: Color.accent
              }

              NText {
                Layout.fillWidth: true
                text: I18n.locale.monthName(Time.now.getMonth(), Locale.LongFormat) + " " + Time.now.getFullYear()
                pointSize: Style.fontSizeM
                elide: Text.ElideRight
              }

              NText {
                text: I18n.locale.dayName(Time.now.getDay(), Locale.LongFormat)
                pointSize: Style.fontSizeS
                color: Color.onShellSecondary
              }
            }
          }
        }

        // ---- Month navigation + grid ----
        Loader {
          id: monthSection
          active: panelContent.cardEnabled("calendar-month-card")
          visible: active
          Layout.fillWidth: true

          sourceComponent: ColumnLayout {
            id: monthRoot

            spacing: Style.marginXS

            readonly property var now: Time.now
            property int calendarMonth: now.getMonth()
            property int calendarYear: now.getFullYear()
            readonly property int firstDayOfWeek: Settings.data.location.firstDayOfWeek === -1 ? I18n.locale.firstDayOfWeek : Settings.data.location.firstDayOfWeek

            function getISOWeekNumber(date) {
              const target = new Date(date.valueOf());
              const dayNr = (date.getDay() + 6) % 7;
              target.setDate(target.getDate() - dayNr + 3);
              const firstThursday = new Date(target.getFullYear(), 0, 4);
              const diff = target - firstThursday;
              const oneWeek = 1000 * 60 * 60 * 24 * 7;
              return 1 + Math.round(diff / oneWeek);
            }

            function isAllDayEvent(event) {
              const duration = event.end - event.start;
              const startDate = new Date(event.start * 1000);
              const isAtMidnight = startDate.getHours() === 0 && startDate.getMinutes() === 0;
              return duration === 86400 && isAtMidnight;
            }

            function navigateToPreviousMonth() {
              let newDate = new Date(calendarYear, calendarMonth - 1, 1);
              calendarYear = newDate.getFullYear();
              calendarMonth = newDate.getMonth();
              loadWindow();
            }

            function navigateToNextMonth() {
              let newDate = new Date(calendarYear, calendarMonth + 1, 1);
              calendarYear = newDate.getFullYear();
              calendarMonth = newDate.getMonth();
              loadWindow();
            }

            function loadWindow() {
              const now = new Date();
              const monthStart = new Date(calendarYear, calendarMonth, 1);
              const monthEnd = new Date(calendarYear, calendarMonth + 1, 0);
              const daysBehind = Math.max(0, Math.ceil((now - monthStart) / (24 * 60 * 60 * 1000)));
              const daysAhead = Math.max(0, Math.ceil((monthEnd - now) / (24 * 60 * 60 * 1000)));
              CalendarService.loadEvents(daysAhead + 30, daysBehind + 30);
            }

            function hasEventsOnDate(year, month, day) {
              if (!CalendarService.available || CalendarService.events.length === 0)
                return false;
              const targetDate = new Date(year, month, day);
              const targetStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate()).getTime() / 1000;
              const targetEnd = targetStart + 86400;
              return CalendarService.events.some(event => {
                                                   return (event.start >= targetStart && event.start < targetEnd) || (event.end > targetStart && event.end <= targetEnd) || (event.start < targetStart && event.end > targetEnd);
                                                 });
            }

            function getEventsForDate(year, month, day) {
              if (!CalendarService.available || CalendarService.events.length === 0)
                return [];
              const targetDate = new Date(year, month, day);
              const targetStart = Math.floor(new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate()).getTime() / 1000);
              const targetEnd = targetStart + 86400;
              return CalendarService.events.filter(event => {
                                                     return (event.start >= targetStart && event.start < targetEnd) || (event.end > targetStart && event.end <= targetEnd) || (event.start < targetStart && event.end > targetEnd);
                                                   });
            }

            WheelHandler {
              target: monthRoot
              acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
              onWheel: function (event) {
                if (event.angleDelta.y > 0) {
                  monthRoot.navigateToPreviousMonth();
                  event.accepted = true;
                } else if (event.angleDelta.y < 0) {
                  monthRoot.navigateToNextMonth();
                  event.accepted = true;
                }
              }
            }

            // Navigation row: flat chevrons + month label
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 36

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginS
                spacing: Style.marginXS

                NText {
                  Layout.fillWidth: true
                  text: I18n.locale.monthName(monthRoot.calendarMonth, Locale.LongFormat) + " " + monthRoot.calendarYear
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                }

                NIconButton {
                  icon: "chevron-left"
                  colorFg: Color.onShell
                  onClicked: monthRoot.navigateToPreviousMonth()
                }

                NIconButton {
                  icon: "calendar"
                  colorFg: Color.onShell
                  tooltipText: I18n.tr("common.today")
                  onClicked: {
                    monthRoot.calendarMonth = monthRoot.now.getMonth();
                    monthRoot.calendarYear = monthRoot.now.getFullYear();
                    CalendarService.loadEvents();
                  }
                }

                NIconButton {
                  icon: "chevron-right"
                  colorFg: Color.onShell
                  onClicked: monthRoot.navigateToNextMonth()
                }
              }
            }

            // Weekday header
            RowLayout {
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginM
              Layout.rightMargin: Style.marginM
              spacing: 0

              Item {
                visible: Settings.data.location.showWeekNumberInCalendar
                Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.7 : 0
              }

              GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 0

                Repeater {
                  model: 7
                  Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.fontSizeS * 2

                    NText {
                      anchors.centerIn: parent
                      text: {
                        let dayIndex = (monthRoot.firstDayOfWeek + index) % 7;
                        return I18n.locale.dayName(dayIndex, Locale.ShortFormat).substring(0, 2).toUpperCase();
                      }
                      color: Color.onShellSecondary
                      pointSize: Style.fontSizeS
                      font.weight: Style.fontWeightBold
                      horizontalAlignment: Text.AlignHCenter
                    }
                  }
                }
              }
            }

            // Day grid with optional week numbers
            RowLayout {
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginM
              Layout.rightMargin: Style.marginM
              spacing: 0

              ColumnLayout {
                visible: Settings.data.location.showWeekNumberInCalendar
                Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.7 : 0
                Layout.alignment: Qt.AlignTop
                spacing: Style.marginXXS

                property var weekNumbers: {
                  if (!grid.daysModel || grid.daysModel.length === 0)
                    return [];
                  const weeks = [];
                  const numWeeks = Math.ceil(grid.daysModel.length / 7);
                  for (var i = 0; i < numWeeks; i++) {
                    const dayIndex = i * 7;
                    if (dayIndex < grid.daysModel.length) {
                      const weekDay = grid.daysModel[dayIndex];
                      const date = new Date(weekDay.year, weekDay.month, weekDay.day);
                      let thursday = new Date(date);
                      if (monthRoot.firstDayOfWeek === 0) {
                        thursday.setDate(date.getDate() + 4);
                      } else if (monthRoot.firstDayOfWeek === 1) {
                        thursday.setDate(date.getDate() + 3);
                      } else {
                        let daysToThursday = (4 - monthRoot.firstDayOfWeek + 7) % 7;
                        thursday.setDate(date.getDate() + daysToThursday);
                      }
                      weeks.push(monthRoot.getISOWeekNumber(thursday));
                    }
                  }
                  return weeks;
                }

                Repeater {
                  model: parent.weekNumbers
                  Item {
                    Layout.preferredWidth: Style.baseWidgetSize * 0.7
                    Layout.preferredHeight: Style.baseWidgetSize * 0.9

                    NText {
                      anchors.centerIn: parent
                      color: Color.onShellTertiary
                      pointSize: Style.fontSizeXXS
                      text: modelData
                    }
                  }
                }
              }

              GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: 7
                columnSpacing: Style.marginXXS
                rowSpacing: Style.marginXXS

                property int month: monthRoot.calendarMonth
                property int year: monthRoot.calendarYear

                property var daysModel: {
                  const firstOfMonth = new Date(year, month, 1);
                  const lastOfMonth = new Date(year, month + 1, 0);
                  const daysInMonth = lastOfMonth.getDate();
                  const firstDayOfWeek = monthRoot.firstDayOfWeek;
                  const firstOfMonthDayOfWeek = firstOfMonth.getDay();
                  let daysBefore = (firstOfMonthDayOfWeek - firstDayOfWeek + 7) % 7;
                  const lastOfMonthDayOfWeek = lastOfMonth.getDay();
                  const daysAfter = (firstDayOfWeek - lastOfMonthDayOfWeek - 1 + 7) % 7;
                  const days = [];
                  const today = new Date();

                  const prevMonth = new Date(year, month, 0);
                  const prevMonthDays = prevMonth.getDate();
                  for (var i = daysBefore - 1; i >= 0; i--) {
                    const day = prevMonthDays - i;
                    days.push({
                                "day": day,
                                "month": month - 1,
                                "year": month === 0 ? year - 1 : year,
                                "today": false,
                                "currentMonth": false
                              });
                  }

                  for (var day = 1; day <= daysInMonth; day++) {
                    const date = new Date(year, month, day);
                    const isToday = date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate();
                    days.push({
                                "day": day,
                                "month": month,
                                "year": year,
                                "today": isToday,
                                "currentMonth": true
                              });
                  }

                  for (var i = 1; i <= daysAfter; i++) {
                    days.push({
                                "day": i,
                                "month": month + 1,
                                "year": month === 11 ? year + 1 : year,
                                "today": false,
                                "currentMonth": false
                              });
                  }

                  return days;
                }

                Repeater {
                  model: grid.daysModel

                  Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.baseWidgetSize * 0.9

                    Rectangle {
                      width: Style.baseWidgetSize * 0.9
                      height: Style.baseWidgetSize * 0.9
                      anchors.centerIn: parent
                      // DDE: today is an accent filled circle
                      radius: width / 2
                      color: modelData.today ? Color.accent : (cellMouse.containsMouse ? Color.overlay("hover") : "transparent")

                      NText {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: {
                          if (modelData.today)
                            return Color.onAccent;
                          if (modelData.currentMonth)
                            return Color.onShell;
                          return Color.onShellTertiary;
                        }
                        pointSize: Style.fontSizeM
                        font.weight: modelData.today ? Style.fontWeightBold : Style.fontWeightMedium
                      }

                      // Event indicator dots
                      Row {
                        visible: Settings.data.location.showCalendarEvents && monthRoot.hasEventsOnDate(modelData.year, modelData.month, modelData.day)
                        spacing: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Style.marginXXS

                        Repeater {
                          model: monthRoot.getEventsForDate(modelData.year, modelData.month, modelData.day)

                          Rectangle {
                            width: 4
                            height: width
                            radius: 2
                            color: modelData.today ? Color.onAccent : Color.accent
                          }
                        }
                      }

                      MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                          const events = monthRoot.getEventsForDate(modelData.year, modelData.month, modelData.day);
                          if (events.length > 0) {
                            const summaries = events.map(event => {
                                                           if (monthRoot.isAllDayEvent(event)) {
                                                             return event.summary;
                                                           } else {
                                                             const timeFormat = Settings.data.location.use12hourFormat ? "hh:mm AP" : "HH:mm";
                                                             const start = new Date(event.start * 1000);
                                                             const startFormatted = I18n.locale.toString(start, timeFormat);
                                                             const end = new Date(event.end * 1000);
                                                             const endFormatted = I18n.locale.toString(end, timeFormat);
                                                             return `${startFormatted}-${endFormatted} ${event.summary}`;
                                                           }
                                                         }).join('\n');
                            TooltipService.show(parent, summaries, "auto", Style.tooltipDelay, Settings.data.ui.fontFixed);
                          }
                        }

                        onClicked: {
                          const dateWithSlashes = `${(modelData.month + 1).toString().padStart(2, '0')}/${modelData.day.toString().padStart(2, '0')}/${modelData.year.toString().substring(2)}`;
                          if (ProgramCheckerService.gnomeCalendarAvailable) {
                            Quickshell.execDetached(["gnome-calendar", "--date", dateWithSlashes]);
                          }
                        }

                        onExited: {
                          TooltipService.hide();
                        }
                      }

                      Behavior on color {
                        ColorAnimation {
                          duration: Style.animationFast
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ---- Weather ----
        Loader {
          active: panelContent.cardEnabled("weather-card") && Settings.data.location.weatherEnabled && LocationService.data.weather !== null
          visible: active
          Layout.fillWidth: true

          sourceComponent: ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NPanelSection {
              Layout.fillWidth: true
              text: I18n.tr("common.weather")
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 36

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginM
                spacing: Style.marginS

                NIcon {
                  icon: LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode)
                  pointSize: Style.fontSizeXL
                  color: Color.accent
                }

                NText {
                  text: {
                    var temp = LocationService.data.weather.current_weather.temperature;
                    var suffix = "C";
                    if (Settings.data.location.useFahrenheit) {
                      temp = LocationService.celsiusToFahrenheit(temp);
                      suffix = "F";
                    }
                    return `${Math.round(temp)}°${suffix}`;
                  }
                  pointSize: Style.fontSizeL
                  font.weight: Style.fontWeightBold
                }

                NText {
                  Layout.fillWidth: true
                  visible: !Settings.data.location.hideWeatherCityName
                  text: Settings.data.location.name.split(",")[0]
                  pointSize: Style.fontSizeS
                  color: Color.onShellSecondary
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }
  }
}

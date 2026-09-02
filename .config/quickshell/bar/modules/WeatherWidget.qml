// WeatherWidget.qml — weather card for the notification center, sitting directly
// above CalendarView.
//
// Layout follows Apple's large Weather widget: header (location + large
// temperature, condition and high/low right-aligned), an hourly strip with the
// next sunrise/sunset threaded in among the hours, and five daily rows whose
// range bars are positioned and gradient-filled across the week's spread.
// The palette is the shell's, not Apple's — see Theme.weather* .
import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    implicitWidth:  parent ? parent.width : Theme.notifCardWidth
    implicitHeight: card.implicitHeight

    readonly property bool hasData: WeatherService.ready

    // Surface colours, overridable so the same widget can sit on a different
    // background. Defaults are the notification-centre palette it was drawn for;
    // the lock screen passes transparents to strip the card down to bare content.
    property color cardColor:    Theme.notifCardBg
    property color borderColor:  Theme.notifUnreadBorder
    property color dividerColor: Theme.notifBorderDim

    function deg(v) { return Math.round(v) + "°" }

    Rectangle {
        id: card
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        // Height is pinned while empty so the panel below does not jump once the
        // first fetch lands and `content` starts reporting a real height.
        implicitHeight: root.hasData ? content.implicitHeight + 28 : 240

        radius:       Theme.radius
        // Flat, same surface as the notification cards above it in this panel.
        // Day/night still reads from the condition glyph.
        color:        root.cardColor
        border.color: root.borderColor
        border.width: 1

        // ── Empty / unreachable state ─────────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            visible: !root.hasData
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: WeatherService.loading
                      ? WeatherService.refreshIcon
                      : WeatherService.offlineIcon
                font.family:    Theme.iconFamily
                font.pixelSize: Theme.weatherIconSize
                color:          Theme.fgDim

                RotationAnimator on rotation {
                    running: WeatherService.loading && !root.hasData
                    from: 0; to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: WeatherService.loading ? "Loading weather…" : "Weather unavailable"
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color:          Theme.fgDim
            }
        }

        ColumnLayout {
            id: content
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.margins:    14
            visible: root.hasData
            spacing: 10

            // ── Header ────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight

                RowLayout {
                    id: headerRow
                    anchors.left:  parent.left
                    anchors.right: parent.right
                    anchors.top:   parent.top
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: WeatherService.locationName !== ""
                                      ? WeatherService.locationName
                                      : "Unknown location"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight:    Font.Medium
                                color:          Theme.fg
                                elide:          Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Spins while fetching, and marks the reading as old once
                            // it is past Theme.weatherStaleMs (offline, or suspended).
                            Text {
                                visible: WeatherService.loading || WeatherService.stale
                                text:    WeatherService.refreshIcon
                                font.family:    Theme.iconFamily
                                font.pixelSize: Theme.fontSize
                                color:   WeatherService.stale && !WeatherService.loading
                                         ? Theme.red : Theme.fgDim

                                RotationAnimator on rotation {
                                    running: WeatherService.loading
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }
                        }

                        Text {
                            text: root.deg(WeatherService.temp)
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.weatherTempSize
                            font.weight:    Font.Light
                            color:          Theme.fg
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        spacing: 1

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: WeatherService.codeIcon(WeatherService.code, WeatherService.isDay)
                            font.family:    Theme.iconFamily
                            font.pixelSize: Theme.weatherIconSize
                            color:          Theme.fg
                        }

                        Item { Layout.preferredHeight: 4 }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: WeatherService.codeLabel(WeatherService.code)
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color:          Theme.fg
                        }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: "H:" + root.deg(WeatherService.todayMax)
                                + "  L:" + root.deg(WeatherService.todayMin)
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color:          Theme.fgDim
                        }
                    }
                }

                // Manual refresh — the escape hatch when the card is showing
                // stale data. Scoped to the header so the rest of the card
                // stays a plain read-only surface.
                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    WeatherService.refresh()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  root.dividerColor
            }

            // ── Hourly strip ──────────────────────────────────────────────
            Row {
                id: hourStrip
                Layout.fillWidth: true
                property real slotWidth: width / Theme.weatherHourSlots

                Repeater {
                    model: WeatherService.hourlyModel

                    delegate: Column {
                        required property var model

                        width:   hourStrip.slotWidth
                        spacing: 4

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text:  model.label
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            color:          Theme.fgDim
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            // A "sun" slot is a sunrise/sunset marker, not a
                            // forecast hour, so it gets its own glyph and tint.
                            text: model.kind === "sun"
                                  ? WeatherService.sunIcon
                                  : WeatherService.codeIcon(model.code, model.isDay === 1)
                            font.family:    Theme.iconFamily
                            font.pixelSize: Theme.weatherHourIconSize
                            color: model.kind === "sun" ? Theme.weatherSunTint : Theme.fg
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text:  model.temp + "°"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.weight:    Font.DemiBold
                            color:          Theme.fg
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  root.dividerColor
            }

            // ── Daily rows ────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: WeatherService.dailyModel

                    delegate: RowLayout {
                        required property var model

                        Layout.fillWidth: true
                        implicitHeight: Theme.weatherDayRowHeight
                        spacing: 8

                        Text {
                            text: model.label
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color:          Theme.fg
                            Layout.preferredWidth: 30
                        }

                        Text {
                            text: WeatherService.codeIcon(model.code, true)
                            font.family:    Theme.iconFamily
                            font.pixelSize: Theme.fontSize + 4
                            color:          Theme.fg
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: 22
                        }

                        Text {
                            text: model.minTemp + "°"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color:          Theme.fgDim
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 28
                        }

                        // Range bar: the row's low→high span placed inside the
                        // week's span, filled cold→warm across its own extent.
                        Rectangle {
                            id: track
                            Layout.fillWidth: true
                            implicitHeight: 4
                            radius: 2
                            color:  Theme.weatherTrackBg

                            readonly property real span:
                                Math.max(1, WeatherService.weekMax - WeatherService.weekMin)

                            Rectangle {
                                id: fill
                                height: parent.height
                                radius: parent.radius

                                // Floored so a day with a flat range still reads
                                // as a bar rather than vanishing.
                                readonly property real barWidth:
                                    Math.max(8, (model.maxTemp - model.minTemp)
                                                / track.span * track.width)

                                width: barWidth
                                // Clamped, so the 8px floor above cannot push a
                                // bar for the week's warmest day off the track.
                                x: Math.max(0, Math.min(
                                       (model.minTemp - WeatherService.weekMin)
                                       / track.span * track.width,
                                       track.width - barWidth))

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0.0
                                        color: WeatherService.tempColor(model.minTemp)
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: WeatherService.tempColor(model.maxTemp)
                                    }
                                }

                                Behavior on x     { NumberAnimation { duration: Theme.animMed } }
                                Behavior on width { NumberAnimation { duration: Theme.animMed } }
                            }
                        }

                        Text {
                            text: model.maxTemp + "°"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color:          Theme.fg
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 28
                        }
                    }
                }
            }
        }
    }
}

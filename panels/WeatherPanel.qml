import QtQuick
import qs.services
import qs.components

// Панель погоды (сейчас, почасовой и на 7 дней). Клавиша R / ПКМ — обновить.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_R) {
            Weather.refresh();
            event.accepted = true;
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Верхний ряд: сейчас + почасовой прогноз
        Row {
            width: parent.width
            spacing: Theme.px(10)

            // Текущая погода
            Rectangle {
                width: Theme.px(210)
                height: Theme.px(112)
                radius: Theme.px(20)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(14)
                    spacing: Theme.px(4)

                    Row {
                        spacing: Theme.px(5)
                        Icon { name: "location_on"; size: Theme.px(13); color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.city
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        spacing: Theme.px(8)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Weather.icon
                            size: Theme.px(32)
                            color: Theme.yellow
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: isNaN(Weather.temp) ? "--°" : Math.round(Weather.temp) + "°"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(32)
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        text: Weather.desc + " · Ощущ. " + (isNaN(Weather.feelsLike) ? "--" : Math.round(Weather.feelsLike) + "°")
                              + " · " + Math.round(Weather.wind) + " км/ч"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: Weather.refresh()
                }
            }

            // Почасовой
            Rectangle {
                id: hourlyCard
                width: parent.width - Theme.px(220)
                height: Theme.px(112)
                radius: Theme.px(20)
                color: Theme.card

                Row {
                    anchors.centerIn: parent
                    width: parent.width - Theme.px(20)

                    Repeater {
                        model: Weather.hourly.slice(0, 7)
                        Column {
                            required property var modelData
                            width: (hourlyCard.width - Theme.px(20)) / 7
                            spacing: Theme.px(6)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.time
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: modelData.icon
                                size: Theme.px(19)
                                color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.temp + "°"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }

        // Прогноз на 7 дней
        Rectangle {
            id: dailyCard
            width: parent.width
            height: Theme.px(88)
            radius: Theme.px(20)
            color: Theme.card

            Row {
                anchors.centerIn: parent
                width: parent.width - Theme.px(20)

                Repeater {
                    model: Weather.daily
                    Column {
                        required property var modelData
                        width: (dailyCard.width - Theme.px(20)) / 7
                        spacing: Theme.px(4)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.day
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon
                            size: Theme.px(18)
                            color: Theme.blue
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.max + "° / " + modelData.min + "°"
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                    }
                }
            }
        }
    }
}

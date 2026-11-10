import QtQuick
import qs.services
import qs.components

// Calendar panel. Hotkeys: ←/→ or mouse wheel — change month, T/Home — today.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property var viewDate: new Date()

    implicitWidth: Theme.px(510)
    implicitHeight: row.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { shiftMonth(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { shiftMonth(1); event.accepted = true; }
        else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) { viewDate = new Date(); event.accepted = true; }
    }

    readonly property string viewTitle: {
        const m = Qt.locale().standaloneMonthName(viewDate.getMonth(), Locale.LongFormat);
        const cap = m ? (m.charAt(0).toUpperCase() + m.slice(1)) : "";
        return cap + " " + viewDate.getFullYear();
    }
    readonly property var dayHeaders: {
        const loc = Qt.locale();
        const res = [];
        for (let i = 1; i <= 7; i++) {
            const d = loc.standaloneDayName(i, Locale.ShortFormat);
            res.push(d ? (d.charAt(0).toUpperCase() + d.slice(1)) : "");
        }
        return res;
    }

    function shiftMonth(delta) {
        const d = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1);
        viewDate = d;
    }

    readonly property var cells: {
        const y = viewDate.getFullYear();
        const m = viewDate.getMonth();
        const first = new Date(y, m, 1);
        const startOffset = (first.getDay() + 6) % 7; // Mon = 0
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const daysInPrev = new Date(y, m, 0).getDate();
        const now = new Date();

        const list = [];
        for (let i = 0; i < 42; i++) {
            const num = i - startOffset + 1;
            let day = num, cur = true;
            if (num <= 0) { day = daysInPrev + num; cur = false; }
            else if (num > daysInMonth) { day = num - daysInMonth; cur = false; }
            const isToday = cur && y === now.getFullYear() && m === now.getMonth() && day === now.getDate();
            list.push({ day: day, current: cur, today: isToday, weekend: (i % 7) >= 5 });
        }
        return list;
    }

    Row {
        id: row
        width: parent.width
        spacing: Theme.px(12)

        // Left card — today
        Rectangle {
            width: Theme.px(205)
            height: calCard.height
            radius: Theme.px(20)
            color: Theme.card

            Column {
                anchors.fill: parent
                anchors.margins: Theme.px(18)
                spacing: Theme.px(6)

                Text {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd")
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Bold
                    font.capitalization: Font.Capitalize
                }
                Text {
                    text: new Date().getDate().toString()
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(52)
                    font.weight: Font.Bold
                }
                Text {
                    text: new Date().toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                    font.capitalization: Font.Capitalize
                }

                Item { width: 1; height: Theme.px(14) }

                Row {
                    visible: Weather.ready
                    spacing: Theme.px(8)
                    Icon { name: Weather.icon; size: Theme.px(18); color: Weather.iconColor; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Weather.temp) + "° · " + Weather.desc
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // Right card — month grid (mouse wheel scrolls months)
        Rectangle {
            id: calCard
            width: parent.width - Theme.px(217)
            height: calCol.implicitHeight + Theme.px(28)
            radius: Theme.px(20)
            color: Theme.card

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: w => root.shiftMonth(w.angleDelta.y > 0 ? -1 : 1)
            }

            Column {
                id: calCol
                anchors.fill: parent
                anchors.margins: Theme.px(14)
                spacing: Theme.px(8)

                // Month header
                Item {
                    width: parent.width
                    height: Theme.px(28)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.viewTitle
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(15)
                        font.weight: Font.Bold
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.viewDate = new Date()
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(4)

                        Repeater {
                            model: [{ icon: "chevron_left", d: -1 }, { icon: "today", d: 0 }, { icon: "chevron_right", d: 1 }]
                            Rectangle {
                                id: navBtn
                                required property var modelData
                                width: Theme.px(28); height: width; radius: width / 2
                                color: navMa.containsMouse ? Theme.cardHover : "transparent"
                                Icon { anchors.centerIn: parent; name: navBtn.modelData.icon; size: Theme.px(16) }
                                MouseArea {
                                    id: navMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (navBtn.modelData.d === 0) root.viewDate = new Date();
                                        else root.shiftMonth(navBtn.modelData.d);
                                    }
                                }
                            }
                        }
                    }
                }

                // Days of the week
                Row {
                    width: parent.width
                    Repeater {
                        model: root.dayHeaders
                        Text {
                            required property string modelData
                            required property int index
                            width: calCol.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: index >= 5 ? Theme.accent : Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Bold
                        }
                    }
                }

                // Month dates
                Grid {
                    width: parent.width
                    columns: 7
                    Repeater {
                        model: root.cells
                        Item {
                            id: dCell
                            required property var modelData
                            width: calCol.width / 7
                            height: Theme.px(28)

                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.px(26); height: width; radius: width / 2
                                color: dCell.modelData.today ? Theme.accent : "transparent"
                            }
                            Text {
                                anchors.centerIn: parent
                                text: dCell.modelData.day
                                color: dCell.modelData.today ? "#000000"
                                     : !dCell.modelData.current ? Theme.text3
                                     : dCell.modelData.weekend ? Theme.text2 : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: dCell.modelData.today ? Font.Bold : Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}

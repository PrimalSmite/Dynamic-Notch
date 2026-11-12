import QtQuick
import qs.services
import qs.components

// Compact minimalist Calendar panel matching Dynamic Island aesthetic.
// Hotkeys: ←/→ (or wheel) to change month, ↑/↓ to change year, T/Home to reset to today.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property var viewDate: new Date()

    implicitWidth: Theme.px(260)
    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { shiftMonth(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { shiftMonth(1); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { shiftMonth(-12); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { shiftMonth(12); event.accepted = true; }
        else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) { viewDate = new Date(); event.accepted = true; }
    }

    readonly property string viewTitle: {
        const m = viewDate.toLocaleDateString(Qt.locale(), "MMMM yyyy");
        return m ? (m.charAt(0).toUpperCase() + m.slice(1)) : "";
    }

    readonly property var dayHeaders: {
        const loc = Qt.locale();
        const res = [];
        for (let i = 1; i <= 7; i++) {
            let d = loc.standaloneDayName(i, Locale.NarrowFormat);
            if (!d || d.length === 0) d = loc.standaloneDayName(i, Locale.ShortFormat);
            res.push(d ? d.charAt(0).toUpperCase() : "");
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
            let cellMonth = m;
            let cellYear = y;

            if (num <= 0) {
                day = daysInPrev + num;
                cur = false;
                cellMonth = m - 1;
            } else if (num > daysInMonth) {
                day = num - daysInMonth;
                cur = false;
                cellMonth = m + 1;
            }

            const isToday = cur && y === now.getFullYear() && m === now.getMonth() && day === now.getDate();
            list.push({
                day: day,
                current: cur,
                today: isToday,
                targetDate: new Date(cellYear, cellMonth, day)
            });
        }
        return list;
    }

    // Scroll wheel shifts month
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => root.shiftMonth(w.angleDelta.y > 0 ? -1 : 1)
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(8)

        // Month Navigation Header
        Item {
            width: parent.width
            height: Theme.px(30)

            // Previous month button
            Rectangle {
                id: prevBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(28)
                height: width
                radius: width / 2
                color: prevMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                Icon {
                    anchors.centerIn: parent
                    name: "arrow_back"
                    size: Theme.px(15)
                    color: Theme.text
                }

                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(-1)
                }
            }

            // Month and year title
            Text {
                anchors.centerIn: parent
                text: root.viewTitle
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(13)
                font.weight: Font.DemiBold

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewDate = new Date()
                }
            }

            // Next month button
            Rectangle {
                id: nextBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(28)
                height: width
                radius: width / 2
                color: nextMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                Icon {
                    anchors.centerIn: parent
                    name: "arrow_forward"
                    size: Theme.px(15)
                    color: Theme.text
                }

                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        Item { width: 1; height: Theme.px(2) }

        // Day of week abbreviations (M T W T F S S)
        Row {
            width: parent.width
            Repeater {
                model: root.dayHeaders
                Text {
                    required property string modelData
                    width: col.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: Qt.rgba(1, 1, 1, 0.42)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.DemiBold
                }
            }
        }

        // Days Grid
        Grid {
            width: parent.width
            columns: 7
            rowSpacing: Theme.px(2)

            Repeater {
                model: root.cells
                Item {
                    id: dCell
                    required property var modelData
                    width: col.width / 7
                    height: Theme.px(26)

                    Rectangle {
                        id: cellBg
                        anchors.centerIn: parent
                        width: Theme.px(24)
                        height: width
                        radius: width / 2
                        color: dCell.modelData.today ? "#8ab4f8"
                             : cellMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08)
                             : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dCell.modelData.day
                        color: dCell.modelData.today ? "#0a1224"
                             : !dCell.modelData.current ? Qt.rgba(1, 1, 1, 0.28)
                             : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11.5)
                        font.weight: dCell.modelData.today ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!dCell.modelData.current) {
                                root.viewDate = dCell.modelData.targetDate;
                            }
                        }
                    }
                }
            }
        }
    }
}

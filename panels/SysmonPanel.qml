import QtQuick
import qs.services
import qs.components

// Панель системного монитора: CPU со спарклайном, RAM, диск, сеть, аптайм и топ процессов.
Item {
    id: root
    property var host: null
    implicitHeight: col.implicitHeight

    Connections {
        target: SysInfo
        function onCpuHistoryChanged() { sparkCanvas.requestPaint(); }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Верхние 4 плитки
        Row {
            width: parent.width
            spacing: Theme.px(10)
            readonly property real tileW: (width - 3 * spacing) / 4

            StatTile {
                width: parent.tileW
                icon: "memory"
                label: "Процессор" + (SysInfo.cpuTemp >= 0 ? " · " + SysInfo.cpuTemp + "°C" : "")
                value: Math.round(SysInfo.cpu * 100) + "%"
                level: SysInfo.cpu
                tint: SysInfo.cpu > 0.85 ? Theme.red : SysInfo.cpu > 0.6 ? Theme.orange : Theme.blue
            }

            StatTile {
                width: parent.tileW
                icon: "memory_alt"
                label: "Память · " + SysInfo.memTotalGb.toFixed(0) + " ГБ"
                value: SysInfo.memUsedGb.toFixed(1) + " ГБ"
                level: SysInfo.mem
                tint: SysInfo.mem > 0.85 ? Theme.red : Theme.purple
            }

            StatTile {
                width: parent.tileW
                icon: "hard_drive"
                label: "Диск / · " + (SysInfo.diskText || "--")
                value: Math.round(SysInfo.disk * 100) + "%"
                level: SysInfo.disk
                tint: Theme.green
            }

            // Сеть и аптайм
            Rectangle {
                width: parent.tileW
                height: Theme.px(74)
                radius: Theme.px(18)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(4)

                    Row {
                        width: parent.width
                        spacing: Theme.px(6)
                        Icon { name: "swap_vert"; size: Theme.px(18); color: Theme.orange }
                        Text {
                            text: "Сеть · " + (SysInfo.uptime || "")
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: "↓ " + SysInfo.netDown
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        text: "↑ " + SysInfo.netUp
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        // График истории CPU + Топ процессов
        Row {
            width: parent.width
            spacing: Theme.px(10)

            // График CPU
            Rectangle {
                width: (parent.width - parent.spacing) * 0.45
                height: Theme.px(138)
                radius: Theme.px(18)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(6)

                    Text {
                        text: "История нагрузки ЦП"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Bold
                    }

                    Canvas {
                        id: sparkCanvas
                        width: parent.width
                        height: parent.height - Theme.px(22)
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const h = SysInfo.cpuHistory;
                            if (!h || h.length < 2) return;
                            ctx.beginPath();
                            for (let i = 0; i < h.length; i++) {
                                const x = (i / (h.length - 1)) * width;
                                const y = height - Math.max(0.04, h[i]) * (height - 6) - 3;
                                if (i === 0) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = "#0A84FF";
                            ctx.lineWidth = 2.2;
                            ctx.stroke();

                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fillStyle = Qt.rgba(0.04, 0.52, 1.0, 0.18);
                            ctx.fill();
                        }
                    }
                }
            }

            // Топ процессов
            Rectangle {
                width: (parent.width - parent.spacing) * 0.55
                height: Theme.px(138)
                radius: Theme.px(18)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(4)

                    Text {
                        text: "Активные процессы"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: SysInfo.topProcs
                        Item {
                            required property var modelData
                            width: parent.width
                            height: Theme.px(18)

                            Text {
                                anchors.left: parent.left
                                text: modelData.comm
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Medium
                                width: parent.width * 0.6
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.right: memT.left
                                anchors.rightMargin: Theme.px(14)
                                text: modelData.cpu
                                color: Theme.blue
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                id: memT
                                anchors.right: parent.right
                                width: Theme.px(42)
                                horizontalAlignment: Text.AlignRight
                                text: modelData.mem
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import qs.services
import qs.components

// System monitor panel: CPU with sparkline, RAM, disk, network, uptime and top processes.
Item {
    id: root
    property var host: null
    implicitWidth: Theme.px(420)
    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        SysInfo.activeClients++;
        sparkCanvas.requestPaint();
    }
    Component.onDestruction: SysInfo.activeClients = Math.max(0, SysInfo.activeClients - 1)

    Connections {
        target: SysInfo
        function onCpuHistoryChanged() { sparkCanvas.requestPaint(); }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(8)

        // 2×2 system stats grid
        Column {
            width: parent.width
            spacing: Theme.px(8)
            readonly property real tileW: (width - Theme.px(8)) / 2

            // Row 1: CPU and Memory
            Row {
                width: parent.width
                spacing: Theme.px(8)

                StatTile {
                    width: parent.parent.tileW
                    icon: "memory"
                    label: "CPU" + (SysInfo.cpuTemp >= 0 ? " · " + SysInfo.cpuTemp + "°C" : "")
                    value: Math.round(SysInfo.cpu * 100) + "%"
                    level: SysInfo.cpu
                    tint: SysInfo.cpu > 0.85 ? Theme.alert : SysInfo.cpu > 0.65 ? Theme.warn : Theme.controlFill
                }

                StatTile {
                    width: parent.parent.tileW
                    icon: "memory_alt"
                    label: "Memory · " + SysInfo.memTotalGb.toFixed(0) + " GB"
                    value: SysInfo.memUsedGb.toFixed(1) + " GB"
                    level: SysInfo.mem
                    tint: SysInfo.mem > 0.85 ? Theme.alert : SysInfo.mem > 0.75 ? Theme.warn : Theme.controlFill
                }
            }

            // Row 2: Disk and Network
            Row {
                width: parent.width
                spacing: Theme.px(8)

                StatTile {
                    width: parent.parent.tileW
                    icon: "hard_drive"
                    label: "Disk / · " + (SysInfo.diskText || "--")
                    value: Math.round(SysInfo.disk * 100) + "%"
                    level: SysInfo.disk
                    tint: SysInfo.disk > 0.90 ? Theme.alert : SysInfo.disk > 0.80 ? Theme.warn : Theme.controlFill
                }

                // Network and uptime
                Rectangle {
                    width: parent.parent.tileW
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
                            Icon { name: "swap_vert"; size: Theme.px(18); color: Theme.controlFill }
                            Text {
                                text: "Network · " + (SysInfo.uptime || "")
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
        }

        // CPU history chart + Top processes
        Row {
            width: parent.width
            spacing: Theme.px(10)

            // CPU chart
            Rectangle {
                width: (parent.width - parent.spacing) * 0.45
                height: Theme.px(146)
                radius: Theme.px(18)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(6)

                    Text {
                        text: "CPU Load History"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Bold
                    }

                    Canvas {
                        id: sparkCanvas
                        width: parent.width
                        height: parent.height - Theme.px(24)
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Threaded
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
                            const isCrit = SysInfo.cpu > 0.85;
                            const isWarn = SysInfo.cpu > 0.65;
                            ctx.strokeStyle = isCrit ? "#FF453A" : (isWarn ? "#FF9F0A" : Qt.rgba(1, 1, 1, 0.85));
                            ctx.lineWidth = 2.0;
                            ctx.stroke();

                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fillStyle = isCrit ? Qt.rgba(1, 0.27, 0.23, 0.18) : (isWarn ? Qt.rgba(1, 0.62, 0.04, 0.14) : Qt.rgba(1, 1, 1, 0.08));
                            ctx.fill();
                        }
                    }
                }
            }

            // Top processes (btop/htop style)
            Rectangle {
                width: (parent.width - parent.spacing) * 0.55
                height: Theme.px(146)
                radius: Theme.px(18)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(3)

                    // Header row with column titles
                    Item {
                        width: parent.width
                        height: Theme.px(18)

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Active Processes"
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.Bold
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(8)

                            Text {
                                width: Theme.px(42)
                                horizontalAlignment: Text.AlignRight
                                text: "MEM"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                                font.weight: Font.Bold
                            }

                            Text {
                                width: Theme.px(42)
                                horizontalAlignment: Text.AlignRight
                                text: "CPU%"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // Process rows
                    Repeater {
                        model: SysInfo.topProcs
                        Item {
                            required property var modelData
                            width: parent.width
                            height: Theme.px(19)

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.comm
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Medium
                                width: parent.width - Theme.px(98)
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.right: cpuT.left
                                anchors.rightMargin: Theme.px(8)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(42)
                                horizontalAlignment: Text.AlignRight
                                text: modelData.mem
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.features: { "tnum": 1 }
                            }

                            Text {
                                id: cpuT
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(42)
                                horizontalAlignment: Text.AlignRight
                                text: modelData.cpu
                                color: modelData.cpuNum > 25 ? Theme.alert : (modelData.cpuNum > 10 ? Theme.warn : Theme.text)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}

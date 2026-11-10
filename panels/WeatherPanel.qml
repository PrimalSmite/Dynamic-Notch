import QtQuick
import qs.services
import qs.components

// Weather panel (current, hourly and 7-day forecast + searchable city dropdown menu).
// Hotkeys: R — refresh, C / F — open city selector, Escape — close city selector.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: cityDropdownOpen && citySearchInput.activeFocus

    implicitWidth: Theme.px(540)
    implicitHeight: col.implicitHeight

    property bool cityDropdownOpen: false
    property string cityQuery: ""
    property int selectedCityIdx: 0

    readonly property var displayedCities: {
        const q = cityQuery.trim().toLowerCase();
        const presets = Weather.presetCities || [];
        if (!q.length) return presets;

        // Instant match against presets (supports English & Russian aliases)
        const localMatches = presets.filter(c =>
            c.name.toLowerCase().indexOf(q) !== -1 ||
            (c.sub && c.sub.toLowerCase().indexOf(q) !== -1) ||
            (c.aliases && c.aliases.indexOf(q) !== -1)
        );

        const apiMatches = Weather.searchResults || [];
        const combined = localMatches.slice();
        for (let i = 0; i < apiMatches.length; i++) {
            const a = apiMatches[i];
            const dup = combined.some(existing =>
                Math.abs(existing.lat - a.lat) < 0.08 && Math.abs(existing.lon - a.lon) < 0.08
            );
            if (!dup) combined.push(a);
        }
        return combined;
    }

    function openCityPicker() {
        cityQuery = "";
        citySearchInput.text = "";
        selectedCityIdx = 0;
        cityDropdownOpen = true;
        focusCityTimer.restart();
    }

    function selectCityItem(item) {
        if (!item) return;
        Weather.setLocation(item.name, item.lat, item.lon);
        cityDropdownOpen = false;
        root.forceActiveFocus();
    }

    function focusInput() {
        if (cityDropdownOpen) citySearchInput.forceActiveFocus();
        else root.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (cityDropdownOpen) {
            if (event.key === Qt.Key_Escape) {
                cityDropdownOpen = false;
                root.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down && displayedCities.length > 0) {
                selectedCityIdx = Math.min(displayedCities.length - 1, selectedCityIdx + 1);
                cityListView.positionViewAtIndex(selectedCityIdx, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up && displayedCities.length > 0) {
                selectedCityIdx = Math.max(0, selectedCityIdx - 1);
                cityListView.positionViewAtIndex(selectedCityIdx, ListView.Contain);
                event.accepted = true;
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && displayedCities.length > 0) {
                selectCityItem(displayedCities[selectedCityIdx] || displayedCities[0]);
                event.accepted = true;
            }
            return;
        }

        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_R || t === "r" || t === "к") {
            Weather.refresh();
            event.accepted = true;
        } else if (event.key === Qt.Key_C || event.key === Qt.Key_F || t === "c" || t === "f" || t === "с" || t === "а") {
            openCityPicker();
            event.accepted = true;
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Top row: current + hourly forecast
        Row {
            width: parent.width
            spacing: Theme.px(10)

            // Current weather card with clickable City Dropdown button
            Rectangle {
                width: Theme.px(210)
                height: Theme.px(112)
                radius: Theme.px(20)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(4)

                    // Clickable City Dropdown Pill
                    Rectangle {
                        id: cityBtn
                        height: Theme.px(24)
                        width: Math.min(parent.width, cityRow.implicitWidth + Theme.px(14))
                        radius: height / 2
                        color: cityBtnMa.containsMouse || root.cityDropdownOpen
                            ? Qt.rgba(1, 1, 1, 0.14)
                            : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: cityBtnMa.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.24)
                            : Qt.rgba(1, 1, 1, 0.10)
                        scale: cityBtnMa.pressed ? 0.95 : 1.0
                        Behavior on scale { Spring { epsilon: 0.01 } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            id: cityRow
                            anchors.centerIn: parent
                            spacing: Theme.px(4)

                            Icon {
                                name: "location_on"
                                size: Theme.px(13)
                                color: Theme.controlFill
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.city
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, Theme.px(135))
                            }

                            Icon {
                                name: "expand_more"
                                size: Theme.px(14)
                                color: Theme.text2
                                anchors.verticalCenter: parent.verticalCenter
                                rotation: root.cityDropdownOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 160 } }
                            }
                        }

                        MouseArea {
                            id: cityBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openCityPicker()
                        }
                    }

                    Row {
                        spacing: Theme.px(8)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Weather.icon
                            size: Theme.px(30)
                            color: Weather.iconColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: isNaN(Weather.temp) ? "--°" : Math.round(Weather.temp) + "°"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(30)
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        text: Weather.desc + " · Feels " + (isNaN(Weather.feelsLike) ? "--" : Math.round(Weather.feelsLike) + "°")
                              + " · " + (Math.round(Weather.wind * 10) / 10) + " m/s"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // Hourly forecast
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
                        model: Weather.hourly
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
                                color: modelData.iconColor || Theme.text
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

        // 7-day forecast
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
                            color: modelData.iconColor || Theme.blue
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

    // ── Searchable City Dropdown Overlay ──
    Rectangle {
        id: cityModal
        visible: opacity > 0.01
        opacity: root.cityDropdownOpen ? 1.0 : 0.0
        scale: root.cityDropdownOpen ? 1.0 : 0.96
        anchors.fill: parent
        radius: Theme.px(20)
        color: "#0F1211"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        z: 999

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { Spring { spring: 5.2; damping: 0.48; epsilon: 0.01 } }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            spacing: Theme.px(8)

            // Header: Title + Auto IP button + Close button
            Item {
                width: parent.width
                height: Theme.px(26)

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "location_on"
                        size: Theme.px(15)
                        color: Theme.controlFill
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Select City"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "· Current: " + Weather.city
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(6)

                    // Auto-detect by IP pill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.px(24)
                        width: autoIpRow.implicitWidth + Theme.px(14)
                        radius: height / 2
                        color: autoIpMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Row {
                            id: autoIpRow
                            anchors.centerIn: parent
                            spacing: Theme.px(4)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "my_location"
                                size: Theme.px(12)
                                color: Theme.controlFill
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Auto by IP"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: autoIpMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Weather.detectLocationByIp();
                                root.cityDropdownOpen = false;
                                root.forceActiveFocus();
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(24)
                        height: width
                        radius: width / 2
                        color: closeCityMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                        Icon {
                            anchors.centerIn: parent
                            name: "close"
                            size: Theme.px(13)
                            color: Theme.text2
                        }
                        MouseArea {
                            id: closeCityMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.cityDropdownOpen = false;
                                root.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Search Input Box
            Rectangle {
                width: parent.width
                height: Theme.px(30)
                radius: Theme.px(8)
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: citySearchInput.activeFocus ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.12)

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(8)
                    anchors.right: clearCityBtn.visible ? clearCityBtn.left : parent.right
                    anchors.rightMargin: Theme.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.searchingCities ? "hourglass_top" : "search"
                        size: Theme.px(14)
                        color: Theme.text3
                    }

                    TextInput {
                        id: citySearchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(24)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        color: Theme.text
                        selectionColor: Theme.controlFill
                        cursorDelegate: Caret {}
                        clip: true
                        onTextChanged: {
                            root.cityQuery = text;
                            root.selectedCityIdx = 0;
                            searchDebounce.restart();
                        }

                        Text {
                            visible: citySearchInput.text.length === 0
                            text: "Search any city (e.g. Izhevsk, Ижевск, Moscow, Tokyo)..."
                            color: Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                        }
                    }
                }

                Rectangle {
                    id: clearCityBtn
                    visible: citySearchInput.text.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(18)
                    height: width
                    radius: width / 2
                    color: clearCityMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.px(11)
                        color: Theme.text3
                    }
                    MouseArea {
                        id: clearCityMa
                        anchors.fill: parent
                        onClicked: citySearchInput.text = ""
                    }
                }
            }

            // Scrollable City Results ListView
            ListView {
                id: cityListView
                width: parent.width
                height: parent.height - Theme.px(72)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.displayedCities
                spacing: Theme.px(3)

                delegate: Rectangle {
                    id: cityItem
                    required property var modelData
                    required property int index
                    width: cityListView.width
                    height: Theme.px(30)
                    radius: Theme.px(7)

                    readonly property bool isCurrentCity: Weather.city.toLowerCase() === modelData.name.toLowerCase()
                    readonly property bool isHighlighted: root.selectedCityIdx === index || cItemMa.containsMouse

                    color: isCurrentCity
                        ? Qt.rgba(1, 1, 1, 0.15)
                        : (isHighlighted ? Theme.cardHover : "transparent")

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(7)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: cityItem.isCurrentCity ? "check" : "location_on"
                            size: Theme.px(13)
                            color: cityItem.isCurrentCity ? Theme.controlFill : Theme.text3
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cityItem.modelData.name
                            color: cityItem.isCurrentCity ? Theme.controlFill : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: cityItem.isCurrentCity ? Font.Bold : Font.Medium
                        }

                        Text {
                            visible: (cityItem.modelData.sub || "").length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: cityItem.modelData.sub || ""
                            color: Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            elide: Text.ElideRight
                            width: Theme.px(230)
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: cityItem.modelData.lat.toFixed(2) + ", " + cityItem.modelData.lon.toFixed(2)
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.features: { "tnum": 1 }
                    }

                    MouseArea {
                        id: cItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedCityIdx = cityItem.index
                        onClicked: root.selectCityItem(cityItem.modelData)
                    }
                }

                // Empty state when searching
                Column {
                    visible: root.displayedCities.length === 0
                    anchors.centerIn: parent
                    spacing: Theme.px(4)
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Weather.searchingCities ? "hourglass_top" : "location_off"
                        size: Theme.px(20)
                        color: Theme.text3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.searchingCities
                            ? ("Searching for \"" + root.cityQuery + "\"...")
                            : ("No cities found for \"" + root.cityQuery + "\"")
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                    }
                }
            }
        }
    }

    Timer {
        id: searchDebounce
        interval: 260
        repeat: false
        onTriggered: Weather.searchCities(root.cityQuery)
    }

    Timer {
        id: focusCityTimer
        interval: 50
        repeat: false
        onTriggered: citySearchInput.forceActiveFocus()
    }
}

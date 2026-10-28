import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Панель запуска приложений со встроенным инженерным калькулятором и историей вычислений.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true
    property string query: ""
    property int selectedIndex: 0
    property bool showHistory: false
    property int historyIndex: 0

    implicitWidth: Theme.px(410)
    implicitHeight: col.implicitHeight

    readonly property var calcResult: Calculator.evaluate(root.query)

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            selectedIndex = 0;
            historyIndex = 0;
            showHistory = false;
            list.positionViewAtBeginning();
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    Component.onCompleted: {
        searchInput.forceActiveFocus();
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 35
        onTriggered: searchInput.forceActiveFocus()
    }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const all = Apps.allEntries.slice();
        let res = [];
        if (q === "") {
            res = all;
            res.sort((a, b) => {
                const sa = Apps.score(a);
                const sb = Apps.score(b);
                if (sb !== sa) return sb - sa;
                return (a.name || "").localeCompare(b.name || "");
            });
        } else {
            for (const e of all) {
                const name = (e.name || "").toLowerCase();
                const gen = (e.genericName || "").toLowerCase();
                const id = (e.id || "").toLowerCase();
                if (name.indexOf(q) >= 0 || gen.indexOf(q) >= 0 || id.indexOf(q) >= 0)
                    res.push(e);
            }
            res.sort((a, b) => {
                const na = (a.name || "").toLowerCase().startsWith(q) ? 1 : 0;
                const nb = (b.name || "").toLowerCase().startsWith(q) ? 1 : 0;
                if (nb !== na) return nb - na;
                return Apps.score(b) - Apps.score(a);
            });
        }
        return res.slice(0, 40);
    }

    function triggerPrimaryAction() {
        // Если открыта история и нет текущего вычисления — копируем выбранный элемент истории
        if (root.showHistory && !root.calcResult.valid && Calculator.history.length > 0) {
            const hIdx = Math.max(0, Math.min(Calculator.history.length - 1, root.historyIndex));
            const item = Calculator.history[hIdx];
            Calculator.copyText(item.result);
            return;
        }
        // Если активно математическое выражение (и пользователь не спустился стрелкой в список приложений)
        if (root.calcResult.valid && (root.filtered.length === 0 || root.selectedIndex === -1)) {
            Calculator.recordAndCopy(root.calcResult.expr, root.calcResult.formatted);
            return;
        }
        if (root.filtered.length === 0) return;
        const idx = Math.max(0, Math.min(root.filtered.length - 1, root.selectedIndex));
        Apps.launch(root.filtered[idx]);
        if (root.host) root.host.collapse();
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(8)

        // ───────── Строка поиска / ввода выражения ─────────
        Item {
            width: parent.width
            height: Theme.px(36)

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(6)
                anchors.verticalCenter: parent.verticalCenter
                name: (root.calcResult.valid || root.showHistory) ? "calculate" : "search"
                size: Theme.px(17)
                color: (root.calcResult.valid || root.showHistory) ? Theme.orange : Theme.text2
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            TextInput {
                id: searchInput
                anchors.left: sIcon.right
                anchors.right: rightBarBtns.left
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(13)
                selectionColor: Theme.blue
                clip: true
                focus: true
                onTextChanged: {
                    root.query = text;
                    // Когда выражение вычисляется в калькуляторе, фокус по умолчанию на карточке калькулятора (-1)
                    const ev = Calculator.evaluate(text);
                    root.selectedIndex = ev.valid ? -1 : 0;
                    list.positionViewAtBeginning();
                }
                Keys.onReturnPressed: root.triggerPrimaryAction()
                Keys.onEnterPressed: root.triggerPrimaryAction()
                Keys.onPressed: event => {
                    const ctrlOrAlt = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) !== 0;
                    if (ctrlOrAlt && event.key === Qt.Key_H) {
                        root.showHistory = !root.showHistory;
                        root.historyIndex = 0;
                        event.accepted = true;
                        return;
                    }
                }
                Keys.onDownPressed: {
                    if (root.showHistory && Calculator.history.length > 0 && !root.calcResult.valid) {
                        root.historyIndex = Math.min(Calculator.history.length - 1, root.historyIndex + 1);
                        historyList.positionViewAtIndex(root.historyIndex, ListView.Contain);
                        return;
                    }
                    if (root.filtered.length > 0) {
                        root.selectedIndex = Math.min(root.filtered.length - 1, root.selectedIndex + 1);
                        if (root.selectedIndex >= 0)
                            list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    }
                }
                Keys.onUpPressed: {
                    if (root.showHistory && Calculator.history.length > 0 && !root.calcResult.valid) {
                        root.historyIndex = Math.max(0, root.historyIndex - 1);
                        historyList.positionViewAtIndex(root.historyIndex, ListView.Contain);
                        return;
                    }
                    const minIdx = root.calcResult.valid ? -1 : 0;
                    root.selectedIndex = Math.max(minIdx, root.selectedIndex - 1);
                    if (root.selectedIndex >= 0)
                        list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                }
                Keys.onEscapePressed: event => {
                    if (root.showHistory) {
                        root.showHistory = false;
                        event.accepted = true;
                        return;
                    }
                    if (root.host) root.host.collapse();
                    event.accepted = true;
                }

                Text {
                    visible: searchInput.text.length === 0
                    text: root.showHistory
                          ? "Введите выражение (sin(30°), 2^10, ln(e), 5!)..."
                          : "Поиск или расчёт (2+2, sin(30°), log2(1024))..."
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                }
            }

            Row {
                id: rightBarBtns
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(4)

                // Кнопка очистки строки
                Rectangle {
                    visible: searchInput.text.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(24); height: width
                    radius: Theme.px(7)
                    color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Icon { anchors.centerIn: parent; name: "close"; size: Theme.px(15); color: Theme.text2 }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                    }
                }

                // Кнопка открытия истории калькулятора
                Rectangle {
                    id: histToggleBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: histRow.implicitWidth + Theme.px(12)
                    height: Theme.px(26)
                    radius: Theme.px(8)
                    color: root.showHistory
                           ? Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.22)
                           : (histBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: root.showHistory ? 1 : 0
                    border.color: Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.5)

                    Row {
                        id: histRow
                        anchors.centerIn: parent
                        spacing: Theme.px(4)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "history"
                            size: Theme.px(14)
                            color: root.showHistory ? Theme.orange : Theme.text2
                        }
                        Text {
                            visible: Calculator.history.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: Calculator.history.length
                            color: root.showHistory ? Theme.orange : Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }
                    }

                    MouseArea {
                        id: histBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHistory = !root.showHistory;
                            root.historyIndex = 0;
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Тонкий разделитель под строкой поиска
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ───────── Карточка живого калькулятора ─────────
        Rectangle {
            id: calcCard
            visible: root.calcResult.valid
            width: parent.width
            height: Theme.px(74)
            radius: Theme.px(13)
            readonly property bool focusedCard: root.selectedIndex === -1
            readonly property bool justCopied: Calculator.lastCopied !== "" && Calculator.lastCopied === root.calcResult.formatted

            color: focusedCard
                   ? Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.14)
                   : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: justCopied
                          ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.55)
                          : (focusedCard
                             ? Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.45)
                             : Qt.rgba(1, 1, 1, 0.1))
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            // Левая акцентная капсула
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(5)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(3)
                height: calcCard.focusedCard ? Theme.px(34) : Theme.px(16)
                radius: width / 2
                color: calcCard.justCopied ? Theme.green : Theme.orange
                Behavior on height { Spring {} }
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            // Левая часть: выражение и крупный ответ
            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(16)
                anchors.right: calcActions.left
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(2)

                Row {
                    width: parent.width
                    spacing: Theme.px(8)

                    Text {
                        text: root.calcResult.expr + " ="
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.calcResult.extra !== ""
                        text: root.calcResult.extra
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.features: { "tnum": 1 }
                    }
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.calcResult.formatted
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(22)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
            }

            // Кнопки справа: Копировать результат и История
            Row {
                id: calcActions
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(6)

                // Кнопка копирования (и сохранения в историю)
                Rectangle {
                    width: copyRow.implicitWidth + Theme.px(16)
                    height: Theme.px(32)
                    radius: Theme.px(9)
                    color: calcCard.justCopied
                           ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.22)
                           : (copyBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09))

                    Row {
                        id: copyRow
                        anchors.centerIn: parent
                        spacing: Theme.px(5)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: calcCard.justCopied ? "check" : "content_copy"
                            size: Theme.px(14)
                            color: calcCard.justCopied ? Theme.green : Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: calcCard.justCopied ? "Скопировано" : "Копировать"
                            color: calcCard.justCopied ? Theme.green : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: copyBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Calculator.recordAndCopy(root.calcResult.expr, root.calcResult.formatted);
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                // Кнопка раскрытия истории прямо с карточки калькулятора
                Rectangle {
                    width: Theme.px(32)
                    height: Theme.px(32)
                    radius: Theme.px(9)
                    color: root.showHistory
                           ? Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.24)
                           : (cardHistMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))

                    Icon {
                        anchors.centerIn: parent
                        name: "history"
                        size: Theme.px(16)
                        color: root.showHistory ? Theme.orange : Theme.text2
                    }

                    MouseArea {
                        id: cardHistMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHistory = !root.showHistory;
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // Клик по самой карточке тоже копирует результат и сохраняет в историю
            MouseArea {
                anchors.left: parent.left
                anchors.right: calcActions.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = -1;
                    Calculator.recordAndCopy(root.calcResult.expr, root.calcResult.formatted);
                    searchInput.forceActiveFocus();
                }
            }
        }

        // ───────── Секция истории вычислений ─────────
        Column {
            id: historySection
            visible: root.showHistory
            width: parent.width
            spacing: Theme.px(6)

            // Шапка истории + быстрые примеры функций + очистка
            Item {
                width: parent.width
                height: Theme.px(24)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ИСТОРИЯ ВЫЧИСЛЕНИЙ"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.px(0.8)
                }

                Rectangle {
                    visible: Calculator.history.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.px(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: clearHistTxt.implicitWidth + Theme.px(12)
                    height: Theme.px(20)
                    radius: Theme.px(6)
                    color: clearHistMa.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.18) : "transparent"

                    Text {
                        id: clearHistTxt
                        anchors.centerIn: parent
                        text: "Очистить"
                        color: clearHistMa.containsMouse ? Theme.red : Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: clearHistMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Calculator.clearHistory();
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // Пустое состояние истории с кликабельными примерами функций
            Rectangle {
                visible: Calculator.history.length === 0
                width: parent.width
                height: Theme.px(88)
                radius: Theme.px(11)
                color: Qt.rgba(1, 1, 1, 0.04)

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.px(6)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "История пуста · Нажмите Enter на расчёте, чтобы сохранить и скопировать"
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.px(6)

                        Repeater {
                            model: ["sin(30°)", "2^10", "log2(1024)", "sqrt(144)", "5!", "ln(e^3)"]
                            Rectangle {
                                required property string modelData
                                width: sampleTxt.implicitWidth + Theme.px(14)
                                height: Theme.px(22)
                                radius: Theme.px(7)
                                color: sampleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

                                Text {
                                    id: sampleTxt
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                }

                                MouseArea {
                                    id: sampleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = modelData;
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Список сохранённых вычислений
            ListView {
                id: historyList
                visible: Calculator.history.length > 0
                width: parent.width
                height: Math.min(Calculator.history.length * Theme.px(44), Theme.px(176))
                spacing: Theme.px(3)
                clip: true
                model: Calculator.history

                delegate: Rectangle {
                    id: histItem
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: Theme.px(42)
                    radius: Theme.px(10)

                    readonly property bool isSel: !root.calcResult.valid && index === root.historyIndex
                    readonly property bool itemCopied: Calculator.lastCopied !== "" && Calculator.lastCopied === modelData.result

                    color: isSel ? Qt.rgba(1, 1, 1, 0.11)
                         : histRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
                         : Qt.rgba(1, 1, 1, 0.03)

                    // Выражение слева
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(12)
                        anchors.right: histRightRow.left
                        anchors.rightMargin: Theme.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: histItem.modelData.expr
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                    }

                    // Результат + действия справа
                    Row {
                        id: histRightRow
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(6)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "= " + histItem.modelData.result
                            color: histItem.itemCopied ? Theme.green : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }

                        // Кнопка «Копировать результат»
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(26); height: width
                            radius: Theme.px(7)
                            color: copyHistMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                            Icon {
                                anchors.centerIn: parent
                                name: histItem.itemCopied ? "check" : "content_copy"
                                size: Theme.px(13)
                                color: histItem.itemCopied ? Theme.green : Theme.text2
                            }
                            MouseArea {
                                id: copyHistMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Calculator.copyText(histItem.modelData.result);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        // Кнопка «Подставить выражение обратно в ввод»
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(26); height: width
                            radius: Theme.px(7)
                            color: insertHistMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                            Icon {
                                anchors.centerIn: parent
                                name: "north_west"
                                size: Theme.px(13)
                                color: Theme.text2
                            }
                            MouseArea {
                                id: insertHistMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = histItem.modelData.expr;
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        // Кнопка удаления записи
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(24); height: width
                            radius: Theme.px(7)
                            color: delHistMa.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : "transparent"

                            Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: Theme.px(13)
                                color: delHistMa.containsMouse ? Theme.red : Theme.text3
                            }
                            MouseArea {
                                id: delHistMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Calculator.removeHistoryAt(histItem.index);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Клик по строке истории копирует результат
                    MouseArea {
                        id: histRowMa
                        anchors.left: parent.left
                        anchors.right: histRightRow.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.historyIndex = histItem.index
                        onClicked: {
                            Calculator.copyText(histItem.modelData.result);
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }
        }

        // ───────── Вертикальный список приложений ─────────
        ListView {
            id: list
            visible: root.filtered.length > 0
            width: parent.width
            height: {
                let maxH = Theme.px(312);
                if (root.calcResult.valid) maxH -= Theme.px(82);
                if (root.showHistory) maxH -= Theme.px(150);
                return Math.max(Theme.px(104), Math.min(maxH, root.filtered.length * Theme.px(52)));
            }
            spacing: Theme.px(2)
            clip: true
            model: root.filtered

            delegate: Rectangle {
                id: rowItem
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Theme.px(50)
                radius: Theme.px(11)

                readonly property bool selected: index === root.selectedIndex

                color: selected ? Qt.rgba(1, 1, 1, 0.11)
                     : rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
                     : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                // Вертикальная белая капсула слева у выбранного элемента
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(3)
                    height: rowItem.selected ? Theme.px(22) : Theme.px(6)
                    radius: width / 2
                    color: Theme.text
                    opacity: rowItem.selected ? 1 : 0
                    Behavior on height { Spring {} }
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(12)
                    spacing: Theme.px(12)

                    // Подложка под иконку приложения
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(34)
                        height: width
                        radius: Theme.px(9)
                        color: Qt.rgba(1, 1, 1, 0.06)

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Theme.px(22)
                            source: Quickshell.iconPath(rowItem.modelData.icon, "application-x-executable")
                        }
                    }

                    // Название и описание
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(52)
                        spacing: Theme.px(1)

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: rowItem.modelData.name || rowItem.modelData.id
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: rowItem.modelData.genericName || rowItem.modelData.comment || rowItem.modelData.id
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = rowItem.index
                    onClicked: {
                        Apps.launch(rowItem.modelData);
                        if (root.host) root.host.collapse();
                    }
                }
            }
        }
    }
}

pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import QtQuick

// Notification service (NotificationServer + DND + read status synchronization).
Singleton {
    id: root

    property var list: []
    property int unread: 0
    property bool dnd: false
    property int _seq: 0

    signal popup(var n)

    // Delay for active window check (Telegram, Discord, etc.)
    Timer {
        id: readAppTimer
        interval: 900
        repeat: false
        onTriggered: root.checkActiveAppRead()
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (root.unread > 0) {
                readAppTimer.restart();
            }
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
            const actions = [];
            if (notif.actions) {
                for (let i = 0; i < notif.actions.length; i++) {
                    const a = notif.actions[i];
                    actions.push({ id: a.identifier, text: a.text || a.identifier });
                }
            }
            const item = {
                id: ++root._seq,
                dbusId: notif.id,
                appName: notif.appName || "System",
                appIcon: notif.appIcon || "",
                desktopEntry: notif.desktopEntry || "",
                image: notif.image || "",
                summary: notif.summary || notif.appName || "Notification",
                body: notif.body || "",
                time: new Date(),
                urgency: notif.urgency,
                actions: actions,
                notif: notif,
                read: false
            };

            // Synchronize dismissal from application side (Telegram/Discord CloseNotification)
            try {
                notif.closed.connect(function(reason) {
                    root.onNotifClosed(item, reason);
                });
            } catch (e) {
                console.log("[Notifs] Error connecting closed signal:", e);
            }

            const next = [item].concat(root.list);
            if (next.length > 80) next.length = 80;
            root.list = next;
            root.recalcUnread();

            if (!root.dnd || notif.urgency === NotificationUrgency.Critical)
                root.popup(item);

            // If application window is already active, check read status
            readAppTimer.restart();
        }
    }

    function onNotifClosed(item, reason) {
        if (!item) return;
        root.markItemRead(item.id);
    }

    function markItemRead(id) {
        let changed = false;
        for (let i = 0; i < root.list.length; i++) {
            if (root.list[i].id === id && !root.list[i].read) {
                root.list[i].read = true;
                changed = true;
            }
        }
        if (changed) {
            root.recalcUnread();
            root.list = root.list.slice();
        }
    }

    function recalcUnread() {
        let count = 0;
        for (let i = 0; i < root.list.length; i++) {
            if (!root.list[i].read) count++;
        }
        root.unread = count;
    }

    function checkActiveAppRead() {
        const top = Hyprland.activeToplevel;
        if (!top || root.unread === 0) return;
        markAppAsRead(top);
    }

    function markAppAsRead(top) {
        if (!top || root.unread === 0) return;
        let changed = false;
        for (let i = 0; i < root.list.length; i++) {
            const item = root.list[i];
            if (!item.read && matchesApp(item, top)) {
                item.read = true;
                changed = true;
            }
        }
        if (changed) {
            root.recalcUnread();
            root.list = root.list.slice();
        }
    }

    function matchesApp(item, top) {
        if (!item || !top) return false;
        const cls = String((top.class || (top.lastIpcObject && top.lastIpcObject.class) || "")).toLowerCase();
        const initCls = String((top.initialClass || (top.lastIpcObject && top.lastIpcObject.initialClass) || "")).toLowerCase();
        const title = String((top.title || (top.lastIpcObject && top.lastIpcObject.title) || "")).toLowerCase();

        const appName = String(item.appName || "").toLowerCase();
        const appIcon = String(item.appIcon || "").toLowerCase();
        const de = String(item.desktopEntry || (item.notif && item.notif.desktopEntry ? item.notif.desktopEntry : "")).toLowerCase();

        // 1. Telegram
        const isTopTelegram = cls.indexOf("telegram") !== -1 || initCls.indexOf("telegram") !== -1 || title.indexOf("telegram") !== -1;
        const isNotifTelegram = appName.indexOf("telegram") !== -1 || appIcon.indexOf("telegram") !== -1 || de.indexOf("telegram") !== -1;
        if (isTopTelegram && isNotifTelegram) return true;

        // 2. Discord / Vesktop / Equibop
        const isTopDiscord = cls.indexOf("discord") !== -1 || cls.indexOf("vesktop") !== -1 || cls.indexOf("equibop") !== -1
                          || initCls.indexOf("discord") !== -1 || initCls.indexOf("vesktop") !== -1 || initCls.indexOf("equibop") !== -1;
        const isNotifDiscord = appName.indexOf("discord") !== -1 || appName.indexOf("vesktop") !== -1 || appName.indexOf("equibop") !== -1
                            || appIcon.indexOf("discord") !== -1 || de.indexOf("discord") !== -1;
        if (isTopDiscord && isNotifDiscord) return true;

        // 3. Direct desktopEntry match
        if (de && (cls === de || initCls === de || cls.indexOf(de) !== -1 || de.indexOf(cls) !== -1))
            return true;

        // 4. Class name match with appName or appIcon
        if (appName && (cls === appName || initCls === appName || cls.indexOf(appName) !== -1))
            return true;
        if (appIcon && (cls === appIcon || initCls === appIcon))
            return true;

        return false;
    }

    function markRead() {
        let changed = false;
        for (let i = 0; i < root.list.length; i++) {
            if (!root.list[i].read) {
                root.list[i].read = true;
                changed = true;
            }
        }
        root.unread = 0;
        if (changed) root.list = root.list.slice();
    }

    function dismiss(n) {
        if (!n) return;
        try { if (n.notif) n.notif.dismiss(); } catch (e) {}
        root.list = root.list.filter(x => x.id !== n.id);
        root.recalcUnread();
    }

    function clear() {
        for (const x of root.list) {
            try { if (x.notif) x.notif.dismiss(); } catch (e) {}
        }
        root.list = [];
        root.unread = 0;
    }

    function invoke(n, actionId) {
        if (!n || !n.notif) return;
        try {
            const acts = n.notif.actions;
            if (acts) {
                for (let i = 0; i < acts.length; i++) {
                    if ((!actionId && acts[i].identifier === "default") || acts[i].identifier === actionId) {
                        acts[i].invoke();
                        break;
                    }
                }
            }
        } catch (e) {}
        dismiss(n);
    }

    function timeAgo(d) {
        if (!d) return "";
        const sec = Math.max(0, Math.floor((Date.now() - d.getTime()) / 1000));
        if (sec < 45) return "just now";
        const min = Math.floor(sec / 60);
        if (min < 60) return min + "m";
        const hr = Math.floor(min / 60);
        if (hr < 24) return hr + "h";
        return Math.floor(hr / 24) + "d";
    }
}

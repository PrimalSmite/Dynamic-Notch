pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Сервис уведомлений (NotificationServer + DND).
Singleton {
    id: root

    property var list: []
    property int unread: 0
    property bool dnd: false
    property int _seq: 0

    signal popup(var n)

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
                appName: notif.appName || "Система",
                appIcon: notif.appIcon || "",
                image: notif.image || "",
                summary: notif.summary || notif.appName || "Уведомление",
                body: notif.body || "",
                time: new Date(),
                urgency: notif.urgency,
                actions: actions,
                notif: notif
            };
            const next = [item].concat(root.list);
            if (next.length > 80) next.length = 80;
            root.list = next;
            root.unread = root.unread + 1;

            if (!root.dnd || notif.urgency === NotificationUrgency.Critical)
                root.popup(item);
        }
    }

    function markRead() {
        unread = 0;
    }

    function dismiss(n) {
        if (!n) return;
        try { if (n.notif) n.notif.dismiss(); } catch (e) {}
        list = list.filter(x => x.id !== n.id);
    }

    function clear() {
        for (const x of list) {
            try { if (x.notif) x.notif.dismiss(); } catch (e) {}
        }
        list = [];
        unread = 0;
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
        if (sec < 45) return "сейчас";
        const min = Math.floor(sec / 60);
        if (min < 60) return min + " мин";
        const hr = Math.floor(min / 60);
        if (hr < 24) return hr + " ч";
        return Math.floor(hr / 24) + " д";
    }
}

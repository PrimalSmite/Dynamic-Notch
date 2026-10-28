pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Активный MPRIS-плеер: выбранный вручную, иначе играющий, иначе первый.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var pinned: null
    readonly property MprisPlayer player: (pinned && players.indexOf(pinned) >= 0 ? pinned : null)
                                          ?? players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player !== null && player.isPlaying

    // MPRIS не шлёт обновления позиции сам — дёргаем раз в секунду
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "0:00";
        const s = Math.floor(sec % 60);
        return Math.floor(sec / 60) + ":" + (s < 10 ? "0" : "") + s;
    }
}

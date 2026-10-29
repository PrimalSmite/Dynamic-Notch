pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Активный MPRIS-плеер: выбранный вручную, иначе играющий, иначе первый доступный.
Singleton {
    id: root

    readonly property var players: Mpris.players ? (Mpris.players.values || []) : []
    property var pinned: null

    property var player: null
    property bool playing: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackArtUrl: ""

    // Периодическая синхронизация позиции трека во время воспроизведения
    Timer {
        id: pollTimer
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.sync()
    }

    onPinnedChanged: root.sync()
    onPlayersChanged: root.sync()

    Component.onCompleted: root.sync()

    function sync() {
        const list = root.players;
        let chosen = null;

        if (root.pinned && list.indexOf(root.pinned) >= 0) {
            chosen = root.pinned;
        } else {
            // 1. Ищем плеер в состоянии воспроизведения (Playing)
            for (let i = 0; i < list.length; i++) {
                const p = list[i];
                if (p && (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)) {
                    chosen = p;
                    break;
                }
            }
            // 2. Иначе ищем плеер с метаданными трека
            if (!chosen) {
                for (let i = 0; i < list.length; i++) {
                    const p = list[i];
                    if (p && (p.trackTitle || (p.metadata && p.metadata["xesam:title"]))) {
                        chosen = p;
                        break;
                    }
                }
            }
            // 3. Иначе первый доступный плеер
            if (!chosen && list.length > 0) {
                chosen = list[0];
            }
        }

        root.player = chosen;

        if (!chosen) {
            root.playing = false;
            root.trackTitle = "";
            root.trackArtist = "";
            root.trackArtUrl = "";
            return;
        }

        root.playing = Boolean(chosen.isPlaying || chosen.playbackState === MprisPlaybackState.Playing);
        root.trackTitle = chosen.trackTitle || (chosen.metadata ? chosen.metadata["xesam:title"] : "") || "";
        root.trackArtist = chosen.trackArtist || chosen.identity || (chosen.metadata ? chosen.metadata["xesam:artist"] : "") || "";
        root.trackArtUrl = chosen.trackArtUrl || (chosen.metadata ? chosen.metadata["mpris:artUrl"] : "") || "";

        if (root.playing && chosen.positionChanged) {
            chosen.positionChanged();
        }
    }

    // Мгновенная реакция на сигналы текущего плеера
    Connections {
        target: root.player
        function onPlaybackStateChanged() { root.sync(); }
        function onIsPlayingChanged() { root.sync(); }
        function onTrackTitleChanged() { root.sync(); }
        function onTrackArtistChanged() { root.sync(); }
        function onTrackArtUrlChanged() { root.sync(); }
    }

    function togglePlay() {
        if (!player) return;
        if (player.canTogglePlaying) {
            player.togglePlaying();
        } else if (player.isPlaying && player.canPause) {
            player.pause();
        } else if (!player.isPlaying && player.canPlay) {
            player.play();
        } else {
            player.togglePlaying();
        }
    }

    function next() {
        if (player && player.canGoNext) player.next();
    }

    function prev() {
        if (player && player.canGoPrevious) player.previous();
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "0:00";
        const s = Math.floor(sec % 60);
        return Math.floor(sec / 60) + ":" + (s < 10 ? "0" : "") + s;
    }
}

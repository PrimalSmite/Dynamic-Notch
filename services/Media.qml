pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Active MPRIS player: manually selected, otherwise playing, otherwise first available.
// Includes enhanced metadata parsing for YouTube/browsers and smart lazy synchronization.
Singleton {
    id: root

    readonly property var players: Mpris.players ? (Mpris.players.values || []) : []
    property var pinned: null

    property var player: null
    property bool playing: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackArtUrl: ""

    // Counter of active components displaying progress (MediaCard / MediaPanel).
    // Position polling once per second runs ONLY when there are active consumers.
    property int activeConsumers: 0

    Timer {
        id: pollTimer
        interval: 1000
        running: root.playing && root.activeConsumers > 0
        repeat: true
        onTriggered: {
            if (root.player && root.player.positionChanged) {
                root.player.positionChanged();
            }
        }
    }

    onPinnedChanged: root.sync()
    onPlayersChanged: root.sync()

    Component.onCompleted: root.sync()

    // Helper function to clean track title (especially for YouTube in web browsers)
    function cleanTitle(raw) {
        if (!raw) return "";
        let t = String(raw).trim();

        // 1. Remove notification prefix in browser tab title: "(1) ", "(99+) "
        t = t.replace(/^\(\d+\+?\)\s*/, "");

        // 2. Remove postfix "- YouTube", "— YouTube", "- YouTube Music"
        t = t.replace(/\s*[-–—|]\s*YouTube(?:\s*Music)?\s*$/i, "");

        // 3. Remove browser name postfixes when capturing window
        t = t.replace(/\s*[-–—|]\s*(?:Mozilla Firefox|Google Chrome|Chromium|Brave|Vivaldi)\s*$/i, "");

        return t.trim();
    }

    // Helper function to extract artist / channel
    function cleanArtist(p, meta, title) {
        let a = p.trackArtist;
        if (!a && meta) {
            const rawA = meta["xesam:artist"] || meta["artist"];
            if (Array.isArray(rawA)) a = rawA.join(", ");
            else if (typeof rawA === "string") a = rawA;
        }

        // If artist is browser name or "YouTube", clear it
        const idLow = (p.identity || "").toLowerCase();
        if (a) {
            const aLow = a.toLowerCase();
            if (aLow === idLow || aLow === "youtube" || aLow === "youtube music"
                || aLow.includes("firefox") || aLow.includes("chrome") || aLow.includes("chromium")) {
                a = "";
            }
        }

        // If no artist, try extracting "Artist - Track" from title
        if (!a && title && title.includes(" - ")) {
            const parts = title.split(" - ");
            if (parts.length >= 2 && parts[0].trim().length > 0) {
                a = parts[0].trim();
            }
        }

        return (a || "").trim();
    }

    // Helper function to extract artwork URL (with fallback to YouTube thumbnail)
    function cleanArtUrl(p, meta) {
        let art = p.trackArtUrl || (meta ? (meta["mpris:artUrl"] || meta["artUrl"]) : "") || "";

        // If local path is provided without file:// scheme
        if (art && art.startsWith("/") && !art.startsWith("//")) {
            art = "file://" + art;
        }

        // If no artwork (common issue with Chromium/Brave for YouTube), extract from YouTube URL
        if (!art && meta) {
            const url = meta["xesam:url"] || meta["url"] || p.url || meta["mpris:trackid"] || "";
            const ytMatch = String(url).match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})/);
            if (ytMatch && ytMatch[1]) {
                art = "https://img.youtube.com/vi/" + ytMatch[1] + "/hqdefault.jpg";
            }
        }

        return art;
    }

    function sync() {
        const list = root.players;
        let chosen = null;

        if (root.pinned && list.indexOf(root.pinned) >= 0) {
            chosen = root.pinned;
        } else {
            // 1. Look for a player in Playing state
            for (let i = 0; i < list.length; i++) {
                const p = list[i];
                if (p && (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)) {
                    chosen = p;
                    break;
                }
            }
            // 2. Otherwise look for player with track metadata
            if (!chosen) {
                for (let i = 0; i < list.length; i++) {
                    const p = list[i];
                    if (p && (p.trackTitle || (p.metadata && p.metadata["xesam:title"]))) {
                        chosen = p;
                        break;
                    }
                }
            }
            // 3. Otherwise use the first available player
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

        const meta = chosen.metadata || {};
        const rawTitle = chosen.trackTitle || meta["xesam:title"] || meta["title"] || "";
        const cTitle = cleanTitle(rawTitle);
        const cArtist = cleanArtist(chosen, meta, cTitle);

        // If artist was extracted from "Artist - Title", strip artist prefix from title
        if (cArtist && cTitle.startsWith(cArtist + " - ")) {
            root.trackTitle = cTitle.slice(cArtist.length + 3).trim();
        } else {
            root.trackTitle = cTitle;
        }

        root.trackArtist = cArtist || chosen.identity || "";
        root.trackArtUrl = cleanArtUrl(chosen, meta);

        if (root.playing && chosen.positionChanged) {
            chosen.positionChanged();
        }
    }

    // Instant reaction to current player signals (including metadataChanged!)
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPlaybackStateChanged() { root.sync(); }
        function onIsPlayingChanged() { root.sync(); }
        function onMetadataChanged() { root.sync(); }
        function onTrackTitleChanged() { root.sync(); }
        function onTrackArtistChanged() { root.sync(); }
        function onTrackArtUrlChanged() { root.sync(); }
        function onTrackIdChanged() { root.sync(); }
    }

    // Also watch every MPRIS player so starting playback in a secondary player/tab triggers sync()
    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onPlaybackStateChanged() { root.sync(); }
            function onIsPlayingChanged() { root.sync(); }
            function onMetadataChanged() { root.sync(); }
        }
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

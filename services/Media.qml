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
    property color trackAccent: "#5EEAD4"
    property string _lastEmittedTrackKey: ""
    property double _lastEmitMs: 0

    // Optimistic skip: set the instant next()/prev() is requested so the Island can react
    // before the browser delivers new MPRIS metadata.
    property int _pendingSkipDir: 0
    property double _pendingSkipUntil: 0
    property string _skipBaseTitle: ""
    property string _skipBaseArtist: ""
    property string _skipBaseArt: ""
    property int _settleDir: 0
    property bool _syncing: false
    property bool _metaDirty: false

    // Fired immediately when a skip is requested (dir: +1 next, -1 prev).
    signal skipRequested(int dir)
    // dir: +1/-1 = swipe direction; 0 = in-place metadata refresh of an already shown track.
    signal trackChanged(string title, string artist, string artUrl, int dir)

    function _armSkip(dir) {
        _pendingSkipDir = dir;
        _pendingSkipUntil = Date.now() + 3000;
        _skipBaseTitle = root.trackTitle;
        _skipBaseArtist = root.trackArtist;
        _skipBaseArt = root.trackArtUrl;
        _settleDir = 0;
        skipSettleTimer.stop();
        skipRequested(dir);
    }

    function _emitTrack(dir) {
        root._lastEmittedTrackKey = root.trackTitle + "|" + root.trackArtist;
        root._lastEmitMs = Date.now();
        root.trackChanged(root.trackTitle, root.trackArtist, root.trackArtUrl, dir);
    }

    Timer {
        id: skipSettleTimer
        interval: 260
        repeat: false
        onTriggered: {
            if (!root.playing || !root.trackTitle) return;
            const d = root._settleDir || 1;
            root._settleDir = 0;
            root._pendingSkipDir = 0;
            root._emitTrack(d);
        }
    }

    Timer {
        id: trackDebounceTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (!root.playing || !root.trackTitle) return;
            const key = root.trackTitle + "|" + root.trackArtist;
            if (key === root._lastEmittedTrackKey) return;
            // Follow-up metadata (e.g. artist arriving after title) refreshes the card in place
            const recent = (Date.now() - root._lastEmitMs) < 2000;
            root._emitTrack(recent ? 0 : 1);
        }
    }

    function _onMetaChanged() {
        if (_syncing) {
            _metaDirty = true;
            return;
        }
        if (trackTitle === "") {
            _lastEmittedTrackKey = "";
            return;
        }
        if (!playing) return;

        // Pending skip: wait briefly for artist and artUrl to settle if only title changed
        if (_pendingSkipDir !== 0) {
            if (Date.now() > _pendingSkipUntil) {
                _pendingSkipDir = 0;
                _settleDir = 0;
                skipSettleTimer.stop();
            } else if (trackTitle !== _skipBaseTitle) {
                const artistSettled = (_skipBaseArtist === "" || trackArtist !== _skipBaseArtist);
                const artSettled = (_skipBaseArt === "" || trackArtUrl !== _skipBaseArt);
                if (artistSettled && artSettled) {
                    const d = _pendingSkipDir;
                    _pendingSkipDir = 0;
                    _settleDir = 0;
                    skipSettleTimer.stop();
                    trackDebounceTimer.stop();
                    _emitTrack(d);
                    return;
                }
                _settleDir = _pendingSkipDir;
                trackDebounceTimer.stop();
                if (!skipSettleTimer.running) skipSettleTimer.restart();
                return;
            }
        }
        if (skipSettleTimer.running) return;
        trackDebounceTimer.restart();
    }

    onTrackTitleChanged: _onMetaChanged()
    onTrackArtistChanged: _onMetaChanged()
    onTrackArtUrlChanged: _onMetaChanged()
    onPlayingChanged: {
        if (playing && trackTitle !== "" && (trackTitle + "|" + trackArtist) !== _lastEmittedTrackKey) {
            trackDebounceTimer.restart();
        }
    }

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
            art = "file://" + art.split("/").map(seg => encodeURIComponent(seg)).join("/");
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

        if (root.pinned) {
            if (list.indexOf(root.pinned) >= 0) {
                chosen = root.pinned;
            } else {
                root.pinned = null;
            }
        }

        if (!chosen) {
            // 1. Keep current player if it is still playing
            if (root.player && list.indexOf(root.player) >= 0 &&
                (root.player.isPlaying || root.player.playbackState === MprisPlaybackState.Playing)) {
                chosen = root.player;
            }
            // 2. Otherwise look for a player in Playing state (preferring unmuted players)
            if (!chosen) {
                let mutedPlaying = null;
                for (let i = 0; i < list.length; i++) {
                    const p = list[i];
                    if (p && (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)) {
                        if (p.volume !== undefined && p.volume <= 0) {
                            if (!mutedPlaying) mutedPlaying = p;
                        } else {
                            chosen = p;
                            break;
                        }
                    }
                }
                if (!chosen) chosen = mutedPlaying;
            }
            // 3. Otherwise look for player with track metadata
            if (!chosen) {
                for (let i = 0; i < list.length; i++) {
                    const p = list[i];
                    if (p && (p.trackTitle || (p.metadata && p.metadata["xesam:title"]))) {
                        chosen = p;
                        break;
                    }
                }
            }
            // 4. Otherwise use the first available player
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

        root._syncing = true;
        root._metaDirty = false;
        // If artist was extracted from "Artist - Title", strip artist prefix from title
        if (cArtist && cTitle.startsWith(cArtist + " - ")) {
            root.trackTitle = cTitle.slice(cArtist.length + 3).trim();
        } else {
            root.trackTitle = cTitle;
        }

        root.trackArtist = cArtist || chosen.identity || "";
        root.trackArtUrl = cleanArtUrl(chosen, meta);
        root._syncing = false;
        if (root._metaDirty) {
            root._metaDirty = false;
            root._onMetaChanged();
        }

        if (root.playing && chosen.positionChanged) {
            chosen.positionChanged();
        }
    }

    // Track-specific signals for active player (playbackState/isPlaying/metadata are watched for all players below)
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root.sync(); }
        function onTrackArtistChanged() { root.sync(); }
        function onTrackArtUrlChanged() { root.sync(); }
        function onTrackIdChanged() { root.sync(); }
    }

    // Watch every MPRIS player so starting playback in a secondary player/tab triggers sync()
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
        if (!player || !player.canGoNext) return;
        _armSkip(1);
        player.next();
    }

    function prev() {
        if (!player || !player.canGoPrevious) return;
        _armSkip(-1);
        player.previous();
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "0:00";
        const s = Math.floor(sec % 60);
        return Math.floor(sec / 60) + ":" + (s < 10 ? "0" : "") + s;
    }
}

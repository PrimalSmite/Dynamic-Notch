pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import QtQuick

// Authentication service: Polkit + sudo askpass via notch.
// Note: For Polkit to use this agent, ensure no other polkit agent (e.g. polkit-gnome,
// hyprpolkitagent) is running in your session. For sudo -A, export SUDO_ASKPASS=<repo>/scripts/sudo-askpass.sh.
Singleton {
    id: root

    signal requested()
    signal finished()

    // Manual/sudo-askpass request mode (when invoked via IPC)
    property bool manualActive: false
    property string manualMessage: ""
    property string manualActionId: ""
    property string manualReplyFile: ""
    property string manualError: ""
    property bool submitting: false

    readonly property bool active: agent.isActive || manualActive
    readonly property var flow: agent.flow

    readonly property string _allowedFifoDir: {
        const xdg = Quickshell.env("XDG_RUNTIME_DIR");
        const base = (xdg && xdg.length > 0) ? xdg : "/tmp";
        return base + "/dynamic-notch-askpass/";
    }

    function _isValidReplyFifo(path) {
        if (!path || typeof path !== "string") return false;
        if (path.indexOf("..") !== -1) return false;
        if (path.indexOf(_allowedFifoDir) === 0) return true;
        // Fallback for systems without XDG_RUNTIME_DIR (/tmp/dynamic-notch-<uid>/dynamic-notch-askpass/)
        return /^\/tmp\/dynamic-notch-\d+\/dynamic-notch-askpass\/askpass-\d+\.fifo$/.test(path);
    }

    readonly property string message: {
        if (agent.isActive && agent.flow)
            return agent.flow.message || "Authentication is needed to perform this action";
        if (manualActive)
            return manualMessage;
        return "";
    }

    readonly property string actionId: {
        if (agent.isActive && agent.flow)
            return agent.flow.actionId || "org.freedesktop.policykit.exec";
        if (manualActive)
            return manualActionId;
        return "";
    }

    readonly property string promptText: {
        if (agent.isActive && agent.flow && agent.flow.inputPrompt)
            return agent.flow.inputPrompt.replace(/:\s*$/, "");
        return "Password";
    }

    readonly property string errorText: {
        if (agent.isActive && agent.flow) {
            if (agent.flow.supplementaryMessage) return agent.flow.supplementaryMessage;
            if (agent.flow.failed) return "Authentication failed";
        }
        return manualError;
    }

    // Write askpass reply via stdin so passwords are never exposed in /proc/<pid>/cmdline.
    Process {
        id: replyProc
        property string pendingPayload: ""
        stdinEnabled: true
        onRunningChanged: {
            if (running && pendingPayload !== "") {
                const data = pendingPayload;
                pendingPayload = "";
                write(data);
                stdinEnabled = false;
            }
        }
        onExited: {
            stdinEnabled = true;
        }
    }

    function _sendFifoReply(fifoPath, payload) {
        if (!_isValidReplyFifo(fifoPath)) return;
        replyProc.running = false;
        replyProc.stdinEnabled = true;
        replyProc.pendingPayload = payload;
        replyProc.command = ["sh", "-c", "[ -p \"$1\" ] && cat > \"$1\"", "_", fifoPath];
        replyProc.running = true;
    }

    PolkitAgent {
        id: agent
        onIsActiveChanged: {
            root.submitting = false;
            if (isActive) root.requested();
            else if (!root.manualActive) root.finished();
        }
    }

    Connections {
        target: agent.flow
        ignoreUnknownSignals: true
        function onFailedChanged() {
            if (agent.flow && agent.flow.failed) root.submitting = false;
        }
        function onInputPromptChanged() {
            root.submitting = false;
        }
    }

    function openAskpass(msg, actId, replyFile) {
        if (manualActive && manualReplyFile !== "" && manualReplyFile !== replyFile) {
            _sendFifoReply(manualReplyFile, "CANCEL\n");
        }
        if (replyFile && !_isValidReplyFifo(replyFile)) {
            return;
        }
        manualMessage = msg || "Authentication is needed to run command as the super user";
        manualActionId = actId || "sudo.askpass";
        manualReplyFile = replyFile || "";
        manualError = "";
        submitting = false;
        manualActive = true;
        root.requested();
    }

    function submit(password) {
        if (agent.isActive && agent.flow) {
            submitting = true;
            agent.flow.submit(password);
            return;
        }
        if (manualActive) {
            const fifo = manualReplyFile;
            manualActive = false;
            manualReplyFile = "";
            submitting = false;
            if (fifo !== "") {
                _sendFifoReply(fifo, "OK:" + password + "\n");
            }
            root.finished();
        }
    }

    function cancel() {
        submitting = false;
        if (agent.isActive && agent.flow) {
            agent.flow.cancelAuthenticationRequest();
        }
        if (manualActive) {
            const fifo = manualReplyFile;
            manualActive = false;
            manualReplyFile = "";
            if (fifo !== "") {
                _sendFifoReply(fifo, "CANCEL\n");
            }
        }
        root.finished();
    }
}

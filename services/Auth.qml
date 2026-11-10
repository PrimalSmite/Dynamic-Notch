pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import QtQuick

// Authentication service: Polkit + sudo askpass via notch.
Singleton {
    id: root

    signal requested()
    signal finished()

    // Manual/sudo-askpass request mode (when invoked via IPC or test)
    property bool manualActive: false
    property string manualMessage: ""
    property string manualActionId: ""
    property string manualReplyFile: ""
    property string manualError: ""

    readonly property bool active: agent.isActive || manualActive
    readonly property var flow: agent.flow

    readonly property string message: {
        if (agent.isActive && agent.flow)
            return agent.flow.message || "Authentication is needed to perform this action";
        if (manualActive)
            return manualMessage;
        return "Authentication is needed to run `/usr/bin/true' as the super user";
    }

    readonly property string actionId: {
        if (agent.isActive && agent.flow)
            return agent.flow.actionId || "org.freedesktop.policykit.exec";
        if (manualActive)
            return manualActionId;
        return "org.freedesktop.policykit.exec";
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

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: {
            root.requested();
        }
        onIsActiveChanged: {
            if (isActive) root.requested();
            else if (!root.manualActive) root.finished();
        }
    }

    function openAskpass(msg, actId, replyFile) {
        manualMessage = msg || "Authentication is needed to run command as the super user";
        manualActionId = actId || "sudo.askpass";
        manualReplyFile = replyFile || "";
        manualError = "";
        manualActive = true;
        root.requested();
    }

    function submit(password) {
        if (agent.isActive && agent.flow) {
            agent.flow.submit(password);
            return;
        }
        if (manualActive) {
            if (manualReplyFile !== "") {
                Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "_", password, manualReplyFile]);
            }
            manualActive = false;
            manualReplyFile = "";
            root.finished();
        }
    }

    function cancel() {
        if (agent.isActive && agent.flow) {
            agent.flow.cancelAuthenticationRequest();
        }
        if (manualActive) {
            if (manualReplyFile !== "") {
                Quickshell.execDetached(["sh", "-c", "printf '\\n' > \"$1\" 2>/dev/null; rm -f \"$1\"", "_", manualReplyFile]);
            }
            manualActive = false;
            manualReplyFile = "";
        }
        root.finished();
    }
}

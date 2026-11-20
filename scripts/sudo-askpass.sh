#!/usr/bin/env sh
# Usage: SUDO_ASKPASS=/path/to/sudo-askpass.sh sudo -A <command>
DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_BASE="${XDG_RUNTIME_DIR:-/tmp/dynamic-notch-$(id -u)}"
FIFO_DIR="$RUNTIME_BASE/dynamic-notch-askpass"
mkdir -p -m 700 "$FIFO_DIR"

FIFO="$FIFO_DIR/askpass-$$.fifo"
rm -f "$FIFO"
mkfifo -m 600 "$FIFO" || exit 1
trap 'rm -f "$FIFO"' EXIT INT TERM

PROMPT="${1:-Authentication is needed to run command as the super user}"
if ! command -v qs >/dev/null 2>&1; then
    exit 1
fi

if ! qs -p "$DIR" ipc call island askpass "$PROMPT" "sudo.askpass" "$FIFO" >/dev/null 2>&1; then
    exit 1
fi

if [ -p "$FIFO" ]; then
    IFS= read -r reply < "$FIFO" || exit 1
    case "$reply" in
        OK:*)
            printf '%s\n' "${reply#OK:}"
            exit 0
            ;;
        *)
            exit 1
            ;;
    esac
fi
exit 1

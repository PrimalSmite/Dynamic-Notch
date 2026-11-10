#!/usr/bin/env sh
# Usage: SUDO_ASKPASS=/path/to/sudo-askpass.sh sudo -A <command>
DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIFO="/tmp/di-askpass-$$.fifo"
rm -f "$FIFO"
mkfifo -m 600 "$FIFO"
trap 'rm -f "$FIFO"' EXIT INT TERM

PROMPT="${1:-Authentication is needed to run command as the super user}"
qs -p "$DIR" ipc call island askpass "$PROMPT" "sudo.askpass" "$FIFO" >/dev/null 2>&1

if [ -p "$FIFO" ]; then
    cat "$FIFO"
fi

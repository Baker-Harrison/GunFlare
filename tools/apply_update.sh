#!/bin/sh
# GUNFARE_UPDATE_SCRIPT_UNIX
# Wait until the game stops. Copy the new files. Start the game again.
set -eu
WAIT_PID="$1"
ZIP_PATH="$2"
INSTALL_DIR="$3"
EXE_NAME="$4"
LOG_PATH="$5"

log() {
    mkdir -p "$(dirname "$LOG_PATH")"
    printf '%s\n' "$1" > "$LOG_PATH"
}

deadline=$(( $(date +%s) + 120 ))
while kill -0 "$WAIT_PID" 2>/dev/null; do
    if [ "$(date +%s)" -gt "$deadline" ]; then
        log "FAIL The game process did not stop."
        exit 1
    fi
    sleep 0.4
done
sleep 1

stage=$(mktemp -d "${TMPDIR:-/tmp}/gunfare-update.XXXXXX")
unzip -q -o "$ZIP_PATH" -d "$stage"
source="$stage"
if [ ! -e "$source/$EXE_NAME" ]; then
    set -- "$source"/*
    if [ "$#" -eq 1 ] && [ -d "$1" ]; then
        source="$1"
    fi
fi
if [ ! -e "$source/$EXE_NAME" ]; then
    log "FAIL The package does not contain $EXE_NAME."
    exit 1
fi
cp -a "$source"/. "$INSTALL_DIR"/
log "OK"
rm -rf "$stage"
target="$INSTALL_DIR/$EXE_NAME"
case "$EXE_NAME" in
    *.app)
        open "$target"
        ;;
    *)
        chmod +x "$target" || true
        "$target" >/dev/null 2>&1 &
        ;;
esac

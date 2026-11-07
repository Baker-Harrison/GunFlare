#!/bin/sh
# GUNFARE_UPDATE_SCRIPT_UNIX
# Wait until the game stops. Replace the files. Start the game again.
# If a step fails, put the old files back and start the old game.
set -u
WAIT_PID="$1"
ZIP_PATH="$2"
INSTALL_DIR="$3"
EXE_NAME="$4"
LOG_PATH="$5"
# MOVED_FLAG is 1 when the game ran from a temporary folder. Then INSTALL_DIR
# is a new permanent folder.
MOVED_FLAG="${6:-0}"
NO_START="${GUNFARE_UPDATE_NO_START:-0}"

stage=""
backup=""
moved=""
placed=""

detail() {
    mkdir -p "$(dirname "$LOG_PATH")" 2>/dev/null || true
    { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >> "$LOG_PATH.details"; } 2>/dev/null || true
}

log() {
    mkdir -p "$(dirname "$LOG_PATH")"
    printf '%s\n' "$1" > "$LOG_PATH"
    detail "$1"
}

start_game() {
    target="$INSTALL_DIR/$EXE_NAME"
    if [ "$NO_START" = "1" ] || [ ! -e "$target" ]; then
        return 0
    fi
    case "$EXE_NAME" in
        *.app)
            open "$target" >/dev/null 2>&1 || true
            ;;
        *)
            chmod +x "$target" 2>/dev/null || true
            (cd "$INSTALL_DIR" && nohup "$target" >/dev/null 2>&1 &) || true
            ;;
    esac
}

restore_old() {
    for name in $placed; do
        rm -rf "$INSTALL_DIR/$name.gunfare-new" 2>/dev/null || true
        rm -rf "$INSTALL_DIR/$name" 2>/dev/null || detail "Remove failed. $name"
    done
    for name in $moved; do
        mv -f "$backup/$name" "$INSTALL_DIR/$name" 2>/dev/null || detail "Restore failed. $name"
    done
}

cleanup() {
    if [ -n "$stage" ] && [ -d "$stage" ]; then
        rm -rf "$stage"
    fi
}

fail() {
    detail "Error. $1"
    restore_old
    if [ -n "$backup" ] && [ -d "$backup" ]; then
        rm -rf "$backup"
    fi
    log "FAIL $1"
    cleanup
    start_game
    exit 1
}

extract() {
    if command -v ditto >/dev/null 2>&1; then
        ditto -x -k "$1" "$2" && return 0
    fi
    if command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$1" -d "$2" && return 0
    fi
    if command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$1" -C "$2" && return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -I -m zipfile -e "$1" "$2" && return 0
    fi
    return 1
}

detail "Start. Folder $INSTALL_DIR"
deadline=$(( $(date +%s) + 120 ))
while kill -0 "$WAIT_PID" 2>/dev/null; do
    if [ "$(date +%s)" -gt "$deadline" ]; then
        fail "The game did not close in 2 minutes."
    fi
    sleep 1
done
sleep 1

for old in "$INSTALL_DIR"/.gunfare-backup-*; do
    if [ -d "$old" ]; then
        rm -rf "$old"
    fi
done

stage=$(mktemp -d "${TMPDIR:-/tmp}/gunfare-update.XXXXXX") || fail "A temporary folder was not made."
extract "$ZIP_PATH" "$stage" || fail "The package did not extract."
source="$stage"
if [ ! -e "$source/$EXE_NAME" ]; then
    set -- "$source"/*
    if [ "$#" -eq 1 ] && [ -d "$1" ]; then
        source="$1"
    fi
fi
if [ ! -e "$source/$EXE_NAME" ]; then
    fail "The package does not contain $EXE_NAME."
fi

mkdir -p "$INSTALL_DIR" || fail "The folder $INSTALL_DIR was not made."
backup="$INSTALL_DIR/.gunfare-backup-$$"
mkdir -p "$backup" || fail "The install folder is read-only. Move the game to a folder that you can write to."
for path in "$source"/* "$source"/.[!.]*; do
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        continue
    fi
    name=$(basename "$path")
    case "$name" in
        *[[:space:]]*)
            fail "The package has a file name with a space: $name"
            ;;
    esac
    if [ -e "$INSTALL_DIR/$name" ] || [ -L "$INSTALL_DIR/$name" ]; then
        mv -f "$INSTALL_DIR/$name" "$backup/$name" || fail "Moving $name failed."
        moved="$name $moved"
    fi
    placed="$name $placed"
    cp -a "$path" "$INSTALL_DIR/$name.gunfare-new" || fail "Copying $name failed."
    mv -f "$INSTALL_DIR/$name.gunfare-new" "$INSTALL_DIR/$name" || fail "Copying $name failed."
done
case "$EXE_NAME" in
    *.app)
        xattr -dr com.apple.quarantine "$INSTALL_DIR/$EXE_NAME" 2>/dev/null || true
        ;;
    *)
        chmod +x "$INSTALL_DIR/$EXE_NAME" 2>/dev/null || true
        ;;
esac
if [ ! -e "$INSTALL_DIR/$EXE_NAME" ]; then
    fail "The new $EXE_NAME is missing after the copy."
fi
if [ "$MOVED_FLAG" = "1" ]; then
    log "OK MOVED $INSTALL_DIR"
else
    log "OK"
fi
rm -rf "$backup"
cleanup
start_game
exit 0

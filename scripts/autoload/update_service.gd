extends Node
## Look for a newer GitHub release while the game runs. Download the package,
## check it, and install it after this process stops.
##
## The check runs at start, every CHECK_INTERVAL seconds, and when the window
## gets the focus again. Thus a new release shows on the main menu without a
## restart. The install scripts below are copies of tools/apply_update.ps1 and
## tools/apply_update.sh. tools/check_update_scripts.py makes sure that they match.

signal state_changed

const REPO := "Baker-Harrison/GunFlare"
const API_URL := "https://api.github.com/repos/%s/releases/latest"
const MAX_BYTES := 1024 * 1024 * 1024
const CHECK_INTERVAL := 300.0
const FOCUS_RECHECK_MS := 60000
const STALL_SECONDS := 45.0
## Automatic retries of a download that fails on the network, before the menu
## shows an error.
const DOWNLOAD_RETRIES := 2
const UPDATE_DIR := "user://updates"
const LOG_FILE := "user://updates/install.log"
const WINDOWS_SCRIPT := r"""# GUNFARE_UPDATE_SCRIPT_WINDOWS
# Wait until the game stops. Replace the files. Start the game again.
# If a step fails, put the old files back and start the old game.
# Moved is "1" when the game ran from a temporary folder. Then InstallDir is a
# new permanent folder.
param(
    [Parameter(Mandatory = $true)][int]$WaitPid,
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$ExeName,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$Moved = "0"
)

$ErrorActionPreference = "Stop"
$stage = $null
$backup = $null
$movedItems = New-Object System.Collections.ArrayList
$placed = New-Object System.Collections.ArrayList
$detailPath = $LogPath + ".details"

function Write-Detail($text) {
    try {
        $line = (Get-Date).ToString("s") + " " + $text + [Environment]::NewLine
        [System.IO.File]::AppendAllText($detailPath, $line)
    } catch { }
}

function Write-UpdateLog($text) {
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($LogPath, $text, $utf8)
    Write-Detail $text
}

function Invoke-Retry([scriptblock]$Action, [string]$What) {
    $last = $null
    for ($i = 0; $i -lt 60; $i++) {
        try {
            & $Action
            return
        } catch {
            $last = $_
            Start-Sleep -Milliseconds 500
        }
    }
    throw ($What + " failed. " + $last.Exception.Message)
}

function Test-FileFree([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $true
    }
    try {
        $stream = [System.IO.File]::Open($Path, "Open", "ReadWrite", "None")
        $stream.Close()
        return $true
    } catch {
        return $false
    }
}

function Get-GameProcesses {
    $root = [System.IO.Path]::GetFullPath($InstallDir).TrimEnd([char]92, [char]47) + [System.IO.Path]::DirectorySeparatorChar
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $path = $null
        try { $path = $_.Path } catch { }
        $path -and $path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
    }
}

function Start-Game {
    if ($env:GUNFARE_UPDATE_NO_START -eq "1") {
        return
    }
    $exe = Join-Path $InstallDir $ExeName
    if (Test-Path -LiteralPath $exe) {
        try { Start-Process -FilePath $exe -WorkingDirectory $InstallDir } catch { Write-Detail ("Start failed. " + $_.Exception.Message) }
    }
}

function Restore-OldFiles {
    for ($i = $placed.Count - 1; $i -ge 0; $i--) {
        $target = $placed[$i]
        try { Remove-Item -LiteralPath $target -Recurse -Force } catch { Write-Detail ("Remove failed. " + $target) }
    }
    for ($i = $movedItems.Count - 1; $i -ge 0; $i--) {
        $pair = $movedItems[$i]
        try {
            Invoke-Retry { Move-Item -LiteralPath $pair[1] -Destination $pair[0] -Force } "Restore"
        } catch {
            Write-Detail ("Restore failed. " + $pair[0])
        }
    }
}

try {
    Write-Detail ("Start. Folder " + $InstallDir)
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $deadline = (Get-Date).AddMinutes(2)
    while (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue) {
        if ((Get-Date) -gt $deadline) {
            throw "The game did not close in 2 minutes."
        }
        Start-Sleep -Milliseconds 400
    }
    $deadline = (Get-Date).AddMinutes(1)
    while (@(Get-GameProcesses).Count -gt 0) {
        if ((Get-Date) -gt $deadline) {
            throw "Another GunFare window is open. Close all GunFare windows and try again."
        }
        Start-Sleep -Milliseconds 500
    }
    $exePath = Join-Path $InstallDir $ExeName
    $deadline = (Get-Date).AddMinutes(1)
    while (-not (Test-FileFree $exePath)) {
        if ((Get-Date) -gt $deadline) {
            throw "Another program uses $ExeName. Close that program and try again."
        }
        Start-Sleep -Milliseconds 500
    }

    Get-ChildItem -LiteralPath $InstallDir -Filter ".gunfare-backup-*" -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("gunfare-update-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $stage -Force
    $source = $stage
    $entries = @(Get-ChildItem -LiteralPath $stage -Force)
    if (-not (Test-Path -LiteralPath (Join-Path $stage $ExeName)) -and $entries.Count -eq 1 -and $entries[0].PSIsContainer) {
        $source = $entries[0].FullName
    }
    if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
        throw "The package does not contain $ExeName."
    }

    $backup = Join-Path $InstallDir (".gunfare-backup-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($item in @(Get-ChildItem -LiteralPath $source -Force)) {
        $target = Join-Path $InstallDir $item.Name
        if (Test-Path -LiteralPath $target) {
            $saved = Join-Path $backup $item.Name
            Invoke-Retry { Move-Item -LiteralPath $target -Destination $saved -Force } ("Moving " + $item.Name)
            [void]$movedItems.Add(@($target, $saved))
        }
        [void]$placed.Add($target)
        Invoke-Retry { Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -Force } ("Copying " + $item.Name)
    }
    # Unblock-File exists only on Windows. A failure here must not stop the install.
    $canUnblock = ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) -and [bool](Get-Command Unblock-File -ErrorAction SilentlyContinue)
    foreach ($target in $placed) {
        if (-not $canUnblock) {
            break
        }
        Get-ChildItem -LiteralPath $target -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue } catch { }
        }
    }
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "The new $ExeName is missing after the copy."
    }
    if ($Moved -eq "1") {
        Write-UpdateLog ("OK MOVED " + $InstallDir)
    }
    else {
        Write-UpdateLog "OK"
    }
    Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    $backup = $null
    Start-Game
}
catch {
    $reason = $_.Exception.Message
    Write-Detail ("Error. " + $reason)
    Restore-OldFiles
    try { Write-UpdateLog ("FAIL " + $reason) } catch { }
    if ($backup -and (Test-Path -LiteralPath $backup)) {
        Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    }
    Start-Game
    exit 1
}
finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}"""
const UNIX_SCRIPT := r"""#!/bin/sh
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
exit 0"""

var current_version := "0.0.0"
var remote_version := ""
## idle, available, downloading, installing, or error.
var status := "idle"
var progress := 0.0
var message := ""
var install_error := ""
## A note after an update that moved the game to a permanent folder.
var install_notice := ""
var _url := ""
var _asset_size := -1
var _asset_digest := ""
var _etag := ""
var _checking := false
var _last_check_ms := -FOCUS_RECHECK_MS
var _part_path := ""
var _check_http: HTTPRequest
var _download_http: HTTPRequest
var _timer: Timer
var _last_percent := -1
var _stall_bytes := -1
var _stall_time := 0.0
var _retries_left := 0


func _ready() -> void:
	current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	set_process(false)
	_read_install_log()
	if _updates_disabled():
		return
	_cleanup_old_files()
	_check_http = HTTPRequest.new()
	_check_http.timeout = 20.0
	add_child(_check_http)
	_check_http.request_completed.connect(_on_check_done)
	_download_http = new_download_request()
	add_child(_download_http)
	_download_http.request_completed.connect(_on_download_done)
	_timer = Timer.new()
	_timer.wait_time = CHECK_INTERVAL
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(check_now)
	check_now.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _check_http != null:
		if Time.get_ticks_msec() - _last_check_ms >= FOCUS_RECHECK_MS:
			check_now()


func _process(delta: float) -> void:
	if status != "downloading" or _download_http == null:
		set_process(false)
		return
	var got := _download_http.get_downloaded_bytes()
	var total := _download_http.get_body_size()
	if total <= 0:
		total = _asset_size
	if total > MAX_BYTES or got > MAX_BYTES:
		_stop_download("The package is larger than 1 GB.")
		return
	if got != _stall_bytes:
		_stall_bytes = got
		_stall_time = 0.0
	else:
		_stall_time += delta
		if _stall_time > STALL_SECONDS:
			_stop_download("The download stopped. Examine the network connection and try again.")
			return
	if total <= 0:
		return
	progress = clampf(float(got) / float(total), 0.0, 1.0)
	var percent := int(progress * 100.0)
	if percent != _last_percent:
		_last_percent = percent
		message = "Downloading version %s. %d percent." % [remote_version, percent]
		state_changed.emit()


# --- Public API ----------------------------------------------------------------

func can_install() -> bool:
	if _url == "" or not (status == "available" or status == "error"):
		return false
	return _is_release_install()


## Asks GitHub for the latest release now. A busy updater ignores the call.
func check_now() -> void:
	if _check_http == null or _checking or status == "downloading" or status == "installing":
		return
	if status == "error" and not can_install():
		# TRY AGAIN: go back to the last good state.
		status = "available" if _url != "" else "idle"
		message = _available_text() if _url != "" else ""
		state_changed.emit()
	_checking = true
	_last_check_ms = Time.get_ticks_msec()
	var headers := _headers()
	if _etag != "":
		headers.append("If-None-Match: " + _etag)
	var err := _check_http.request(API_URL % REPO, headers)
	if err != OK:
		_checking = false
		print("[update] The version check did not start (%s)." % error_string(err))


## The main menu calls this name for TRY AGAIN.
func _check() -> void:
	check_now()


func install() -> void:
	if not can_install():
		# The banner already shows the reason. A blocked install is not an error.
		return
	_retries_left = DOWNLOAD_RETRIES
	_start_download()


func _start_download() -> void:
	status = "downloading"
	progress = 0.0
	_last_percent = -1
	_stall_bytes = -1
	_stall_time = 0.0
	install_error = ""
	message = "Downloading version %s." % remote_version
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATE_DIR))
	_part_path = ProjectSettings.globalize_path("%s/GunFare-%s.zip.part" % [UPDATE_DIR, remote_version])
	_remove(_part_path)
	_download_http.download_file = _part_path
	var err := _download_http.request(_url, download_headers(current_version))
	if err != OK:
		_fail("The download did not start. Examine the network connection and try again.")
		return
	set_process(true)
	state_changed.emit()


## Reads a release from the GitHub API and updates the state.
func apply_release(release: Dictionary) -> void:
	var info := pick_asset(release, str(_package()["asset"]))
	if info.is_empty():
		return
	if not is_newer(info["version"], current_version):
		if status == "available":
			status = "idle"
			message = ""
			_url = ""
			state_changed.emit()
		return
	var same: bool = info["version"] == remote_version and info["url"] == _url
	remote_version = info["version"]
	_url = info["url"]
	_asset_size = info["size"]
	_asset_digest = info["digest"]
	if same and (status == "available" or status == "error"):
		return
	if status == "downloading" or status == "installing":
		return
	status = "available"
	message = _available_text()
	state_changed.emit()


## The folder that receives the update, and whether it differs from the
## folder of the running game. A copy that runs from a zip, a temporary
## folder, or a read-only folder installs into a permanent folder instead.
func install_target() -> Dictionary:
	var dir := game_dir()
	if is_temporary_dir(dir, OS.get_name(), _temp_dirs()) or not _is_writable(dir):
		return {"dir": _fallback_dir(), "moved": true}
	return {"dir": dir, "moved": false}


## The folder of the running game. On macOS, the folder that holds GunFare.app.
func game_dir() -> String:
	var exe := OS.get_executable_path()
	if OS.get_name() == "macOS":
		var app := app_bundle_path(exe)
		if app != "":
			return app.get_base_dir()
	return exe.get_base_dir()


# --- Pure helpers (the tests call these) ---------------------------------------

## The HTTP request that downloads a package. tests/test_update_download.gd
## uses the same request, so CI downloads a real release the same way.
static func new_download_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	# The whole download can take minutes. _process stops a download that stalls.
	http.timeout = 0.0
	http.accept_gzip = false
	# A thread reads the body. Without it, the download reads one chunk per
	# frame, so a slow or background window starves the connection and the
	# server closes it.
	http.use_threads = true
	http.download_chunk_size = 1048576
	return http


## Headers for a request to the GitHub API (the version check).
static func api_headers(version: String) -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: GunFare/" + version,
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
	])


## Headers for the package download.
static func download_headers(version: String) -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: GunFare/" + version,
		"Accept: application/octet-stream",
	])


static func is_newer(remote: String, local: String) -> bool:
	var remote_parts := _parts(remote)
	var local_parts := _parts(local)
	if remote_parts.is_empty():
		return false
	var count := maxi(remote_parts.size(), local_parts.size())
	for i in count:
		var r := remote_parts[i] if i < remote_parts.size() else 0
		var l := local_parts[i] if i < local_parts.size() else 0
		if r != l:
			return r > l
	return false


static func _parts(version: String) -> Array[int]:
	var text := version.strip_edges().trim_prefix("v")
	var cut := text.find("-")
	if cut >= 0:
		text = text.substr(0, cut)
	var out: Array[int] = []
	for piece in text.split("."):
		if piece.is_valid_int():
			out.append(int(piece))
		elif not piece.is_empty():
			out.append(0)
	return out


## Returns {version, url, size, digest} for the named asset, or {} if the release
## is not usable.
static func pick_asset(release: Dictionary, asset_name: String) -> Dictionary:
	if bool(release.get("draft", false)) or bool(release.get("prerelease", false)):
		return {}
	var version := str(release.get("tag_name", "")).strip_edges().trim_prefix("v")
	if version == "" or _parts(version).is_empty():
		return {}
	var assets = release.get("assets", [])
	if typeof(assets) != TYPE_ARRAY:
		return {}
	for asset in assets:
		if typeof(asset) != TYPE_DICTIONARY or str(asset.get("name", "")) != asset_name:
			continue
		var url := str(asset.get("browser_download_url", ""))
		if not url_is_trusted(url):
			continue
		var digest := str(asset.get("digest", "")).strip_edges().to_lower()
		if digest.begins_with("sha256:"):
			digest = digest.substr(7)
		else:
			digest = ""
		var size_value = asset.get("size", -1)
		var size := int(size_value) if typeof(size_value) in [TYPE_INT, TYPE_FLOAT] else -1
		return {"version": version, "url": url, "size": size, "digest": digest}
	return {}


## A short reason for an HTTPRequest result, for the menu and the log.
static func result_text(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "The server returned HTTP %d." % code
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "The connection closed during the download."
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE:
			return "The game cannot connect to GitHub. Examine the network connection."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "The secure connection to GitHub failed. Examine the system clock and the network."
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "The game cannot write the package. Examine the free disk space."
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "GitHub sent too many redirects."
		HTTPRequest.RESULT_TIMEOUT:
			return "The download took too long."
	return "Network error %d." % result


## True when a new attempt can help (network or server trouble).
static func can_retry(result: int, code: int) -> bool:
	if result == HTTPRequest.RESULT_SUCCESS:
		return code >= 500 or code == 429 or code == 408
	return result in [HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH, HTTPRequest.RESULT_CONNECTION_ERROR,
		HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, HTTPRequest.RESULT_TIMEOUT]


static func url_is_trusted(url: String) -> bool:
	return url.begins_with("https://github.com/") \
		or url.begins_with("https://objects.githubusercontent.com/") \
		or url.begins_with("https://release-assets.githubusercontent.com/")


## True when an update must not go into this folder: Explorer runs a zip from
## a temporary folder, and macOS runs a downloaded app from a read-only copy.
static func is_temporary_dir(dir: String, os_name: String, temp_dirs: PackedStringArray) -> bool:
	var d := _norm_dir(dir)
	if d.contains("/apptranslocation/"):
		return true
	if d.contains(".zip/") or d.contains(".zip.") or d.contains("/temp1_"):
		return true
	if os_name == "Windows" and d.contains("/appdata/local/temp/"):
		return true
	if os_name != "Windows" and os_name != "macOS" and (d.begins_with("/tmp/") or d.begins_with("/var/tmp/")):
		return true
	for t in temp_dirs:
		var n := _norm_dir(t)
		if n.length() > 3 and d.begins_with(n):
			return true
	return false


static func _norm_dir(path: String) -> String:
	var d := path.replace("\\", "/").strip_edges().to_lower()
	if not d.ends_with("/"):
		d += "/"
	return d


## Returns the path of the .app bundle that holds the executable, or "".
static func app_bundle_path(exe: String) -> String:
	var marker := ".app/Contents/MacOS/"
	var at := exe.find(marker)
	if at < 0:
		return ""
	return exe.substr(0, at + 4)


## Returns "" when the package is good, or the reason that it is not.
static func verify_package(path: String, size: int, digest: String, exe: String) -> String:
	if not FileAccess.file_exists(path):
		return "The download did not make a file."
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "The downloaded file cannot be read."
	var got := f.get_length()
	f.close()
	if size > 0 and got != size:
		return "The download is not complete (%d of %d bytes). Try again." % [got, size]
	if digest != "" and FileAccess.get_sha256(path).to_lower() != digest:
		return "The downloaded file is damaged. The checksum is not correct. Try again."
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return "The downloaded file is not a valid zip package. Try again."
	var found := false
	for entry in zip.get_files():
		var e := entry.replace("\\", "/")
		if e == exe or e.ends_with("/" + exe) or e.begins_with(exe + "/") or e.contains("/" + exe + "/"):
			found = true
			break
	zip.close()
	if not found:
		return "The package does not contain %s." % exe
	return ""


## Makes the text of an install log easy to read and act on.
static func friendly_error(raw: String) -> String:
	var text := raw.trim_prefix(char(0xFEFF)).strip_edges().trim_prefix("FAIL").strip_edges()
	var low := text.to_lower()
	if low.contains("being used by another process") or low.contains("another program uses"):
		return "Another program used a game file during the install. Close all GunFare windows and try again. If the game runs from a zip file, extract the zip to a folder first."
	if low.contains("denied") or low.contains("read-only") or low.contains("unauthorized"):
		return "The update could not write to the game folder. Move the game to a folder that you own, for example Documents/GunFare. Then try again."
	if text.length() > 300:
		text = text.left(300) + "..."
	return text


# --- Internals -----------------------------------------------------------------

func _updates_disabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if OS.has_feature("editor"):
		return true
	return OS.get_cmdline_user_args().has("--no-update")


func _is_release_install() -> bool:
	return OS.has_feature("template") and OS.get_executable_path().get_file().begins_with("GunFare")


func _package() -> Dictionary:
	match OS.get_name():
		"Windows":
			return {"asset": "GunFare-windows.zip", "exe": "GunFare.exe", "script": "apply_update.ps1", "text": WINDOWS_SCRIPT}
		"macOS":
			return {"asset": "GunFare-macos.zip", "exe": "GunFare.app", "script": "apply_update.sh", "text": UNIX_SCRIPT}
		_:
			return {"asset": "GunFare-linux.zip", "exe": "GunFare.x86_64", "script": "apply_update.sh", "text": UNIX_SCRIPT}


func _temp_dirs() -> PackedStringArray:
	var out := PackedStringArray()
	for key in ["TEMP", "TMP", "TMPDIR"]:
		var value := OS.get_environment(key)
		if value != "":
			out.append(value)
	return out


func _available_text() -> String:
	if not _is_release_install():
		return "Version %s is available. This source build cannot install it." % remote_version
	var target := install_target()
	if target["moved"]:
		return "Version %s is available. The game runs from a temporary folder. The update installs into %s." % [remote_version, target["dir"]]
	return "Version %s is available." % remote_version


func _is_writable(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir):
		return false
	var probe := dir.path_join(".gunfare_write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _fallback_dir() -> String:
	match OS.get_name():
		"Windows":
			var local := OS.get_environment("LOCALAPPDATA")
			if local == "":
				local = OS.get_environment("USERPROFILE").path_join("AppData/Local")
			return local.replace("\\", "/").path_join("Programs/GunFare")
		"macOS":
			return OS.get_environment("HOME").path_join("Applications")
		_:
			var data := OS.get_environment("XDG_DATA_HOME")
			if data == "":
				data = OS.get_environment("HOME").path_join(".local/share")
			return data.path_join("GunFare")


func _headers() -> PackedStringArray:
	return api_headers(current_version)


func _on_check_done(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_checking = false
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[update] The version check failed (result %d)." % result)
		return
	if code == 304:
		return
	if code != 200:
		print("[update] The version check returned HTTP %d." % code)
		return
	for h in headers:
		if h.to_lower().begins_with("etag:"):
			_etag = h.substr(5).strip_edges()
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[update] The version check returned text that is not JSON.")
		return
	apply_release(parsed)


func _stop_download(text: String) -> void:
	_download_http.cancel_request()
	_remove(_part_path)
	_fail(text)


func _on_download_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	set_process(false)
	if status != "downloading":
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_remove(_part_path)
		print("[update] Download attempt failed: result %d, HTTP %d." % [result, code])
		if can_retry(result, code) and _retries_left > 0:
			_retries_left -= 1
			_start_download()
			return
		_fail("The download failed. %s Try again. (result %d, HTTP %d)" % [result_text(result, code), result, code])
		return
	var pack := _package()
	var problem := verify_package(_part_path, _asset_size, _asset_digest, str(pack["exe"]))
	if problem != "":
		_remove(_part_path)
		_fail(problem)
		return
	var zip := _part_path.trim_suffix(".part")
	_remove(zip)
	if DirAccess.rename_absolute(_part_path, zip) != OK:
		_fail("The downloaded file could not be renamed.")
		return
	_launch_installer(zip, pack)


func _launch_installer(zip: String, pack: Dictionary) -> void:
	var script_path := ProjectSettings.globalize_path(UPDATE_DIR.path_join(str(pack["script"])))
	var log_path := ProjectSettings.globalize_path(LOG_FILE)
	_remove(log_path)
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	if script == null:
		_fail("The install script was not written.")
		return
	script.store_string(str(pack["text"]))
	script.close()
	var target := install_target()
	var dir: String = target["dir"]
	var moved := "1" if target["moved"] else "0"
	var pid := str(OS.get_process_id())
	var exe := str(pack["exe"])
	var started := -1
	if OS.get_name() == "Windows":
		var args := PackedStringArray([
			"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
			"-File", script_path.replace("/", "\\"), pid, zip.replace("/", "\\"),
			dir.replace("/", "\\"), exe, log_path.replace("/", "\\"), moved,
		])
		var shell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		if OS.get_environment("SystemRoot") == "" or not FileAccess.file_exists(shell):
			shell = "powershell.exe"
		started = OS.create_process(shell, args)
	else:
		started = OS.create_process("/bin/sh", PackedStringArray([script_path, pid, zip, dir, exe, log_path, moved]))
	if started < 0:
		_fail("The install script did not start.")
		return
	status = "installing"
	message = "Installing version %s. The game closes and starts again." % remote_version
	state_changed.emit()
	Progression.save_profile()
	Settings.save()
	get_tree().quit()


func _read_install_log() -> void:
	if not FileAccess.file_exists(LOG_FILE):
		return
	var text := FileAccess.get_file_as_string(LOG_FILE).trim_prefix(char(0xFEFF)).strip_edges()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_FILE))
	if text.begins_with("OK MOVED "):
		install_notice = "GunFare %s is now in %s. Start the game from that folder." % [current_version, text.trim_prefix("OK MOVED ").strip_edges()]
		return
	if text == "OK" or text == "":
		return
	install_error = friendly_error(text)
	print("[update] The last install failed: ", text)


func _cleanup_old_files() -> void:
	var dir := DirAccess.open(UPDATE_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".zip") or file.ends_with(".part"):
			dir.remove(file)


func _fail(text: String) -> void:
	status = "error"
	message = text
	set_process(false)
	print("[update] ", text)
	state_changed.emit()


static func _remove(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

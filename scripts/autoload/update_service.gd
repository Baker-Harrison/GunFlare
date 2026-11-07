extends Node
## Download a newer GitHub release and install it after this process stops.

const REPO := "Baker-Harrison/GunFlare"
const MAX_BYTES := 1024 * 1024 * 1024
const WINDOWS_SCRIPT := """# GUNFARE_UPDATE_SCRIPT_WINDOWS
# Wait until the game stops. Copy the new files. Start the game again.
param(
    [Parameter(Mandatory = $true)][int]$WaitPid,
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$ExeName,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$Moved = ""
)

$ErrorActionPreference = "Stop"
$stage = $null

function Write-UpdateLog($text) {
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -Path $LogPath -Value $text -Encoding utf8
}

try {
    $deadline = (Get-Date).AddMinutes(2)
    while (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue) {
        if ((Get-Date) -gt $deadline) {
            throw "The game process did not stop."
        }
        Start-Sleep -Milliseconds 400
    }
    Start-Sleep -Seconds 1
    $stage = Join-Path $env:TEMP ("gunfare-update-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $stage -Force
    $source = $stage
    $entries = @(Get-ChildItem -LiteralPath $stage)
    $exeAtRoot = Test-Path -LiteralPath (Join-Path $stage $ExeName)
    if (-not $exeAtRoot -and $entries.Count -eq 1 -and $entries[0].PSIsContainer) {
        $source = $entries[0].FullName
    }
    if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
        throw "The package does not contain $ExeName."
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    # A virus scanner or Explorer can hold a file for a short time after the game stops.
    $attempt = 0
    while ($true) {
        try {
            Copy-Item -Path (Join-Path $source "*") -Destination $InstallDir -Recurse -Force
            break
        }
        catch {
            $attempt += 1
            if ($attempt -ge 30) {
                throw
            }
            Start-Sleep -Seconds 1
        }
    }
    if ($Moved -eq "1") {
        Write-UpdateLog ("OK MOVED " + $InstallDir)
    }
    else {
        Write-UpdateLog "OK"
    }
    Start-Process -FilePath (Join-Path $InstallDir $ExeName) -WorkingDirectory $InstallDir
}
catch {
    Write-UpdateLog ("FAIL " + $_.Exception.Message)
    $existing = Join-Path $InstallDir $ExeName
    if (Test-Path -LiteralPath $existing) {
        Start-Process -FilePath $existing -WorkingDirectory $InstallDir
    }
    exit 1
}
finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}"""
const UNIX_SCRIPT := """#!/bin/sh
# GUNFARE_UPDATE_SCRIPT_UNIX
# Wait until the game stops. Copy the new files. Start the game again.
set -eu
WAIT_PID="$1"
ZIP_PATH="$2"
INSTALL_DIR="$3"
EXE_NAME="$4"
LOG_PATH="$5"
MOVED="${6:-0}"

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
mkdir -p "$INSTALL_DIR"
case "$EXE_NAME" in
    *.app)
        # Replace the whole bundle. Old files in a bundle break its signature.
        rm -rf "$INSTALL_DIR/$EXE_NAME"
        ;;
esac
cp -a "$source"/. "$INSTALL_DIR"/
if [ "$MOVED" = "1" ]; then
    log "OK MOVED $INSTALL_DIR"
else
    log "OK"
fi
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
esac"""

signal state_changed

var current_version := "0.0.0"
var remote_version := ""
var status := "idle"
var progress := 0.0
var message := ""
var install_error := ""
var install_notice := ""
var _url := ""
var _asset_name := ""
var _exe_name := ""
var _mode := ""
var _http: HTTPRequest
var _last_percent := -1


func _ready() -> void:
	current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_read_install_log()
	if _updates_disabled():
		return
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	_http.accept_gzip = false
	add_child(_http)
	_http.request_completed.connect(_on_http)
	set_process(false)
	call_deferred("_check")


func _process(_delta: float) -> void:
	if status != "downloading" or _http == null:
		return
	var total := _http.get_body_size()
	var got := _http.get_downloaded_bytes()
	if total > MAX_BYTES or got > MAX_BYTES:
		_http.cancel_request()
		_fail("The package is larger than 1 GB.")
		return
	if total <= 0:
		return
	var percent := int(float(got) * 100.0 / float(total))
	progress = float(got) / float(total)
	if percent != _last_percent:
		_last_percent = percent
		message = "Downloading the update. %d percent." % percent
		state_changed.emit()


func can_install() -> bool:
	return status == "available" and _is_release_install()


func install() -> void:
	if status != "available" or _url == "":
		return
	if not _is_release_install():
		_fail("This copy is a source build. Install the update from a release build.")
		return
	status = "downloading"
	progress = 0.0
	_last_percent = -1
	message = "Downloading the update."
	state_changed.emit()
	set_process(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://updates"))
	_http.download_file = ProjectSettings.globalize_path("user://updates/package.zip")
	_mode = "download"
	var error := _http.request(_url, _headers())
	if error != OK:
		_fail("The download did not start.")


static func is_newer(remote: String, local: String) -> bool:
	var remote_parts := _parts(remote)
	var local_parts := _parts(local)
	var count := maxi(remote_parts.size(), local_parts.size())
	for i in count:
		var r := remote_parts[i] if i < remote_parts.size() else 0
		var l := local_parts[i] if i < local_parts.size() else 0
		if r != l:
			return r > l
	return false


static func _parts(version: String) -> Array[int]:
	var text := version.trim_prefix("v").strip_edges()
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


func _updates_disabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if OS.has_feature("editor"):
		return true
	return OS.get_cmdline_user_args().has("--no-update")


func _is_release_install() -> bool:
	return OS.get_executable_path().get_file().begins_with("GunFare")


func _package() -> Dictionary:
	match OS.get_name():
		"Windows":
			return {"asset": "GunFare-windows.zip", "exe": "GunFare.exe", "script": "apply_update.ps1", "text": WINDOWS_SCRIPT}
		"macOS":
			return {"asset": "GunFare-macos.zip", "exe": "GunFare.app", "script": "apply_update.sh", "text": UNIX_SCRIPT}
		_:
			return {"asset": "GunFare-linux.zip", "exe": "GunFare.x86_64", "script": "apply_update.sh", "text": UNIX_SCRIPT}


func _check() -> void:
	status = "checking"
	_mode = "check"
	_http.download_file = ""
	var error := _http.request("https://api.github.com/repos/%s/releases/latest" % REPO, _headers())
	if error != OK:
		status = "idle"
		print("[update] The version check did not start.")
		state_changed.emit()


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: GunFare",
		"Accept: application/vnd.github+json",
	])


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	set_process(false)
	if _mode == "download":
		_on_download(result, code)
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status = "idle"
		print("[update] No release is available (%d, HTTP %d)." % [result, code])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		status = "idle"
		return
	var tag := str(parsed.get("tag_name", ""))
	remote_version = tag.trim_prefix("v")
	if remote_version == "" or not is_newer(remote_version, current_version):
		status = "idle"
		return
	var pack := _package()
	_asset_name = pack["asset"]
	_exe_name = pack["exe"]
	_url = ""
	for asset in parsed.get("assets", []):
		if str(asset.get("name", "")) != _asset_name:
			continue
		var candidate := str(asset.get("browser_download_url", ""))
		if _url_is_trusted(candidate):
			_url = candidate
	if _url == "":
		status = "idle"
		print("[update] The release does not include ", _asset_name)
		return
	status = "available"
	if _is_release_install():
		message = "Version %s is available." % remote_version
	else:
		message = "Version %s is available. This source build cannot install it." % remote_version
	state_changed.emit()


func _on_download(result: int, code: int) -> void:
	var zip := ProjectSettings.globalize_path("user://updates/package.zip")
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(zip):
		_fail("The download failed.")
		return
	var pack := _package()
	var script_path := ProjectSettings.globalize_path("user://updates/" + pack["script"])
	var log_path := ProjectSettings.globalize_path("user://updates/install.log")
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	if script == null:
		_fail("The install script was not written.")
		return
	script.store_string(pack["text"])
	script.close()
	var target := install_target()
	var install_dir: String = target["dir"]
	var moved := "1" if target["moved"] else "0"
	var pid := str(OS.get_process_id())
	var args: PackedStringArray
	if OS.get_name() == "Windows":
		args = PackedStringArray([
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_path,
			pid, zip, install_dir, _exe_name, log_path, moved,
		])
		var shell := "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
		if not FileAccess.file_exists(shell):
			shell = "powershell.exe"
		if OS.create_process(shell, args) < 0:
			_fail("The install script did not start.")
			return
	else:
		args = PackedStringArray([script_path, pid, zip, install_dir, _exe_name, log_path, moved])
		if OS.create_process("sh", args) < 0:
			_fail("The install script did not start.")
			return
	message = "The update will install after the game closes."
	state_changed.emit()
	get_tree().quit()


func _read_install_log() -> void:
	var path := "user://updates/install.log"
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path).strip_edges()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if text.begins_with("OK MOVED "):
		install_notice = "GunFare %s is now in %s. Start the game from that folder." % [current_version, text.trim_prefix("OK MOVED ").strip_edges()]
		return
	if text == "OK" or text == "":
		return
	install_error = text.trim_prefix("FAIL ").left(400)


## The folder that receives the update, and whether it differs from the
## folder of the running game. A copy that runs from a zip, a temporary
## folder or a read-only folder installs into a permanent folder instead.
func install_target() -> Dictionary:
	var exe := OS.get_executable_path()
	var dir := exe.get_base_dir()
	if OS.get_name() == "macOS":
		# .../GunFare.app/Contents/MacOS/GunFare -> the folder that holds GunFare.app
		var bundle := dir.get_base_dir().get_base_dir()
		if bundle.ends_with(".app"):
			dir = bundle.get_base_dir()
	if is_temporary_dir(dir, OS.get_name(), _temp_dirs()) or not _is_writable(dir):
		return {"dir": _fallback_dir(), "moved": true}
	return {"dir": dir, "moved": false}


static func is_temporary_dir(dir: String, os_name: String, temp_dirs: PackedStringArray) -> bool:
	var d := dir.replace("\\", "/").to_lower().trim_suffix("/") + "/"
	if os_name == "macOS" and d.contains("/apptranslocation/"):
		return true
	if os_name == "Windows" and d.contains(".zip/"):
		return true
	for t in temp_dirs:
		var n := t.replace("\\", "/").to_lower().trim_suffix("/")
		if n != "" and d.begins_with(n + "/"):
			return true
	return false


func _temp_dirs() -> PackedStringArray:
	var out := PackedStringArray()
	for key in ["TEMP", "TMP", "TMPDIR"]:
		var v := OS.get_environment(key)
		if v != "":
			out.append(v)
	return out


func _is_writable(dir: String) -> bool:
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


func _fail(text: String) -> void:
	status = "error"
	message = text
	set_process(false)
	print("[update] ", text)
	state_changed.emit()


func _url_is_trusted(url: String) -> bool:
	return url.begins_with("https://github.com/") \
		or url.begins_with("https://objects.githubusercontent.com/") \
		or url.begins_with("https://release-assets.githubusercontent.com/")

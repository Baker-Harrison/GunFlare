extends Node
## Downloads a real GitHub release package with the game's own update code
## (UpdateService.new_download_request, its headers, verify_package) and
## fails if the package does not download or does not pass the checks.
## Thus a broken release or a broken download path fails CI, not the player.
##
## Run: godot --headless --path . res://tests/test_update_download.tscn -- [tag] [asset] [--compare-api-headers]
##   tag    a release tag such as v0.1.0.10, or "latest" (default)
##   asset  GunFare-windows.zip, GunFare-macos.zip or GunFare-linux.zip (default)

const Updater := preload("res://scripts/autoload/update_service.gd")
const TIME_LIMIT := 600.0
const EXES := {"GunFare-windows.zip": "GunFare.exe", "GunFare-macos.zip": "GunFare.app", "GunFare-linux.zip": "GunFare.x86_64"}

var _failed := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 and not args[0].begins_with("--") else "latest"
	var asset := args[1] if args.size() > 1 and not args[1].begins_with("--") else "GunFare-linux.zip"
	_run(tag, asset, args.has("--compare-api-headers"))


func _run(tag: String, asset: String, compare: bool) -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var url := "https://api.github.com/repos/%s/releases/%s" % [Updater.REPO, "latest" if tag == "latest" else "tags/" + tag]
	var check := HTTPRequest.new()
	check.timeout = 30.0
	add_child(check)
	var err := check.request(url, Updater.api_headers(version))
	_expect(err == OK, "the release request starts (%s)" % error_string(err))
	var res: Array = await check.request_completed
	_expect(res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200, "the release request returns HTTP 200 (result %d, HTTP %d)" % [res[0], res[1]])
	var release = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(release) != TYPE_DICTIONARY:
		_finish("the release JSON is not readable")
		return
	var info := Updater.pick_asset(release, asset)
	_expect(not info.is_empty(), "release %s has the asset %s" % [str(release.get("tag_name", "?")), asset])
	if info.is_empty():
		_finish("")
		return
	print("Package: %s, %d bytes, digest %s" % [info["url"], info["size"], "yes" if info["digest"] != "" else "no"])
	if compare:
		# Diagnosis only: the headers of the version check, as the first releases sent them.
		await _download(info, asset, Updater.api_headers(version), "API headers", false)
	await _download(info, asset, Updater.download_headers(version), "download headers", true)
	_finish("")


func _download(info: Dictionary, asset: String, headers: PackedStringArray, label: String, required: bool) -> void:
	var dir := ProjectSettings.globalize_path("user://test_update_download")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(asset + ".part")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var http := Updater.new_download_request()
	add_child(http)
	http.download_file = path
	var start := Time.get_ticks_msec()
	var err := http.request(info["url"], headers)
	if err != OK:
		_report(required, "%s: the download starts (%s)" % [label, error_string(err)])
		return
	var res: Array = await http.request_completed
	var seconds := (Time.get_ticks_msec() - start) / 1000.0
	var got := FileAccess.open(path, FileAccess.READ).get_length() if FileAccess.file_exists(path) else 0
	print("%s: result %d, HTTP %d, %d bytes in %.1f s" % [label, res[0], res[1], got, seconds])
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		_report(required, "%s: the download succeeds (result %d, HTTP %d)" % [label, res[0], res[1]])
	else:
		var problem := Updater.verify_package(path, info["size"], info["digest"], str(EXES.get(asset, "")))
		if problem != "":
			_report(required, "%s: the package passes the checks (%s)" % [label, problem])
		else:
			print("%s: the package passes the size, digest and contents checks" % label)
	http.queue_free()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _report(required: bool, what: String) -> void:
	if required:
		_expect(false, what)
	else:
		print("DIAGNOSIS: failed: ", what)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		printerr("UPDATE DOWNLOAD CHECK FAILED: ", what)
		_failed += 1


func _finish(reason: String) -> void:
	if reason != "":
		_expect(false, reason)
	print("update download checks: %d failed" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 > TIME_LIMIT:
		_finish("the test did not finish in %d seconds" % int(TIME_LIMIT))

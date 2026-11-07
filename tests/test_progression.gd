extends Node
## Headless progression tests. Run from the project folder:
##   Godot_console.exe --headless --path . res://tests/test_progression.tscn

const TEST_SAVE := "user://test_profile.json"

var _failures: Array[String] = []
var _checks := 0
var _last_unlocks: Array = []


func _ready() -> void:
	Progression.save_path = TEST_SAVE
	Progression.ranked_up.connect(func(_r: int, unlocks: Array) -> void: _last_unlocks = unlocks)
	_run(_test_rank_table)
	_run(_test_kill_xp)
	_run(_test_rank_up_unlocks)
	_run(_test_attachment_unlock)
	_run(_test_camo_unlock)
	_run(_test_elite_perk)
	_run(_test_loadout_validation)
	_run(_test_streak_selection)
	_run(_test_prestige)
	_run(_test_save_load)
	_run(_test_update_version)
	_run(_test_update_release_parse)
	_run(_test_update_block_reasons)
	_run(_test_update_package_check)
	_run(_test_update_scripts_embedded)
	_run(_test_safe_file)
	SafeFile.remove(TEST_SAVE)
	print("%d checks, %d failures" % [_checks, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run(test: Callable) -> void:
	Progression.reset_profile()
	_last_unlocks = []
	test.call()


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)
		printerr("FAIL: ", msg)


func kill(weapon: String, headshot := false, perks: Array = [], extra: Dictionary = {}) -> void:
	var info := {"weapon": weapon, "headshot": headshot, "perks": perks, "attachment_count": 0, "distance": 20.0}
	info.merge(extra, true)
	GameEvents.report("kill", info)


func _test_update_version() -> void:
	check(UpdateService.is_newer("0.2.0", "0.1.0"), "0.2.0 is newer than 0.1.0")
	check(not UpdateService.is_newer("0.1.0", "0.1.0"), "the same version is not newer")
	check(not UpdateService.is_newer("0.1.0", "0.2.0"), "an older version is not newer")
	check(UpdateService.is_newer("v1.0.0", "0.9.9"), "a v prefix is accepted")
	check(not UpdateService.is_newer("1.2.0", "1.2"), "1.2.0 matches 1.2")
	check(UpdateService.is_newer("1.2.1", "1.2"), "1.2.1 is newer than 1.2")
	check(UpdateService.is_newer("0.1.0.10", "0.1.0.9"), "a run number compares as a number")
	check(not UpdateService.is_newer("", "0.1.0"), "an empty tag is not newer")
	check(not UpdateService.is_newer("garbage", "0.1.0"), "a tag that is not a version is not newer")


func _release(tag: String, assets: Array) -> Dictionary:
	return {"tag_name": tag, "draft": false, "prerelease": false, "assets": assets}


func _asset(name: String, url: String) -> Dictionary:
	return {"name": name, "browser_download_url": url, "size": 1234, "digest": "sha256:ABCDEF"}


func _test_update_release_parse() -> void:
	var url := "https://github.com/Baker-Harrison/GunFlare/releases/download/v0.1.0.5/GunFare-windows.zip"
	var info := UpdateService.pick_asset(_release("v0.1.0.5", [_asset("GunFare-windows.zip", url)]), "GunFare-windows.zip")
	check(info.get("version") == "0.1.0.5", "the release version has no v prefix")
	check(info.get("size") == 1234, "the asset size is read")
	check(info.get("digest") == "abcdef", "the sha256 digest is read in lower case")
	var bad := _asset("GunFare-windows.zip", "https://example.com/GunFare-windows.zip")
	check(UpdateService.pick_asset(_release("v0.1.0.5", [bad]), "GunFare-windows.zip").is_empty(), "an asset from another host is refused")
	var draft := _release("v0.1.0.5", [_asset("GunFare-windows.zip", url)])
	draft["prerelease"] = true
	check(UpdateService.pick_asset(draft, "GunFare-windows.zip").is_empty(), "a prerelease is ignored")
	check(UpdateService.pick_asset({"tag_name": "v1", "assets": "x"}, "GunFare-windows.zip").is_empty(), "bad assets data is ignored")
	check(UpdateService.pick_asset(_release("v0.1.0.5", []), "GunFare-windows.zip").is_empty(), "a release without the package is ignored")
	# A newer release changes the state at once, without a restart.
	var before := UpdateService.current_version
	UpdateService.current_version = "0.1.0.4"
	var asset_name: String = str(UpdateService._package()["asset"])
	var live := _asset(asset_name, url)
	var emitted := [0]
	var counter := func() -> void: emitted[0] += 1
	UpdateService.state_changed.connect(counter)
	UpdateService.apply_release(_release("v0.1.0.5", [live]))
	check(UpdateService.status == "available", "a newer release makes the update available")
	check(UpdateService.message.begins_with("Version 0.1.0.5 is available."), "the message names the new version")
	UpdateService.apply_release(_release("v0.1.0.5", [live]))
	check(emitted[0] == 1, "the same release does not emit the signal again")
	UpdateService.apply_release(_release("v0.1.0.6", [live]))
	check(UpdateService.remote_version == "0.1.0.6" and emitted[0] == 2, "a later release replaces the earlier one")
	UpdateService.current_version = "0.1.0.6"
	UpdateService.apply_release(_release("v0.1.0.6", [live]))
	check(UpdateService.status == "idle", "the current release clears the banner")
	UpdateService.state_changed.disconnect(counter)
	UpdateService.current_version = before
	UpdateService.remote_version = ""
	UpdateService.message = ""


func _test_update_block_reasons() -> void:
	var win_temp := PackedStringArray(["C:\\Users\\p\\AppData\\Local\\Temp"])
	check(UpdateService.is_temporary_dir("C:\\Users\\p\\AppData\\Local\\Temp\\01b0_GunFare-windows.zip.GunFare-windows.zip", "Windows", win_temp), "a copy that runs from a zip installs elsewhere")
	check(UpdateService.is_temporary_dir("D:/Games/GunFare-windows.zip", "Windows", PackedStringArray()), "a .zip folder is temporary")
	check(not UpdateService.is_temporary_dir("D:\\Games\\GunFare", "Windows", win_temp), "a normal folder keeps the update")
	check(UpdateService.is_temporary_dir("/private/var/folders/x/T/AppTranslocation/ABC/d", "macOS", PackedStringArray()), "a translocated app installs elsewhere")
	check(not UpdateService.is_temporary_dir("/Users/p/Applications", "macOS", PackedStringArray(["/var/folders/x/T/"])), "the Applications folder keeps the update")
	check(not UpdateService.is_temporary_dir("/home/p/games/GunFare", "Linux", PackedStringArray(["/tmp"])), "a Linux game folder keeps the update")
	# The folder from the bug report, with a short 8.3 name in TEMP.
	var report := "C:/Users/thehe/AppData/Local/Temp/01b09247-37b6-43f1-8aa9-af9cbb98b7b8_GunFare-windows.zip.GunFare-windows.zip"
	check(UpdateService.is_temporary_dir(report, "Windows", PackedStringArray(["C:\\Users\\THEHE~1\\AppData\\Local\\Temp"])), "the folder from the bug report is temporary")
	check(UpdateService.is_temporary_dir("C:\\Users\\p\\AppData\\Local\\Temp\\Temp1_GunFare-windows.zip", "Windows", PackedStringArray()), "an old Explorer Temp1 folder is temporary")
	check(UpdateService.is_temporary_dir("/tmp/GunFare", "Linux", PackedStringArray()), "/tmp is temporary on Linux")
	check(UpdateService.app_bundle_path("/Applications/GunFare.app/Contents/MacOS/GunFare") == "/Applications/GunFare.app", "the app bundle path is found")
	check(UpdateService.app_bundle_path("/opt/GunFare/GunFare.x86_64") == "", "a Linux path has no app bundle")
	check(UpdateService.friendly_error("FAIL The process cannot access the file 'x' because it is being used by another process.").contains("Close all GunFare windows"), "a locked file gives clear help")
	check(UpdateService.friendly_error(char(0xFEFF) + "FAIL Access to the path is denied.").contains("folder that you own"), "a denied write gives clear help")


func _test_update_package_check() -> void:
	var path := ProjectSettings.globalize_path("user://test_package.zip")
	var packer := ZIPPacker.new()
	check(packer.open(path) == OK, "the test zip opens")
	packer.start_file("GunFare.exe")
	packer.write_file("game".to_utf8_buffer())
	packer.close_file()
	packer.close()
	var size := FileAccess.open(path, FileAccess.READ).get_length()
	var sha := FileAccess.get_sha256(path)
	check(UpdateService.verify_package(path, size, sha, "GunFare.exe") == "", "a good package passes")
	check(UpdateService.verify_package(path, size + 1, sha, "GunFare.exe").contains("not complete"), "a short download fails")
	check(UpdateService.verify_package(path, size, "00" + sha.substr(2), "GunFare.exe").contains("damaged"), "a wrong checksum fails")
	check(UpdateService.verify_package(path, -1, "", "GunFare.x86_64").contains("does not contain"), "a package without the executable fails")
	var junk := FileAccess.open(path, FileAccess.WRITE)
	junk.store_string("not a zip")
	junk.close()
	check(UpdateService.verify_package(path, -1, "", "GunFare.exe").contains("not a valid zip"), "a file that is not a zip fails")
	DirAccess.remove_absolute(path)


func _test_update_scripts_embedded() -> void:
	for pair in [["res://tools/apply_update.ps1", UpdateService.WINDOWS_SCRIPT], ["res://tools/apply_update.sh", UpdateService.UNIX_SCRIPT]]:
		var text := FileAccess.get_file_as_string(pair[0]).replace("\r\n", "\n").strip_edges()
		check(text != "" and text == str(pair[1]).strip_edges(), "the game embeds the same text as " + pair[0])


func _test_safe_file() -> void:
	var path := "user://test_safe.json"
	SafeFile.remove(path)
	check(SafeFile.write_text(path, "{\"a\": 1}") == OK, "the first safe write works")
	check(SafeFile.write_text(path, "{\"a\": 2}") == OK, "the second safe write works")
	check(SafeFile.read_text(path, SafeFile.is_json_object) == "{\"a\": 2}", "the read gives the last text")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("{\"a\": ")
	broken.close()
	check(SafeFile.read_text(path, SafeFile.is_json_object) == "{\"a\": 1}", "a damaged file falls back to the backup")
	SafeFile.remove(path)
	check(SafeFile.read_text(path, SafeFile.is_json_object) == "", "no file gives an empty text")
	# A damaged profile must not delete the progress.
	Progression.xp = 5000
	check(Progression.save_profile(), "the profile saves")
	Progression.xp = 6000
	check(Progression.save_profile(), "the profile saves again")
	var cut := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	cut.store_string("{")
	cut.close()
	Progression.load_profile()
	check(Progression.xp == 5000, "a damaged profile loads the backup")
	SafeFile.remove(TEST_SAVE)


func _test_rank_table() -> void:
	check(ContentDB.rank_min_xp.size() == 70, "70 ranks")
	for i in range(1, 70):
		check(ContentDB.rank_min_xp[i] > ContentDB.rank_min_xp[i - 1], "rank xp increases at %d" % i)
	check(ContentDB.max_xp > 2_400_000 and ContentDB.max_xp < 2_800_000, "total xp ~2.5M (got %d)" % ContentDB.max_xp)
	check(ContentDB.rank_for_xp(0) == 1, "0 xp is rank 1")
	check(ContentDB.rank_for_xp(ContentDB.max_xp) == 70, "max xp is rank 70")
	check(ContentDB.rank_name(1) == "Recruit I", "rank 1 name")
	check(ContentDB.rank_name(70) == "Legend V", "rank 70 name")


func _test_kill_xp() -> void:
	kill("m4a1", true)
	check(Progression.xp == 150, "headshot kill = 150 xp (got %d)" % Progression.xp)
	check(Progression.stats["kills"] == 1 and Progression.stats["headshots"] == 1, "kill stats")


func _test_rank_up_unlocks() -> void:
	check(Progression.custom_class_slots() == 0, "no custom classes at rank 1")
	Progression.award_xp(ContentDB.rank_min_xp[3], "test")
	check(Progression.rank == 4, "rank 4")
	var ids := _last_unlocks.map(func(i: UnlockableData) -> String: return i.id)
	check(ids.has("create_a_class"), "create-a-class unlocks at 4")
	check(ids.has("tireless"), "tireless unlocks at 4")
	check(Progression.custom_class_slots() == 5, "5 custom classes at rank 4")


func _test_attachment_unlock() -> void:
	for i in 9:
		kill("m4a1")
	check(not Progression.is_attachment_unlocked("m4a1", "reflex"), "reflex locked at 9 kills")
	kill("m4a1")
	check(Progression.is_attachment_unlocked("m4a1", "reflex"), "reflex unlocked at 10 kills")
	check(Progression.xp == 1000 + 300, "10 kills + tier xp (got %d)" % Progression.xp)
	check(not Progression.is_attachment_unlocked("mp5", "reflex"), "unlock is per weapon")


func _test_camo_unlock() -> void:
	for i in 10:
		kill("m4a1", true)
	check(Progression.is_camo_unlocked("m4a1", "camo_woodland"), "camo at 10 headshots")


func _test_elite_perk() -> void:
	for i in 119:
		kill("mp5", false, ["quickhands", "heavy_rounds", "steady_hand"])
	check(not Progression.has_elite("quickhands"), "quickhands not elite at 119")
	kill("mp5", false, ["quickhands"])
	check(Progression.has_elite("quickhands"), "quickhands elite at 120")
	for i in 20:
		kill("mp5", false, ["packmule"], {"attachment_count": 1})
	check(Progression.challenge_state("packmule_elite")["count"] == 0, "packmule needs 2 attachments")


func _test_loadout_validation() -> void:
	var l: Dictionary = ContentDB.DEFAULT_CUSTOM_CLASS.duplicate(true)
	check(Progression.validate_loadout(l).is_empty(), "default class valid: %s" % [Progression.validate_loadout(l)])
	l["primary"] = "ak47"
	check(not Progression.validate_loadout(l).is_empty(), "rank-70 weapon locked")
	l["primary"] = "m4a1"
	l["primary_attachments"] = ["reflex"]
	check(not Progression.validate_loadout(l).is_empty(), "locked attachment rejected")
	Progression.grant_reward({"type": "attachment", "weapon": "m4a1", "id": "reflex"})
	Progression.grant_reward({"type": "attachment", "weapon": "m4a1", "id": "holo"})
	check(Progression.validate_loadout(l).is_empty(), "unlocked attachment ok")
	l["primary_attachments"] = ["reflex", "holo"]
	check(not Progression.validate_loadout(l).is_empty(), "two attachments need packmule")
	Progression.award_xp(ContentDB.rank_min_xp[20], "test")
	l["perks"] = ["packmule", "heavy_rounds", "steady_hand"]
	var errs := Progression.validate_loadout(l)
	check(errs.size() == 1 and errs[0].contains("optic"), "packmule allows 2, but not 2 optics: %s" % [errs])
	l["perks"] = ["heavy_rounds", "quickhands", "steady_hand"]
	check(not Progression.validate_loadout(l).is_empty(), "perk in wrong slot rejected")


func _test_streak_selection() -> void:
	check(Progression.set_streaks(["pulse_scan", "supply_crate", "mortar_strike"]), "default streaks ok")
	check(not Progression.set_streaks(["pulse_scan", "supply_crate", "doomsday"]), "locked streak rejected")
	check(not Progression.set_streaks(["pulse_scan", "pulse_scan", "mortar_strike"]), "duplicates rejected")


func _test_prestige() -> void:
	Progression.grant_reward({"type": "title", "id": "Test Title"})
	for i in 10:
		kill("m4a1")
	check(not Progression.can_prestige(), "can't ascend early")
	check(not Progression.prestige_up(), "ascend refused early")
	Progression.award_xp(ContentDB.max_xp, "test")
	check(Progression.rank == 70 and Progression.can_prestige(), "can ascend at max")
	check(Progression.prestige_up(), "ascend")
	check(Progression.prestige == 1 and Progression.rank == 1 and Progression.xp == 0, "rank reset")
	check(not Progression.is_attachment_unlocked("m4a1", "reflex"), "attachments reset")
	check(Progression.titles.has("Test Title"), "titles kept")
	check(Progression.challenge_state("lifetime_kills")["count"] == 10, "lifetime progress kept")
	check(Progression.challenge_state("m4a1_marksman")["count"] == 0, "weapon challenge reset")
	check(Progression.classes.size() == 6, "extra class slot after ascension")


func _test_save_load() -> void:
	for i in 25:
		kill("m4a1", true)
	Progression.grant_reward({"type": "emblem", "id": "emblem_test"})
	var xp_before := Progression.xp
	check(Progression.save_profile(), "save ok")
	Progression.reset_profile()
	Progression.load_profile()
	check(Progression.xp == xp_before, "xp restored")
	check(Progression.is_attachment_unlocked("m4a1", "suppressor"), "attachments restored")
	check(Progression.is_camo_unlocked("m4a1", "camo_dune"), "camos restored")
	check(Progression.emblems.has("emblem_test"), "emblems restored")
	check(Progression.challenge_state("m4a1_marksman")["count"] == 25, "challenge progress restored")
	check(typeof(Progression.challenge_state("m4a1_marksman")["count"]) == TYPE_INT, "counts are ints")

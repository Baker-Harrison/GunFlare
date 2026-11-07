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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
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

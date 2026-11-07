extends Node
## The player's profile: XP, rank, Ascension (prestige), challenge-earned
## unlocks, custom classes, streak selection and lifetime stats.
## Saved as JSON at save_path.
##
## Rank-based unlocks are not stored: they are worked out from rank.
## Only challenge rewards (attachments, camos, Elite perks, titles, emblems)
## are saved.

signal xp_gained(amount: int, reason: String)
signal ranked_up(new_rank: int, unlocks: Array)
signal reward_granted(reward: Dictionary)
signal prestiged(new_level: int)

const SAVE_VERSION := 1

var save_path := "user://profile.json"

var xp := 0
var prestige := 0
var weapon_unlocks: Dictionary = {} # weapon id -> {"attachments": [ids], "camos": [ids]}
var elite_perks: Array = []
var titles: Array = [] # kept through Ascension
var emblems: Array = [] # kept through Ascension
var challenge_progress: Dictionary = {} # challenge id -> {"count": int, "tier": int}
var stats: Dictionary = {}
var classes: Array = [] # custom class loadouts
var selected_streaks: Array = []

var rank: int:
	get:
		return ContentDB.rank_for_xp(xp)


func _ready() -> void:
	GameEvents.reported.connect(_on_event)
	load_profile()


# --- XP and rank -------------------------------------------------------------

func award_xp(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	var old_rank := rank
	xp = mini(xp + amount, ContentDB.max_xp)
	xp_gained.emit(amount, reason)
	var new_rank := rank
	if new_rank > old_rank:
		var unlocks: Array = []
		for r in range(old_rank + 1, new_rank + 1):
			unlocks.append_array(ContentDB.unlocks_at_rank(r))
		ranked_up.emit(new_rank, unlocks)


func _on_event(event_name: String, info: Dictionary) -> void:
	match event_name:
		"kill":
			_add_stat("kills")
			var amount: int = ContentDB.XP["kill"]
			if info.get("headshot", false):
				_add_stat("headshots")
				amount += ContentDB.XP["headshot"]
			award_xp(amount, "kill")
		"assist":
			_add_stat("assists")
			award_xp(ContentDB.XP["assist"], "assist")
		"death":
			_add_stat("deaths")
		"bonus":
			var bonus = ContentDB.BONUSES.get(info.get("bonus", ""))
			if bonus != null:
				award_xp(bonus[1], bonus[0])
		"match_end":
			var won: bool = info.get("won", false)
			_add_stat("matches")
			_add_stat("wins" if won else "losses")
			var base: int = ContentDB.XP["match_win"] if won else ContentDB.XP["match_loss"]
			var minutes := float(info.get("minutes", 0.0))
			award_xp(base + int(minutes * ContentDB.XP["match_per_minute"]), "match")
			save_profile()


func _add_stat(key: String, amount := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


# --- Rewards and unlock queries ----------------------------------------------

func grant_reward(reward: Dictionary) -> void:
	var id: String = reward.get("id", "")
	match reward.get("type", ""):
		"attachment":
			_add_unique(_weapon_entry(reward["weapon"])["attachments"], id)
		"camo":
			_add_unique(_weapon_entry(reward["weapon"])["camos"], id)
		"elite":
			_add_unique(elite_perks, id)
		"title":
			_add_unique(titles, id)
		"emblem":
			_add_unique(emblems, id)
		_:
			push_warning("Unknown reward type: %s" % reward)
			return
	reward_granted.emit(reward)


func is_unlocked(id: String) -> bool:
	var item := ContentDB.get_item(id)
	return item != null and item.unlock_rank > 0 and item.unlock_rank <= rank


func is_attachment_unlocked(weapon_id: String, attachment_id: String) -> bool:
	return weapon_unlocks.get(weapon_id, {}).get("attachments", []).has(attachment_id)


func is_camo_unlocked(weapon_id: String, camo_id: String) -> bool:
	return weapon_unlocks.get(weapon_id, {}).get("camos", []).has(camo_id)


func has_elite(perk_id: String) -> bool:
	return elite_perks.has(perk_id)


func challenge_state(id: String) -> Dictionary:
	if not challenge_progress.has(id):
		challenge_progress[id] = {"count": 0, "tier": 0}
	return challenge_progress[id]


func _weapon_entry(weapon_id: String) -> Dictionary:
	if not weapon_unlocks.has(weapon_id):
		weapon_unlocks[weapon_id] = {"attachments": [], "camos": []}
	return weapon_unlocks[weapon_id]


static func _add_unique(arr: Array, value) -> void:
	if not arr.has(value):
		arr.append(value)


# --- Classes and streak selection --------------------------------------------

## 0 until Create-a-Class unlocks, then 5, plus one per early Ascension.
func custom_class_slots() -> int:
	if not is_unlocked("create_a_class"):
		return 0
	return _class_slot_count()


func _class_slot_count() -> int:
	return ContentDB.BASE_CLASS_SLOTS + mini(prestige, ContentDB.PRESTIGE_BONUS_CLASS_SLOTS)


func _default_custom_classes() -> Array:
	var out: Array = []
	for i in _class_slot_count():
		var c: Dictionary = ContentDB.DEFAULT_CUSTOM_CLASS.duplicate(true)
		c["name"] = "Custom Class %d" % (i + 1)
		out.append(c)
	return out


## Returns a list of problems; empty means the loadout is legal for this profile.
func validate_loadout(loadout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var perks: Array = loadout.get("perks", [])

	if perks.size() != 3:
		errors.append("A class needs exactly 3 perks.")
	for i in perks.size():
		var perk := ContentDB.get_item(perks[i]) as PerkData
		if perk == null:
			errors.append("Unknown perk: %s" % perks[i])
		elif perk.slot != i + 1:
			errors.append("%s belongs in perk slot %d." % [perk.display_name, perk.slot])
		elif not is_unlocked(perk.id):
			errors.append("%s unlocks at rank %d." % [perk.display_name, perk.unlock_rank])

	var has_packmule := perks.has("packmule")
	var primary_ok := _validate_weapon(loadout.get("primary", ""), "primary", false, errors)
	if primary_ok:
		_validate_attachments(loadout["primary"], loadout.get("primary_attachments", []),
			2 if has_packmule else 1, errors)
		var camo: String = loadout.get("primary_camo", "")
		if camo != "" and not is_camo_unlocked(loadout["primary"], camo):
			errors.append("Camo %s is locked for this weapon." % camo)

	var secondary_ok := _validate_weapon(loadout.get("secondary", ""), "secondary",
		perks.has("second_holster"), errors)
	if secondary_ok:
		_validate_attachments(loadout["secondary"], loadout.get("secondary_attachments", []),
			2 if has_packmule and has_elite("packmule") else 1, errors)

	for slot_kind in ["lethal", "tactical", "deathstreak"]:
		var id: String = loadout.get(slot_kind, "")
		var item := ContentDB.get_item(id)
		if item == null or item.kind != slot_kind:
			errors.append("Invalid %s: %s" % [slot_kind, id])
		elif not is_unlocked(id):
			errors.append("%s unlocks at rank %d." % [item.display_name, item.unlock_rank])
	return errors


func _validate_weapon(id: String, slot: String, allow_primary: bool, errors: Array[String]) -> bool:
	var w := ContentDB.get_item(id) as WeaponData
	if w == null:
		errors.append("Unknown %s weapon: %s" % [slot, id])
		return false
	if w.slot != slot and not (allow_primary and w.slot == "primary"):
		errors.append("%s can't go in the %s slot." % [w.display_name, slot])
		return false
	if not is_unlocked(id):
		errors.append("%s unlocks at rank %d." % [w.display_name, w.unlock_rank])
		return false
	return true


func _validate_attachments(weapon_id: String, attachments: Array, max_count: int, errors: Array[String]) -> void:
	if attachments.size() > max_count:
		errors.append("Too many attachments on %s (max %d)." % [weapon_id, max_count])
	var optics := 0
	for att in attachments:
		if not is_attachment_unlocked(weapon_id, att):
			errors.append("Attachment %s is locked on %s." % [att, weapon_id])
		if ContentDB.OPTICS.has(att):
			optics += 1
	if optics > 1:
		errors.append("Only one optic per weapon.")


## Pick three distinct, unlocked streak rewards.
func set_streaks(ids: Array) -> bool:
	if ids.size() != 3:
		return false
	var seen := {}
	for id in ids:
		var s := ContentDB.get_item(id)
		if s == null or s.kind != "killstreak" or not is_unlocked(id) or seen.has(id):
			return false
		seen[id] = true
	selected_streaks = ids.duplicate()
	return true


# --- Ascension (prestige) ----------------------------------------------------

func can_prestige() -> bool:
	return xp >= ContentDB.max_xp and prestige < ContentDB.MAX_PRESTIGE


## Resets rank, unlocks, classes and non-lifetime challenges.
## Keeps titles, emblems, lifetime challenges and stats.
func prestige_up() -> bool:
	if not can_prestige():
		return false
	prestige += 1
	xp = 0
	weapon_unlocks = {}
	elite_perks = []
	for id: String in challenge_progress.keys():
		var c := ContentDB.get_challenge(id)
		if c == null or not c.lifetime:
			challenge_progress.erase(id)
	classes = _default_custom_classes()
	selected_streaks = ContentDB.DEFAULT_STREAKS.duplicate()
	prestiged.emit(prestige)
	save_profile()
	return true


# --- Save / load -------------------------------------------------------------

func reset_profile() -> void:
	xp = 0
	prestige = 0
	weapon_unlocks = {}
	elite_perks = []
	titles = []
	emblems = []
	challenge_progress = {}
	stats = {"kills": 0, "deaths": 0, "assists": 0, "headshots": 0, "wins": 0, "losses": 0, "matches": 0}
	classes = _default_custom_classes()
	selected_streaks = ContentDB.DEFAULT_STREAKS.duplicate()


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"xp": xp,
		"prestige": prestige,
		"weapon_unlocks": weapon_unlocks,
		"elite_perks": elite_perks,
		"titles": titles,
		"emblems": emblems,
		"challenge_progress": challenge_progress,
		"stats": stats,
		"classes": classes,
		"selected_streaks": selected_streaks,
	}


func save_profile() -> bool:
	var err := SafeFile.write_text(save_path, JSON.stringify(to_dict(), "\t"))
	if err != OK:
		push_error("Could not save profile to %s: %s" % [save_path, error_string(err)])
		return false
	return true


func load_profile() -> void:
	reset_profile()
	var text := SafeFile.read_text(save_path, SafeFile.is_json_object)
	if text == "":
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Profile at %s is unreadable; starting fresh." % save_path)
		return

	# JSON numbers come back as floats, so convert them back to ints.
	prestige = clampi(int(data.get("prestige", 0)), 0, ContentDB.MAX_PRESTIGE)
	xp = clampi(int(data.get("xp", 0)), 0, ContentDB.max_xp)
	weapon_unlocks = data.get("weapon_unlocks", {})
	elite_perks = data.get("elite_perks", [])
	titles = data.get("titles", [])
	emblems = data.get("emblems", [])
	var saved_progress: Dictionary = data.get("challenge_progress", {})
	for id: String in saved_progress:
		var p: Dictionary = saved_progress[id]
		challenge_progress[id] = {"count": int(p.get("count", 0)), "tier": int(p.get("tier", 0))}
	var saved_stats: Dictionary = data.get("stats", {})
	for key: String in saved_stats:
		stats[key] = int(saved_stats[key])
	var saved_classes: Array = data.get("classes", [])
	classes = _default_custom_classes()
	for i in mini(saved_classes.size(), classes.size()):
		classes[i] = saved_classes[i]
	var saved_streaks: Array = data.get("selected_streaks", [])
	if saved_streaks.size() == 3:
		selected_streaks = saved_streaks

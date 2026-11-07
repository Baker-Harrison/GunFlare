extends Node
## All progression content: ranks, weapons, attachments, camos, equipment,
## perks, streak rewards, challenges and XP values. Rename or retune here;
## game code refers to things only by id.

const MAX_RANK := 70
const MAX_PRESTIGE := 10
const BASE_CLASS_SLOTS := 5
## One extra custom class slot at each of the first N Ascensions.
const PRESTIGE_BONUS_CLASS_SLOTS := 2

## Player-facing names for the systems themselves.
const TERMS := {
	"prestige": "Ascension",
	"elite": "Elite",
	"killstreak": "Streak Reward",
	"deathstreak": "Setback Perk",
	"title": "Title",
	"emblem": "Emblem",
}

const XP := {
	"kill": 100,
	"headshot": 50, # on top of the kill
	"assist": 20,
	"match_win": 500,
	"match_loss": 200,
	"match_per_minute": 30,
}

## Bonus XP for special plays. id: [display name, xp]
const BONUSES := {
	"first_blood": ["First Blood", 100],
	"double_kill": ["Double Kill", 50],
	"triple_kill": ["Triple Kill", 75],
	"multi_kill": ["Rampage", 100],
	"payback": ["Payback", 50], # kill the enemy who last killed you
	"avenger": ["Avenger", 50], # kill the enemy who just killed a teammate
	"spoiler": ["Spoiler", 100], # end an enemy's streak of 5+
	"long_shot": ["Long Shot", 50],
	"point_blank": ["Point Blank", 50],
	"comeback": ["Rebound", 100], # kill after dying 4+ times in a row
	"posthumous": ["From the Grave", 25], # kill after you died
	"rescuer": ["Guardian", 50], # kill an enemy shooting a teammate
}

const RANK_TITLES := [
	"Recruit", "Rookie", "Grunt", "Trooper", "Operator", "Specialist", "Sergeant",
	"Vanguard", "Lieutenant", "Captain", "Major", "Warden", "Commander", "Legend",
]
const RANK_SUBLEVELS := ["I", "II", "III", "IV", "V"]

## Rank-1 items used by fresh custom classes.
const DEFAULT_STREAKS := ["pulse_scan", "supply_crate", "mortar_strike"]
const DEFAULT_CUSTOM_CLASS := {
	"name": "Custom Class",
	"primary": "kestrel_ar",
	"primary_attachments": [],
	"primary_camo": "",
	"secondary": "pip",
	"secondary_attachments": [],
	"lethal": "shard_grenade",
	"tactical": "flash_pop",
	"perks": ["quickhands", "heavy_rounds", "steady_hand"],
	"deathstreak": "second_wind",
}

## Preset classes usable at any rank (not validated against unlocks).
const PRESET_CLASSES := [
	{"name": "Rifleman", "primary": "kestrel_ar", "primary_attachments": ["underbarrel_gl"], "primary_camo": "",
		"secondary": "pip", "secondary_attachments": [], "lethal": "shard_grenade", "tactical": "flash_pop",
		"perks": ["quickhands", "heavy_rounds", "steady_hand"], "deathstreak": "second_wind"},
	{"name": "Close Quarters", "primary": "wasp", "primary_attachments": ["suppressor"], "primary_camo": "",
		"secondary": "thumper", "secondary_attachments": [], "lethal": "shard_grenade", "tactical": "dazer",
		"perks": ["tireless", "fleetfoot", "hush"], "deathstreak": "second_wind"},
	{"name": "Overwatch", "primary": "heron", "primary_attachments": ["suppressor"], "primary_camo": "",
		"secondary": "pip", "secondary_attachments": [], "lethal": "tripwire_mine", "tactical": "smoke_canister",
		"perks": ["scrounger", "ghostline", "steady_hand"], "deathstreak": "second_wind"},
	{"name": "Heavy", "primary": "anvil", "primary_attachments": ["grip"], "primary_camo": "",
		"secondary": "thudder", "secondary_attachments": [], "lethal": "sticky_charge", "tactical": "flash_pop",
		"perks": ["scrounger", "heavy_rounds", "steady_hand"], "deathstreak": "second_wind"},
	{"name": "Recon", "primary": "mako_5", "primary_attachments": ["holo"], "primary_camo": "",
		"secondary": "hornet", "secondary_attachments": [], "lethal": "hatchet", "tactical": "dazer",
		"perks": ["quickhands", "fleetfoot", "keen_eye"], "deathstreak": "second_wind"},
]

## id: [display name, description]
const ATTACHMENTS := {
	"reflex": ["Reflex Sight", "Red-dot optic for fast target pickup."],
	"holo": ["Holo Sight", "Wide holographic optic."],
	"marksman_scope": ["Marksman Scope", "Mid-range magnified optic."],
	"thermal": ["Thermal Optic", "Shows targets as heat signatures."],
	"suppressor": ["Suppressor", "Hides you from the minimap when firing."],
	"underbarrel_gl": ["Underbarrel Launcher", "Single-shot grenade launcher."],
	"underbarrel_shotgun": ["Underbarrel Shotgun", "Close-range backup blast."],
	"fmj": ["Piercing Rounds", "Better penetration through cover."],
	"pulse_tracker": ["Pulse Tracker", "Shows nearby enemies on a wrist screen."],
	"ext_mag": ["Extended Mag", "More rounds per magazine."],
	"rapid_fire": ["Hair Trigger", "Higher fire rate."],
	"grip": ["Foregrip", "Less recoil."],
	"akimbo": ["Dual Wield", "One in each hand."],
	"tactical_knife": ["Knife Grip", "Faster melee."],
}
const OPTICS := ["reflex", "holo", "marksman_scope", "thermal"]

## weapon class -> {attachment id: kills needed}
const ATTACHMENT_TRACKS := {
	"assault": {"reflex": 10, "suppressor": 25, "underbarrel_gl": 40, "marksman_scope": 60, "fmj": 80,
		"underbarrel_shotgun": 100, "holo": 125, "pulse_tracker": 150, "thermal": 200, "ext_mag": 250},
	"smg": {"rapid_fire": 10, "reflex": 25, "suppressor": 40, "marksman_scope": 60, "fmj": 80,
		"akimbo": 100, "holo": 125, "thermal": 150, "ext_mag": 200},
	"lmg": {"grip": 10, "reflex": 25, "suppressor": 40, "marksman_scope": 60, "fmj": 80,
		"holo": 100, "pulse_tracker": 125, "thermal": 150, "ext_mag": 200},
	"sniper": {"suppressor": 10, "marksman_scope": 25, "fmj": 40, "thermal": 60, "pulse_tracker": 80, "ext_mag": 100},
	"shotgun": {"reflex": 10, "grip": 20, "suppressor": 30, "fmj": 40, "holo": 50, "akimbo": 75, "ext_mag": 100},
	"pistol": {"fmj": 10, "suppressor": 20, "akimbo": 30, "tactical_knife": 40, "ext_mag": 50},
	"machine_pistol": {"reflex": 10, "suppressor": 20, "fmj": 30, "akimbo": 40, "holo": 50, "ext_mag": 60},
	"launcher": {},
}

## Camos for primary weapons, unlocked by headshots with that weapon. [id, name, headshots]
const CAMO_TRACK := [
	["camo_woodland", "Woodland Drab", 10],
	["camo_dune", "Dune", 25],
	["camo_frostbite", "Frostbite", 50],
	["camo_pixel", "Pixel", 75],
	["camo_slate", "Slate", 100],
	["camo_crimson", "Crimson", 150],
	["camo_ember", "Ember", 200],
	["camo_gilded", "Gilded", 300],
]

## [id, name, class, slot, unlock rank, damage, rpm, magazine, range m]
const WEAPONS := [
	["kestrel_ar", "Kestrel AR", "assault", "primary", 1, 30, 750, 30, 45],
	["mako_5", "Mako-5", "assault", "primary", 4, 28, 800, 30, 40],
	["halberd", "Halberd", "assault", "primary", 10, 40, 500, 20, 55],
	["vex_carbine", "Vex Carbine", "assault", "primary", 28, 30, 700, 30, 45],
	["tempest", "Tempest", "assault", "primary", 40, 26, 900, 30, 35],
	["bastion", "Bastion", "assault", "primary", 58, 35, 650, 30, 50],
	["ironwood", "Ironwood", "assault", "primary", 70, 40, 600, 30, 45],
	["wasp", "Wasp", "smg", "primary", 1, 25, 900, 32, 20],
	["ratchet_45", "Ratchet-45", "smg", "primary", 12, 35, 650, 25, 18],
	["hummingbird", "Hummingbird", "smg", "primary", 22, 22, 1100, 35, 15],
	["viper", "Viper", "smg", "primary", 44, 28, 850, 30, 22],
	["anvil", "Anvil", "lmg", "primary", 1, 32, 650, 100, 50],
	["brute", "Brute", "lmg", "primary", 32, 40, 550, 100, 55],
	["longhaul", "Longhaul", "lmg", "primary", 52, 30, 800, 100, 45],
	["heron", "Heron", "sniper", "primary", 1, 98, 40, 5, 150],
	["spindle", "Spindle", "sniper", "primary", 20, 70, 180, 10, 120],
	["bolt_12", "Bolt-12", "sniper", "primary", 36, 120, 35, 5, 160],
	["lancewood", "Lancewood", "sniper", "primary", 56, 60, 250, 10, 110],
	["pip", "Pip", "pistol", "secondary", 1, 30, 400, 12, 15],
	["hornet", "Hornet", "pistol", "secondary", 14, 35, 380, 15, 18],
	["magnum_six", "Magnum Six", "pistol", "secondary", 34, 60, 150, 6, 20],
	["buzzsaw", "Buzzsaw", "machine_pistol", "secondary", 18, 22, 1000, 20, 12],
	["stinger", "Stinger", "machine_pistol", "secondary", 48, 26, 900, 24, 14],
	["thumper", "Thumper", "shotgun", "secondary", 1, 15, 70, 6, 10],
	["breacher", "Breacher", "shotgun", "secondary", 26, 12, 300, 8, 8],
	["riot_twin", "Riot Twin", "shotgun", "secondary", 46, 20, 150, 2, 12],
	["thudder", "Thudder", "launcher", "secondary", 1, 150, 30, 1, 60],
	["sparrow", "Sparrow", "launcher", "secondary", 30, 150, 30, 1, 100],
]

## [id, name, kind, unlock rank, description]
const EQUIPMENT := [
	["shard_grenade", "Shard Grenade", "lethal", 1, "Cookable fragmentation grenade."],
	["sticky_charge", "Sticky Charge", "lethal", 8, "Sticks to any surface, including people."],
	["spawn_beacon", "Spawn Beacon", "lethal", 11, "Sets your next spawn point."],
	["hatchet", "Hatchet", "lethal", 13, "Thrown one-hit kill. Retrievable."],
	["tripwire_mine", "Tripwire Mine", "lethal", 31, "Proximity mine that guards a doorway."],
	["breach_charge", "Breach Charge", "lethal", 43, "Remote-detonated explosive."],
	["flash_pop", "Flash Pop", "tactical", 1, "Blinds and deafens."],
	["dazer", "Dazer", "tactical", 1, "Slows movement and aim."],
	["smoke_canister", "Smoke Canister", "tactical", 6, "Blocks line of sight."],
]

## [id, name, unlock rank, description]
const FEATURES := [
	["create_a_class", "Create-a-Class", 4, "Build your own custom classes."],
]

## [id, name, slot, rank, description, elite description, elite event, elite conditions, target, challenge text]
const PERKS := [
	["scrounger", "Scrounger", 1, 1, "Resupply ammo from fallen enemies.", "Spawn with extra magazines.",
		"kill", {"perks": "scrounger"}, 100, "Get {target} kills with Scrounger."],
	["quickhands", "Quickhands", 1, 1, "Reload faster.", "Aim down sights faster.",
		"kill", {"perks": "quickhands"}, 120, "Get {target} kills with Quickhands."],
	["tireless", "Tireless", 1, 4, "Unlimited sprint.", "Climb and vault faster.",
		"kill", {"perks": "tireless"}, 150, "Get {target} kills with Tireless."],
	["packmule", "Packmule", 1, 21, "Two attachments on your primary.", "Two attachments on your secondary.",
		"kill", {"perks": "packmule", "attachment_count_min": 2}, 200, "Get {target} kills with a weapon carrying two attachments."],
	["second_holster", "Second Holster", 1, 37, "Carry a primary weapon as your secondary.", "Swap weapons faster.",
		"kill", {"perks": "second_holster"}, 100, "Get {target} kills with Second Holster."],
	["swap_kit", "Swap Kit", 1, 45, "Replaces your secondary. Change class mid-life.", "Change class faster.",
		"kill", {"perks": "swap_kit"}, 120, "Get {target} kills with Swap Kit."],
	["heavy_rounds", "Heavy Rounds", 2, 1, "Increased bullet damage.", "Extra damage to streak rewards.",
		"kill", {"perks": "heavy_rounds"}, 250, "Get {target} kills with Heavy Rounds."],
	["fleetfoot", "Fleetfoot", 2, 3, "Move faster.", "Aim faster after sprinting.",
		"kill", {"perks": "fleetfoot"}, 150, "Get {target} kills with Fleetfoot."],
	["shortcut", "Shortcut", 2, 7, "Streak rewards need one fewer kill.", "Setback perks need one fewer death.",
		"streak_earned", {"perks": "shortcut"}, 40, "Earn {target} streak rewards with Shortcut."],
	["ghostline", "Ghostline", 2, 19, "Invisible to scans, sentries and drones.", "Hidden from thermal optics; no name tag when targeted.",
		"streak_destroyed", {"perks": "ghostline"}, 40, "Destroy {target} enemy streak rewards with Ghostline."],
	["blast_master", "Blast Master", 2, 33, "Increased explosive damage.", "Extra damage to airborne streak rewards.",
		"kill", {"perks": "blast_master", "explosive": true}, 100, "Get {target} explosive kills with Blast Master."],
	["steady_hand", "Steady Hand", 3, 1, "Better hip-fire accuracy.", "Recover aim faster after sprinting.",
		"kill", {"perks": "steady_hand"}, 250, "Get {target} kills with Steady Hand."],
	["hush", "Hush", 3, 5, "Silent footsteps.", "Quieter weapon handling.",
		"kill", {"perks": "hush", "distance_max": 5.0}, 50, "Get {target} close-range kills with Hush."],
	["long_reach", "Long Reach", 3, 15, "Longer melee range.", "No fall damage.",
		"kill", {"perks": "long_reach", "melee": true}, 20, "Get {target} melee kills with Long Reach."],
	["signal_fog", "Signal Fog", 3, 23, "Jams enemy minimaps near you.", "Delays enemy mines.",
		"kill", {"perks": "signal_fog", "distance_max": 10.0}, 50, "Get {target} close-range kills with Signal Fog."],
	["keen_eye", "Keen Eye", 3, 29, "See enemy equipment through walls.", "Enemy footsteps are louder.",
		"equipment_destroyed", {"perks": "keen_eye"}, 50, "Destroy {target} pieces of enemy equipment with Keen Eye."],
	["last_gasp", "Last Gasp", 3, 39, "When downed, fight on with your pistol.", "Use equipment while downed.",
		"kill", {"perks": "last_gasp", "downed": true}, 20, "Get {target} kills while downed."],
]

## [id, name, kind, count, rank, description, ends match]
const STREAKS := [
	["pulse_scan", "Pulse Scan", "killstreak", 3, 1, "Reveals enemies on the minimap.", false],
	["supply_crate", "Supply Crate", "killstreak", 4, 1, "Airdrops a crate with ammo or a random streak reward.", false],
	["mortar_strike", "Mortar Strike", "killstreak", 5, 1, "A mortar shell you steer from above.", false],
	["jammer", "Jammer", "killstreak", 4, 10, "Scrambles the enemy minimap.", false],
	["sentry_post", "Sentry Post", "killstreak", 5, 14, "Deployable automated turret.", false],
	["strafing_run", "Strafing Run", "killstreak", 6, 18, "Jets strafe a line you pick.", false],
	["hunter_drone", "Hunter Drone", "killstreak", 7, 26, "Hovering drone that hunts enemies.", false],
	["escort_chopper", "Escort Chopper", "killstreak", 9, 30, "Armored helicopter that guards you.", false],
	["carpet_bomb", "Carpet Bomb", "killstreak", 9, 34, "A bomber blankets an area.", false],
	["deep_scan", "Deep Scan", "killstreak", 12, 38, "Live enemy positions and facing.", false],
	["overwatch_gunship", "Overwatch Gunship", "killstreak", 11, 46, "Control a circling gunship's cannons.", false],
	["blackout_pulse", "Blackout Pulse", "killstreak", 15, 54, "Knocks out enemy electronics for 60 seconds.", false],
	["doomsday", "Doomsday", "killstreak", 25, 62, "Ends the match in your team's favor.", true],
	["second_wind", "Second Wind", "deathstreak", 3, 1, "Spawn with extra health for 10 seconds.", false],
	["mimic", "Mimic", "deathstreak", 4, 9, "Respawn with your killer's class.", false],
	["parting_gift", "Parting Gift", "deathstreak", 4, 17, "Drop a live grenade when you die.", false],
	["last_laugh", "Last Laugh", "deathstreak", 5, 41, "Get back up once after being downed.", false],
]

## Starts at 0 for rank 1. Index = rank - 1.
var rank_min_xp: Array[int] = []
## XP needed to complete the final rank (Ascension becomes available).
var max_xp: int = 0

var items: Dictionary = {} # id -> UnlockableData
var challenges: Array[ChallengeData] = []
var _challenge_index: Dictionary = {} # id -> ChallengeData


func _init() -> void:
	_build_ranks()
	_build_items()
	_build_challenges()


# --- Ranks -------------------------------------------------------------------

func _build_ranks() -> void:
	# Each rank costs a bit more than the last: 800 XP for rank 2, ~73k for the
	# last one, about 2.6M in total (close to the 2009 game's pacing).
	var total := 0
	for r in MAX_RANK:
		rank_min_xp.append(total)
		total += int(round((800.0 + r * 1050.0) / 100.0)) * 100
	max_xp = total


func rank_for_xp(value: int) -> int:
	var r := 1
	for i in range(1, MAX_RANK):
		if value >= rank_min_xp[i]:
			r = i + 1
		else:
			break
	return r


## XP needed to reach the next rank (or to complete the last one).
func xp_for_next_rank(rank: int) -> int:
	return max_xp if rank >= MAX_RANK else rank_min_xp[rank]


func rank_name(rank: int) -> String:
	var i := clampi(rank, 1, MAX_RANK) - 1
	return "%s %s" % [RANK_TITLES[i / RANK_SUBLEVELS.size()], RANK_SUBLEVELS[i % RANK_SUBLEVELS.size()]]


# --- Items -------------------------------------------------------------------

func _register(item: UnlockableData) -> void:
	assert(not items.has(item.id), "Duplicate content id: " + item.id)
	items[item.id] = item


func _build_items() -> void:
	for id in ATTACHMENTS:
		var a := UnlockableData.new()
		a.id = id
		a.kind = "attachment"
		a.display_name = ATTACHMENTS[id][0]
		a.description = ATTACHMENTS[id][1]
		a.unlock_rank = 0
		_register(a)

	for row in CAMO_TRACK:
		var c := UnlockableData.new()
		c.id = row[0]
		c.kind = "camo"
		c.display_name = row[1]
		c.unlock_rank = 0
		_register(c)

	for row in WEAPONS:
		var w := WeaponData.new()
		w.id = row[0]
		w.kind = "weapon"
		w.display_name = row[1]
		w.weapon_class = row[2]
		w.slot = row[3]
		w.unlock_rank = row[4]
		w.damage = row[5]
		w.fire_rate_rpm = row[6]
		w.magazine = row[7]
		w.range_m = row[8]
		w.attachment_unlocks = ATTACHMENT_TRACKS[w.weapon_class].duplicate()
		_register(w)

	for row in EQUIPMENT:
		var e := UnlockableData.new()
		e.id = row[0]
		e.display_name = row[1]
		e.kind = row[2]
		e.unlock_rank = row[3]
		e.description = row[4]
		_register(e)

	for row in FEATURES:
		var f := UnlockableData.new()
		f.id = row[0]
		f.kind = "feature"
		f.display_name = row[1]
		f.unlock_rank = row[2]
		f.description = row[3]
		_register(f)

	for row in PERKS:
		var p := PerkData.new()
		p.id = row[0]
		p.kind = "perk"
		p.display_name = row[1]
		p.slot = row[2]
		p.unlock_rank = row[3]
		p.description = row[4]
		p.elite_description = row[5]
		p.elite_event = row[6]
		p.elite_conditions = row[7]
		p.elite_target = row[8]
		p.elite_challenge_text = row[9]
		_register(p)

	for row in STREAKS:
		var s := StreakData.new()
		s.id = row[0]
		s.display_name = row[1]
		s.kind = row[2]
		s.count = row[3]
		s.unlock_rank = row[4]
		s.description = row[5]
		s.ends_match = row[6]
		_register(s)


func get_item(id: String) -> UnlockableData:
	return items.get(id)


func items_of_kind(kind: String) -> Array:
	var out: Array = []
	for item: UnlockableData in items.values():
		if item.kind == kind:
			out.append(item)
	return out


## Everything that unlocks exactly at this rank.
func unlocks_at_rank(rank: int) -> Array:
	var out: Array = []
	for item: UnlockableData in items.values():
		if item.unlock_rank == rank:
			out.append(item)
	return out


# --- Challenges --------------------------------------------------------------

func _add_challenge(id: String, display_name: String, description: String, category: String,
		event: String, conditions: Dictionary, tiers: Array, lifetime := false) -> void:
	var c := ChallengeData.new()
	c.id = id
	c.display_name = display_name
	c.description = description
	c.category = category
	c.event = event
	c.conditions = conditions
	c.tiers = tiers
	c.lifetime = lifetime
	assert(not _challenge_index.has(id), "Duplicate challenge id: " + id)
	challenges.append(c)
	_challenge_index[id] = c


func get_challenge(id: String) -> ChallengeData:
	return _challenge_index.get(id)


func _build_challenges() -> void:
	# Weapon kills -> attachments. Weapon headshots -> camos (primaries).
	for w: WeaponData in items_of_kind("weapon"):
		var kill_tiers: Array = []
		for att: String in w.attachment_unlocks:
			var kills: int = w.attachment_unlocks[att]
			kill_tiers.append({"target": kills, "xp": 250 + kills * 5,
				"rewards": [{"type": "attachment", "weapon": w.id, "id": att}]})
		if kill_tiers.is_empty():
			for kills in [10, 50, 150]:
				kill_tiers.append({"target": kills, "xp": 250 + kills * 5, "rewards": []})
		_add_challenge(w.id + "_marksman", w.display_name + " Marksman",
			"Get {target} kills with the %s." % w.display_name, "weapon", "kill", {"weapon": w.id}, kill_tiers)

		if w.slot == "primary":
			var camo_tiers: Array = []
			for row in CAMO_TRACK:
				camo_tiers.append({"target": row[2], "xp": 500 + row[2] * 10,
					"rewards": [{"type": "camo", "weapon": w.id, "id": row[0]}]})
			_add_challenge(w.id + "_expert", w.display_name + " Expert",
				"Get {target} headshots with the %s." % w.display_name, "weapon", "kill",
				{"weapon": w.id, "headshot": true}, camo_tiers)

	# Perks -> Elite versions.
	for p: PerkData in items_of_kind("perk"):
		_add_challenge(p.id + "_elite", p.display_name + " Elite", p.elite_challenge_text, "perk",
			p.elite_event, p.elite_conditions,
			[{"target": p.elite_target, "xp": 5000, "rewards": [{"type": "elite", "id": p.id}]}])

	# Streak rewards: use them to earn XP, a title and an emblem.
	for s: StreakData in items_of_kind("killstreak"):
		var targets: Array = [1, 5, 10] if s.ends_match else [10, 25, 50]
		_add_challenge(s.id + "_caller", s.display_name + " Caller",
			"Call in {target} %s." % s.display_name, "streak", "streak_used", {"streak": s.id}, [
				{"target": targets[0], "xp": 1000, "rewards": []},
				{"target": targets[1], "xp": 2500, "rewards": [{"type": "title", "id": s.display_name + " Caller"}]},
				{"target": targets[2], "xp": 5000, "rewards": [{"type": "emblem", "id": "emblem_" + s.id}]},
			])

	# Feats from bonus plays.
	for b: String in BONUSES:
		var bonus_name: String = BONUSES[b][0]
		_add_challenge("feat_" + b, bonus_name, "Earn {target} %s bonuses." % bonus_name, "feat", "bonus", {"bonus": b}, [
			{"target": 10, "xp": 500, "rewards": []},
			{"target": 50, "xp": 1500, "rewards": [{"type": "emblem", "id": "emblem_" + b}]},
			{"target": 150, "xp": 3000, "rewards": [{"type": "title", "id": bonus_name}]},
		])

	# Lifetime challenges survive Ascension.
	_add_challenge("lifetime_kills", "Body Count", "Get {target} kills.", "lifetime", "kill", {},
		_lifetime_tiers([100, 1000, 5000, 10000, 25000], "Body Count"), true)
	_add_challenge("lifetime_headshots", "Headhunter", "Get {target} headshots.", "lifetime", "kill",
		{"headshot": true}, _lifetime_tiers([50, 500, 2500, 5000, 10000], "Headhunter"), true)
	_add_challenge("lifetime_wins", "Winner's Circle", "Win {target} matches.", "lifetime", "match_end",
		{"won": true}, _lifetime_tiers([10, 50, 100, 250, 500], "Winner"), true)


func _lifetime_tiers(targets: Array, title_base: String) -> Array:
	var out: Array = []
	for i in targets.size():
		out.append({"target": targets[i], "xp": 1000 * (i + 1), "rewards": [
			{"type": "title", "id": "%s %s" % [title_base, RANK_SUBLEVELS[i]]},
			{"type": "emblem", "id": "emblem_%s_%d" % [title_base.to_lower().replace(" ", "_"), i + 1]},
		]})
	return out

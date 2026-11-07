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
	"defender": ["Defender", 50], # kill near a flag you own
	"attacker": ["Assault", 50], # kill near an enemy flag
	"capture": ["Captured", 150], # capture an objective
	"tag_confirm": ["Kill Confirmed", 50],
	"tag_deny": ["Kill Denied", 50],
	"streak_kill": ["Streak Kill", 0], # kills by a streak reward (feat only)
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
	"primary": "m4a1",
	"primary_attachments": [],
	"primary_camo": "",
	"secondary": "m9",
	"secondary_attachments": [],
	"lethal": "shard_grenade",
	"tactical": "flash_pop",
	"perks": ["quickhands", "heavy_rounds", "steady_hand"],
	"deathstreak": "second_wind",
}

## Preset classes usable at any rank (not validated against unlocks).
const PRESET_CLASSES := [
	{"name": "Rifleman", "primary": "m4a1", "primary_attachments": ["underbarrel_gl"], "primary_camo": "",
		"secondary": "m9", "secondary_attachments": [], "lethal": "shard_grenade", "tactical": "flash_pop",
		"perks": ["quickhands", "heavy_rounds", "steady_hand"], "deathstreak": "second_wind"},
	{"name": "Close Quarters", "primary": "mp5", "primary_attachments": ["suppressor"], "primary_camo": "",
		"secondary": "m1014", "secondary_attachments": [], "lethal": "shard_grenade", "tactical": "dazer",
		"perks": ["tireless", "fleetfoot", "hush"], "deathstreak": "second_wind"},
	{"name": "Overwatch", "primary": "m24", "primary_attachments": ["suppressor"], "primary_camo": "",
		"secondary": "m9", "secondary_attachments": [], "lethal": "tripwire_mine", "tactical": "smoke_canister",
		"perks": ["scrounger", "ghostline", "steady_hand"], "deathstreak": "second_wind"},
	{"name": "Heavy", "primary": "m249", "primary_attachments": ["grip"], "primary_camo": "",
		"secondary": "rpg7", "secondary_attachments": [], "lethal": "sticky_charge", "tactical": "flash_pop",
		"perks": ["scrounger", "heavy_rounds", "steady_hand"], "deathstreak": "second_wind"},
	{"name": "Recon", "primary": "ump45", "primary_attachments": ["holo"], "primary_camo": "",
		"secondary": "usp45", "secondary_attachments": [], "lethal": "hatchet", "tactical": "dazer",
		"perks": ["quickhands", "fleetfoot", "keen_eye"], "deathstreak": "second_wind"},
]

## id: [display name, description]
const ATTACHMENTS := {
	"reflex": ["Red Dot Sight", "Red-dot optic for fast target pickup."],
	"holo": ["Holo Sight", "Wide holographic optic."],
	"marksman_scope": ["4x Scope", "Mid-range magnified optic."],
	"thermal": ["Thermal Optic", "Shows targets as heat signatures."],
	"suppressor": ["Suppressor", "Hides you from the minimap when firing."],
	"underbarrel_gl": ["Grenade Launcher", "Single-shot grenade launcher."],
	"underbarrel_shotgun": ["Masterkey Shotgun", "Close-range backup blast."],
	"fmj": ["FMJ", "Better penetration through cover."],
	"pulse_tracker": ["Pulse Tracker", "Shows nearby enemies on a wrist screen."],
	"ext_mag": ["Extended Mag", "More rounds per magazine."],
	"rapid_fire": ["Rapid Fire", "Higher fire rate."],
	"grip": ["Foregrip", "Less recoil."],
	"akimbo": ["Akimbo", "One in each hand."],
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

## Per-class baseline stats; each weapon below overrides what differs.
const WEAPON_CLASS_DEFAULTS := {
	"assault": {"slot": "primary", "fire_mode": "auto", "damage_max": 30, "damage_min": 20, "range_min": 30, "range_max": 60,
		"fire_rate_rpm": 750, "magazine": 30, "reserve_mags": 4, "reload_time": 2.2, "reload_empty_time": 2.9,
		"ads_time": 0.25, "ads_fov_mult": 0.8, "move_mult": 0.95, "hip_spread": 3.5, "ads_spread": 0.12,
		"recoil_vertical": 0.55, "recoil_horizontal": 0.25, "penetration": 0.6, "sound": "rifle"},
	"smg": {"slot": "primary", "fire_mode": "auto", "damage_max": 40, "damage_min": 20, "range_min": 12, "range_max": 30,
		"fire_rate_rpm": 850, "magazine": 30, "reserve_mags": 5, "reload_time": 1.9, "reload_empty_time": 2.4,
		"ads_time": 0.18, "ads_fov_mult": 0.85, "move_mult": 1.0, "hip_spread": 2.4, "ads_spread": 0.3,
		"recoil_vertical": 0.45, "recoil_horizontal": 0.35, "penetration": 0.35, "sound": "smg"},
	"lmg": {"slot": "primary", "fire_mode": "auto", "damage_max": 40, "damage_min": 25, "range_min": 35, "range_max": 70,
		"fire_rate_rpm": 700, "magazine": 100, "reserve_mags": 2, "reload_time": 6.0, "reload_empty_time": 6.5,
		"ads_time": 0.42, "ads_fov_mult": 0.78, "move_mult": 0.85, "hip_spread": 5.5, "ads_spread": 0.18,
		"recoil_vertical": 0.5, "recoil_horizontal": 0.4, "penetration": 0.9, "sound": "lmg", "sprint_out_time": 0.4},
	"sniper": {"slot": "primary", "fire_mode": "semi", "damage_max": 70, "damage_min": 70, "range_min": 999, "range_max": 1000,
		"head_mult": 1.5, "chest_mult": 1.5, "fire_rate_rpm": 200, "magazine": 10, "reserve_mags": 3, "reload_time": 3.0,
		"reload_empty_time": 3.6, "ads_time": 0.4, "ads_fov_mult": 0.22, "move_mult": 0.9, "hip_spread": 8.0,
		"ads_spread": 0.0, "recoil_vertical": 2.5, "recoil_horizontal": 0.6, "penetration": 1.0, "sound": "sniper",
		"sprint_out_time": 0.4},
	"pistol": {"slot": "secondary", "fire_mode": "semi", "damage_max": 40, "damage_min": 20, "range_min": 10, "range_max": 25,
		"fire_rate_rpm": 600, "magazine": 15, "reserve_mags": 4, "reload_time": 1.6, "reload_empty_time": 2.0,
		"ads_time": 0.15, "ads_fov_mult": 0.9, "move_mult": 1.0, "hip_spread": 2.2, "ads_spread": 0.35,
		"recoil_vertical": 1.0, "recoil_horizontal": 0.35, "penetration": 0.3, "sound": "pistol", "swap_time": 0.35},
	"machine_pistol": {"slot": "secondary", "fire_mode": "auto", "damage_max": 30, "damage_min": 20, "range_min": 8, "range_max": 22,
		"fire_rate_rpm": 900, "magazine": 20, "reserve_mags": 4, "reload_time": 1.7, "reload_empty_time": 2.1,
		"ads_time": 0.16, "ads_fov_mult": 0.9, "move_mult": 1.0, "hip_spread": 2.6, "ads_spread": 0.6,
		"recoil_vertical": 0.6, "recoil_horizontal": 0.5, "penetration": 0.25, "sound": "smg", "swap_time": 0.35},
	"shotgun": {"slot": "secondary", "fire_mode": "pump", "damage_max": 40, "damage_min": 10, "range_min": 6, "range_max": 18,
		"pellets": 8, "head_mult": 1.0, "fire_rate_rpm": 70, "magazine": 6, "reserve_mags": 4, "reload_time": 0.5,
		"reload_empty_time": 0.5, "ads_time": 0.2, "ads_fov_mult": 0.9, "move_mult": 1.0, "hip_spread": 5.0,
		"ads_spread": 4.0, "recoil_vertical": 3.0, "recoil_horizontal": 0.8, "penetration": 0.2, "sound": "shotgun"},
	"launcher": {"slot": "secondary", "fire_mode": "launcher", "damage_max": 150, "damage_min": 150, "range_min": 999, "range_max": 1000,
		"fire_rate_rpm": 30, "magazine": 1, "reserve_mags": 1, "reload_time": 3.5, "reload_empty_time": 3.5,
		"ads_time": 0.4, "ads_fov_mult": 0.75, "move_mult": 0.9, "hip_spread": 1.5, "ads_spread": 0.0,
		"recoil_vertical": 2.0, "recoil_horizontal": 0.5, "penetration": 0.0, "projectile_speed": 60.0,
		"blast_radius": 6.0, "sound": "launcher", "swap_time": 0.8},
}

## id, name, class, unlock rank + any stat overrides. Shotgun reloads are per shell.
const WEAPONS := [
	# Assault rifles
	{"id": "m4a1", "name": "M4A1", "class": "assault", "rank": 1, "fire_rate_rpm": 800, "recoil_vertical": 0.45},
	{"id": "m16a4", "name": "M16A4", "class": "assault", "rank": 1, "fire_mode": "burst", "damage_max": 40, "damage_min": 30,
		"fire_rate_rpm": 900, "recoil_vertical": 0.5},
	{"id": "ak74", "name": "AK-74", "class": "assault", "rank": 4, "fire_rate_rpm": 650, "damage_max": 32, "damage_min": 22,
		"recoil_vertical": 0.55, "recoil_horizontal": 0.3},
	{"id": "scar_h", "name": "SCAR-H", "class": "assault", "rank": 8, "magazine": 20, "fire_rate_rpm": 600, "damage_max": 40,
		"damage_min": 30, "recoil_vertical": 0.75, "sound": "rifle_heavy"},
	{"id": "g36c", "name": "G36C", "class": "assault", "rank": 12, "fire_rate_rpm": 750, "recoil_vertical": 0.42, "recoil_horizontal": 0.2},
	{"id": "famas", "name": "FAMAS F1", "class": "assault", "rank": 16, "fire_mode": "burst", "damage_max": 40, "damage_min": 30,
		"magazine": 25, "fire_rate_rpm": 1000, "recoil_vertical": 0.45},
	{"id": "aug", "name": "AUG A3", "class": "assault", "rank": 24, "fire_rate_rpm": 700, "damage_max": 33, "damage_min": 22,
		"recoil_vertical": 0.38, "ads_time": 0.28},
	{"id": "fal", "name": "FN FAL", "class": "assault", "rank": 32, "fire_mode": "semi", "magazine": 20, "damage_max": 55,
		"damage_min": 34, "fire_rate_rpm": 650, "recoil_vertical": 1.0, "sound": "rifle_heavy"},
	{"id": "hk416", "name": "HK416", "class": "assault", "rank": 48, "fire_rate_rpm": 850, "recoil_vertical": 0.4, "recoil_horizontal": 0.18},
	{"id": "ak47", "name": "AK-47", "class": "assault", "rank": 70, "fire_rate_rpm": 600, "damage_max": 40, "damage_min": 30,
		"recoil_vertical": 0.7, "recoil_horizontal": 0.4, "sound": "rifle_heavy"},
	# Submachine guns
	{"id": "mp5", "name": "MP5", "class": "smg", "rank": 1, "fire_rate_rpm": 800, "recoil_vertical": 0.35},
	{"id": "ump45", "name": "UMP45", "class": "smg", "rank": 4, "magazine": 25, "fire_rate_rpm": 650, "damage_min": 35,
		"range_max": 35, "recoil_vertical": 0.5},
	{"id": "p90", "name": "P90", "class": "smg", "rank": 18, "magazine": 50, "fire_rate_rpm": 900, "damage_max": 34, "recoil_vertical": 0.35},
	{"id": "mp7", "name": "MP7", "class": "smg", "rank": 26, "magazine": 40, "fire_rate_rpm": 950, "damage_max": 34, "recoil_vertical": 0.4},
	{"id": "vector", "name": "Vector", "class": "smg", "rank": 40, "magazine": 25, "fire_rate_rpm": 1100, "recoil_vertical": 0.25,
		"recoil_horizontal": 0.2},
	{"id": "mini_uzi", "name": "Mini-Uzi", "class": "smg", "rank": 44, "magazine": 32, "fire_rate_rpm": 1000, "recoil_vertical": 0.55,
		"recoil_horizontal": 0.55},
	# Light machine guns
	{"id": "m249", "name": "M249", "class": "lmg", "rank": 1, "fire_rate_rpm": 750, "damage_max": 38},
	{"id": "rpk", "name": "RPK", "class": "lmg", "rank": 16, "magazine": 75, "fire_rate_rpm": 600, "damage_max": 40, "damage_min": 30,
		"reload_time": 4.0, "reload_empty_time": 4.5},
	{"id": "m60e4", "name": "M60E4", "class": "lmg", "rank": 36, "fire_rate_rpm": 550, "damage_max": 50, "damage_min": 30,
		"recoil_vertical": 0.7, "sound": "rifle_heavy"},
	{"id": "pkm", "name": "PKM", "class": "lmg", "rank": 52, "fire_rate_rpm": 650, "damage_max": 45, "damage_min": 32,
		"recoil_vertical": 0.65, "sound": "rifle_heavy"},
	# Sniper rifles
	{"id": "m24", "name": "M24", "class": "sniper", "rank": 1, "fire_mode": "bolt", "magazine": 5, "damage_max": 98, "damage_min": 98,
		"fire_rate_rpm": 45, "recoil_vertical": 3.5},
	{"id": "svd", "name": "SVD", "class": "sniper", "rank": 20, "fire_rate_rpm": 250, "recoil_vertical": 2.2},
	{"id": "m14ebr", "name": "M14 EBR", "class": "sniper", "rank": 30, "magazine": 20, "damage_max": 70, "damage_min": 50,
		"range_min": 50, "range_max": 100, "fire_rate_rpm": 350, "recoil_vertical": 1.6, "hip_spread": 6.0},
	{"id": "m107", "name": "M107", "class": "sniper", "rank": 56, "damage_max": 98, "damage_min": 98, "fire_rate_rpm": 180,
		"recoil_vertical": 3.0, "ads_time": 0.5, "sound": "sniper_heavy"},
	# Pistols
	{"id": "m9", "name": "M9", "class": "pistol", "rank": 1},
	{"id": "usp45", "name": "USP .45", "class": "pistol", "rank": 1, "magazine": 12, "damage_min": 30, "recoil_vertical": 1.2},
	{"id": "p226", "name": "P226", "class": "pistol", "rank": 22, "damage_max": 45, "damage_min": 25},
	{"id": "magnum", "name": ".44 Magnum", "class": "pistol", "rank": 28, "magazine": 6, "damage_max": 60, "damage_min": 40,
		"fire_rate_rpm": 200, "recoil_vertical": 3.5, "reload_time": 2.6, "reload_empty_time": 2.6, "sound": "magnum"},
	# Machine pistols
	{"id": "skorpion", "name": "Skorpion", "class": "machine_pistol", "rank": 1},
	{"id": "tmp", "name": "TMP", "class": "machine_pistol", "rank": 38, "magazine": 15, "recoil_vertical": 0.45},
	{"id": "m93r", "name": "M93R", "class": "machine_pistol", "rank": 50, "fire_mode": "burst", "damage_max": 40, "fire_rate_rpm": 1100},
	# Shotguns
	{"id": "m1014", "name": "M1014", "class": "shotgun", "rank": 1, "fire_mode": "semi", "damage_max": 30, "fire_rate_rpm": 240,
		"magazine": 6},
	{"id": "spas12", "name": "SPAS-12", "class": "shotgun", "rank": 6, "damage_max": 40, "magazine": 8},
	{"id": "double_barrel", "name": "Double Barrel", "class": "shotgun", "rank": 12, "fire_mode": "semi", "magazine": 2,
		"fire_rate_rpm": 400, "damage_max": 42, "reload_time": 2.0, "reload_empty_time": 2.0},
	{"id": "aa12", "name": "AA-12", "class": "shotgun", "rank": 42, "fire_mode": "auto", "magazine": 8, "pellets": 6,
		"damage_max": 25, "fire_rate_rpm": 300, "reload_time": 2.8, "reload_empty_time": 3.2, "recoil_vertical": 1.2},
	# Launchers
	{"id": "rpg7", "name": "RPG-7", "class": "launcher", "rank": 1, "reserve_mags": 1},
	{"id": "at4", "name": "AT4", "class": "launcher", "rank": 14, "projectile_speed": 80.0, "reload_time": 4.0},
	{"id": "m79", "name": "M79", "class": "launcher", "rank": 24, "projectile_speed": 40.0, "projectile_gravity": 9.8,
		"blast_radius": 5.0, "damage_max": 130, "damage_min": 130, "reserve_mags": 4, "reload_time": 2.5, "reload_empty_time": 2.5},
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

	for row: Dictionary in WEAPONS:
		var w := WeaponData.new()
		w.id = row["id"]
		w.kind = "weapon"
		w.display_name = row["name"]
		w.weapon_class = row["class"]
		w.unlock_rank = row["rank"]
		w.model = row.get("model", w.id)
		var stats: Dictionary = WEAPON_CLASS_DEFAULTS[w.weapon_class].duplicate()
		for key: String in row:
			if not key in ["id", "name", "class", "rank", "model"]:
				stats[key] = row[key]
		for key: String in stats:
			assert(key in w, "Unknown weapon stat %s on %s" % [key, w.id])
			w.set(key, stats[key])
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

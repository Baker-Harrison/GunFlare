class_name Match
extends Node3D
## Runs one match: builds the map, spawns the player and bots, applies the
## mode's rules, tracks score and kill bonuses, feeds progression events
## and shows the end-of-match report.

signal finished

const BOT_NAMES := [
	"Viper", "Ghostdog", "Havoc", "Nomad", "Reaper", "Tank", "Sparrow", "Wolfe", "Bishop", "Kodiak",
	"Rook", "Saint", "Ozzy", "Hammer", "Fable", "Dutch", "Ranger", "Crow", "Mako", "Volt", "Jester",
	"Grizzly", "Patch", "Lynx", "Tex", "Diesel", "Echo", "Bravo", "Moss", "Zulu", "Gunner", "Frost",
	"Talon", "Shade", "Rocco", "Brick", "Ace", "Ivan", "Sasha", "Yuri", "Boris", "Dima", "Kostya",
]
const TEAM_COLORS := [Color(0.4, 0.8, 1.0), Color(1.0, 0.38, 0.3)]

var config: Dictionary = {}
var mode: GameMode
var map: MapBase
var soldiers: Array[Soldier] = []
var player: Soldier
var player_ctrl: PlayerController
var streaks: StreakManager
var in_progress := false
var ended := false
## Pre-match countdown: soldiers are spawned and can look around, but
## cannot move, shoot or use equipment until it reaches zero.
const PRE_MATCH_COUNTDOWN := 10.0
var pre_match := false
var countdown := 0.0
var time_left := 600.0
var elapsed := 0.0
var world_env: WorldEnvironment

var _stats: Dictionary = {}
var _respawn: Dictionary = {}
var _damage_log: Dictionary = {} # victim -> [{attacker, time}]
var _first_blood := false
var _recent_kills: Dictionary = {} # soldier -> [times]
var _last_killer_of: Dictionary = {}
var _recent_deaths: Array = [] # [{killer, victim, time}]
var _pending_class: Dictionary = {}
var _player_class: Dictionary = {}
var _loading: Control
var _pause_menu: PauseMenu
var _xp_at_start := 0
var _rank_at_start := 1
var _match_unlocks: Array = []
var _match_challenges: Array = []
var _player_score_events := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_show_loading()
	await get_tree().process_frame
	await _build()


func _show_loading() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_loading = LoadingScreen.new()
	_loading.map_name = MapCatalog.display_name(config.get("map", "dustline"))
	_loading.mode_name = GameMode.create(config.get("mode", "tdm")).display_name
	layer.add_child(_loading)


func _build() -> void:
	Equipment.smokes.clear()
	Equipment.beacons.clear()
	map = MapCatalog.create(config.get("map", "dustline"))
	add_child(map)
	print("[match] building map")
	map.build()
	print("[match] map built: ", map.geometry.get_child_count(), " nodes")
	world_env = map.environment_node
	Fx.attach_to(self)
	Sfx.attach_to(self)
	_loading.set_status("Building navigation...")
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	await map.bake_navigation()
	print("[match] nav baked in ", Time.get_ticks_msec() - t0, " ms")

	mode = GameMode.create(config.get("mode", "tdm"))
	if config.has("score_limit"):
		mode.score_limit = config["score_limit"]
	if config.has("time_limit"):
		mode.time_limit = config["time_limit"]
	mode.setup(self)
	time_left = mode.time_limit
	streaks = StreakManager.new()
	streaks.match_ref = self
	add_child(streaks)

	_loading.set_status("Deploying...")
	_xp_at_start = Progression.xp
	_rank_at_start = Progression.rank
	Progression.ranked_up.connect(_on_player_ranked_up)
	ChallengeTracker.tier_completed.connect(_on_challenge_tier)

	# Player
	player = Soldier.new()
	player.display_name = str(Settings.get_value("player_name"))
	player.team = 0
	player.match_ref = self
	add_child(player)
	player_ctrl = PlayerController.new()
	add_child(player_ctrl)
	player_ctrl.setup(player, world_env.environment if world_env else null)
	player_ctrl.pause_requested.connect(_toggle_pause)
	_register(player)
	if config.get("autoplay", false):
		player_ctrl.autoplay = true
		var pb := BotBrain.new()
		pb.soldier = player
		pb.match_ref = self
		pb.difficulty = 3
		player.add_child(pb)
	_player_class = _resolve_class(config.get("class", {"source": "preset", "index": 0}))

	# Bots
	var bot_count: int = config.get("bots", 11)
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var difficulty: int = config.get("difficulty", Settings.get_value("bot_difficulty"))
	for i in bot_count:
		var b := Soldier.new()
		b.display_name = names[i % names.size()]
		b.team = (i + 1) % 2 if mode.team_based else i + 1
		if mode.team_based and bot_count % 2 == 1:
			# Player's team gets one fewer bot so teams are even.
			b.team = 1 if i < (bot_count + 1) / 2 else 0
		b.difficulty = difficulty
		b.match_ref = self
		add_child(b)
		var brain := BotBrain.new()
		brain.soldier = b
		brain.match_ref = self
		brain.difficulty = difficulty
		b.add_child(brain)
		b.set_meta("bot_loadout_seed", randi())
		b.set_meta("bot_rank", randi_range(maxi(1, difficulty * 15), mini(70, 25 + difficulty * 15)))
		_register(b)

	for s in soldiers:
		_spawn(s, true)
	_loading.get_parent().queue_free()
	_loading = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play_music("match", -14.0)
	countdown = float(config.get("countdown", PRE_MATCH_COUNTDOWN))
	if countdown > 0.0:
		pre_match = true
		print("[match] pre-match countdown ", countdown, " s")
		hud_banner(mode.display_name.to_upper(), map.display_name, Color(1, 0.85, 0.3), minf(countdown, 4.0))
	else:
		_begin_match()


func _begin_match() -> void:
	pre_match = false
	countdown = 0.0
	in_progress = true
	print("[match] in progress")
	hud_banner("GO!", "%s  —  %s" % [mode.display_name, map.display_name], Color(1, 0.85, 0.3), 2.5)
	Sfx.play_2d("match_start", -2.0)
	get_tree().create_timer(0.4).timeout.connect(func() -> void: Sfx.play_2d("vo_match_start", 0.0))


func _update_countdown(delta: float) -> void:
	var before := ceili(countdown)
	countdown -= delta
	var now_sec := ceili(maxf(countdown, 0.0))
	if now_sec != before and now_sec > 0 and now_sec <= 5:
		Sfx.play_ui("tick")
	if countdown <= 0.0:
		_begin_match()


func _register(s: Soldier) -> void:
	soldiers.append(s)
	_stats[s] = {"score": 0, "kills": 0, "deaths": 0, "assists": 0, "streak_best": 0}
	s.died.connect(_on_soldier_died)
	s.damaged.connect(func(info: DamageInfo) -> void: _log_damage(s, info))


func stats_of(s: Soldier) -> Dictionary:
	return _stats.get(s, {"score": 0, "kills": 0, "deaths": 0, "assists": 0})


func add_personal_score(s: Soldier, pts: int) -> void:
	if _stats.has(s):
		_stats[s]["score"] += pts


func are_enemies(a: Node, b: Node) -> bool:
	if a == null or b == null or a == b:
		return false
	return a.get("team") != b.get("team")


# --- Loadouts ----------------------------------------------------------------

func _resolve_class(sel: Dictionary) -> Dictionary:
	var l: Dictionary
	if sel.get("source", "preset") == "custom":
		var idx: int = sel.get("index", 0)
		if idx < Progression.classes.size() and Progression.custom_class_slots() > idx:
			l = Progression.classes[idx].duplicate(true)
			if not Progression.validate_loadout(l).is_empty():
				l = ContentDB.PRESET_CLASSES[0].duplicate(true)
		else:
			l = ContentDB.PRESET_CLASSES[0].duplicate(true)
	else:
		l = ContentDB.PRESET_CLASSES[clampi(sel.get("index", 0), 0, ContentDB.PRESET_CLASSES.size() - 1)].duplicate(true)
	l["streaks"] = Progression.selected_streaks.duplicate()
	return l


func choose_class(sel: Dictionary) -> void:
	_pending_class = _resolve_class(sel)
	# Before the match or within the first seconds of a life, switch immediately.
	if player.alive and (pre_match or player.now() - player.spawn_time < 6.0):
		_player_class = _pending_class
		_pending_class = {}
		player.spawn(player.global_transform, _player_class, _player_elites())
		hud_popup("CLASS CHANGED", Color(1, 1, 1))
	else:
		hud_popup("Class will change on respawn", Color(1, 1, 1, 0.8))


func _player_elites() -> Array:
	return Progression.elite_perks.duplicate()


func _bot_loadout(b: Soldier) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.get_meta("bot_loadout_seed")) + _stats[b]["deaths"] * 7919
	var rank: int = b.get_meta("bot_rank")
	var roll := rng.randf()
	var cls := "assault"
	if roll < 0.25:
		cls = "smg"
	elif roll < 0.35:
		cls = "lmg"
	elif roll < 0.47:
		cls = "sniper"
	var pick := func(kind: String, filter: Callable) -> String:
		var opts: Array = []
		for it: UnlockableData in ContentDB.items_of_kind(kind):
			if it.unlock_rank <= rank and filter.call(it):
				opts.append(it.id)
		return opts[rng.randi() % opts.size()] if not opts.is_empty() else ""
	var primary: String = pick.call("weapon", func(w: WeaponData) -> bool: return w.slot == "primary" and w.weapon_class == cls)
	if primary == "":
		primary = "m4a1"
	var secondary: String = pick.call("weapon", func(w: WeaponData) -> bool: return w.slot == "secondary" and w.weapon_class != "launcher")
	if rng.randf() < 0.15:
		secondary = pick.call("weapon", func(w: WeaponData) -> bool: return w.slot == "secondary" and w.weapon_class == "launcher")
	if secondary == "":
		secondary = "m9"
	var w: WeaponData = ContentDB.get_item(primary)
	var atts: Array = []
	var track: Array = w.attachment_unlocks.keys()
	if not track.is_empty() and rng.randf() < 0.75:
		atts.append(track[rng.randi() % mini(track.size(), 2 + rank / 10)])
	var perks: Array = []
	for slot in [1, 2, 3]:
		var p: String = pick.call("perk", func(pk: PerkData) -> bool: return pk.slot == slot and pk.id != "swap_kit")
		perks.append(p)
	var camo := ""
	if rng.randf() < 0.35:
		var camos := ContentDB.CAMO_TRACK
		camo = camos[rng.randi() % mini(camos.size(), 1 + rank / 9)][0]
	var streak_opts: Array = []
	for st: StreakData in ContentDB.items_of_kind("killstreak"):
		if st.unlock_rank <= rank:
			streak_opts.append(st)
	streak_opts.shuffle()
	var chosen := streak_opts.slice(0, 3)
	chosen.sort_custom(func(a: StreakData, b2: StreakData) -> bool: return a.count < b2.count)
	return {
		"name": "Bot", "primary": primary, "primary_attachments": atts, "primary_camo": camo,
		"secondary": secondary, "secondary_attachments": [],
		"lethal": pick.call("lethal", func(_x: UnlockableData) -> bool: return true),
		"tactical": pick.call("tactical", func(_x: UnlockableData) -> bool: return true),
		"perks": perks,
		"deathstreak": pick.call("deathstreak", func(_x: UnlockableData) -> bool: return true),
		"streaks": chosen.map(func(st: StreakData) -> String: return st.id),
	}


# --- Spawning ----------------------------------------------------------------

func _spawn(s: Soldier, initial := false) -> void:
	var xf := _pick_spawn(s, initial)
	if s == player:
		if not _pending_class.is_empty():
			_player_class = _pending_class
			_pending_class = {}
		s.spawn(xf, _player_class, _player_elites())
		player_ctrl.hud.set_respawn_text("")
		player_ctrl.hud.set_death_info("")
	else:
		var l := _bot_loadout(s)
		var elites: Array = []
		for p in l["perks"]:
			if randf() < 0.4 + s.difficulty * 0.15:
				elites.append(p)
		s.spawn(xf, l, elites)


func _pick_spawn(s: Soldier, initial: bool) -> Transform3D:
	if Equipment.beacons.has(s) and is_instance_valid(Equipment.beacons[s]):
		var b: Node3D = Equipment.beacons[s]
		var t := Transform3D(Basis(Vector3.UP, s.yaw), b.global_position + Vector3.UP * 0.1)
		b.queue_free()
		Equipment.beacons.erase(s)
		return t
	var points: Array = map.spawn_points(s.team if mode.team_based else -1, initial)
	if points.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	var best: Transform3D = points[0]
	var best_score := -INF
	var space := get_world_3d().direct_space_state
	for xf: Transform3D in points:
		var p := xf.origin
		var near_enemy := 999.0
		var near_friend := 999.0
		var seen := false
		var occupied := false
		for o: Soldier in soldiers:
			if o == s or not o.alive:
				continue
			var d := o.global_position.distance_to(p)
			if d < 1.2:
				occupied = true
			if are_enemies(s, o):
				near_enemy = minf(near_enemy, d)
				if d < 70.0 and not seen:
					var q := PhysicsRayQueryParameters3D.create(o.aim_origin(), p + Vector3.UP * 1.5, Layers.WORLD)
					if space.intersect_ray(q).is_empty():
						seen = true
			else:
				near_friend = minf(near_friend, d)
		if occupied:
			continue
		var score := minf(near_enemy, 60.0)
		if seen:
			score -= 45.0
		if mode.team_based and near_friend < 999.0:
			score -= minf(near_friend, 50.0) * 0.15
		score += mode.spawn_bias(s, p)
		score += randf() * (25.0 if initial else 8.0)
		if score > best_score:
			best_score = score
			best = xf
	return best


# --- Damage / kills ----------------------------------------------------------

func _log_damage(victim: Soldier, info: DamageInfo) -> void:
	var a := info.attacker as Soldier
	if a == null or a == victim:
		return
	if not _damage_log.has(victim):
		_damage_log[victim] = []
	_damage_log[victim].append({"attacker": a, "time": elapsed})


func _on_soldier_died(victim: Soldier, info: DamageInfo) -> void:
	if ended:
		return
	var killer := info.attacker as Soldier
	if killer and not is_instance_valid(killer):
		killer = null
	var victim_streak := victim.kills_this_life
	_stats[victim]["deaths"] += 1
	var was_comeback := false
	var weapon_name := _weapon_display(info)
	if killer and killer != victim and are_enemies(killer, victim):
		_stats[killer]["kills"] += 1
		was_comeback = killer.deaths_without_kill >= 4
		killer.deaths_without_kill = 0
		killer.kills_this_life += 1
		_stats[killer]["streak_best"] = maxi(_stats[killer]["streak_best"], killer.kills_this_life)
		var pts := mode.on_kill(killer, victim, info)
		add_personal_score(killer, pts)
		var bonuses := _kill_bonuses(killer, victim, info, victim_streak, was_comeback)
		for b: String in bonuses:
			add_personal_score(killer, ContentDB.BONUSES[b][1])
		if killer.is_player:
			_report_player_kill(killer, info, bonuses)
		streaks.on_kill(killer, info)
		# Assists
		for entry: Dictionary in _damage_log.get(victim, []):
			var a: Soldier = entry["attacker"]
			if a != killer and is_instance_valid(a) and elapsed - entry["time"] < 10.0 and are_enemies(a, victim):
				_stats[a]["assists"] += 1
				add_personal_score(a, 20)
				if a.is_player:
					GameEvents.report("assist", {"weapon": ""})
					hud_popup("ASSIST", Color(1, 1, 1, 0.8))
				break
		_last_killer_of[victim] = killer
		_recent_deaths.append({"killer": killer, "victim": victim, "time": elapsed})
		if killer.has_perk("scrounger"):
			_drop_ammo(victim)
	else:
		# Suicide or world death.
		add_personal_score(victim, -50)
	_damage_log.erase(victim)
	victim.deaths_without_kill += 1
	victim.kills_this_life = 0
	victim.streak_inventory = victim.streak_inventory # earned rewards are kept, like the classic games
	_drop_weapon(victim)
	# Killfeed
	if player_ctrl:
		var kname := killer.display_name if killer else ""
		var kcol: Color = _team_color(killer) if killer else Color.WHITE
		if killer == null or killer == victim:
			kname = ""
		player_ctrl.hud.add_killfeed(kname, kcol, weapon_name, victim.display_name, _team_color(victim), info.headshot)
	if victim.is_player:
		GameEvents.report("death", {})
		player_ctrl.on_player_died(killer)
		var txt := "You were killed by %s" % killer.display_name if killer and killer != victim else "You died"
		if killer and killer != victim:
			txt += "  —  " + weapon_name
		player_ctrl.hud.set_death_info(txt)
	_respawn[victim] = mode.respawn_delay


func _team_color(s: Soldier) -> Color:
	if s == null:
		return Color.WHITE
	if not mode.team_based:
		return Color(1, 0.85, 0.3) if s == player else TEAM_COLORS[1]
	return TEAM_COLORS[0] if s.team == player.team else TEAM_COLORS[1]


func _weapon_display(info: DamageInfo) -> String:
	if info.streak != "":
		var st := ContentDB.get_item(info.streak)
		return st.display_name if st else info.streak
	var it := ContentDB.get_item(info.weapon_id)
	if it:
		return it.display_name
	match info.weapon_id:
		"knife":
			return "Knife"
		"fall":
			return "Fall"
		"underbarrel_gl":
			return "Grenade Launcher"
		"parting_gift":
			return "Parting Gift"
		"bleed_out":
			return "Bled Out"
	return info.weapon_id.capitalize()


func _kill_bonuses(killer: Soldier, victim: Soldier, info: DamageInfo, victim_streak: int, comeback: bool) -> Array:
	var out: Array = []
	if not _first_blood:
		_first_blood = true
		out.append("first_blood")
	var times: Array = _recent_kills.get(killer, [])
	times = times.filter(func(t: float) -> bool: return elapsed - t < 1.75)
	times.append(elapsed)
	_recent_kills[killer] = times
	if times.size() == 2:
		out.append("double_kill")
	elif times.size() == 3:
		out.append("triple_kill")
	elif times.size() >= 4:
		out.append("multi_kill")
	if _last_killer_of.get(killer) == victim:
		out.append("payback")
		_last_killer_of.erase(killer)
	for d: Dictionary in _recent_deaths:
		if d["killer"] == victim and elapsed - d["time"] < 3.0 and d["victim"] != killer and not are_enemies(d["victim"], killer):
			out.append("avenger")
			break
	if victim_streak >= 5:
		out.append("spoiler")
	if info.distance > 45.0 and not info.explosive and info.streak == "":
		out.append("long_shot")
	if info.distance < 2.5 and not info.melee and info.streak == "":
		out.append("point_blank")
	if comeback:
		out.append("comeback")
	if not killer.alive:
		out.append("posthumous")
	if info.streak != "":
		out.append("streak_kill")
	return out


func _report_player_kill(k: Soldier, info: DamageInfo, bonuses: Array) -> void:
	var w := ContentDB.get_item(info.weapon_id) as WeaponData
	GameEvents.report("kill", {
		"weapon": info.weapon_id if info.streak == "" else "",
		"weapon_class": w.weapon_class if w else "",
		"headshot": info.headshot,
		"perks": k.perks,
		"attachment_count": info.attachment_count,
		"distance": info.distance,
		"explosive": info.explosive,
		"melee": info.melee,
		"downed": k.downed,
		"streak": info.streak,
	})
	for b: String in bonuses:
		GameEvents.report("bonus", {"bonus": b})
		if ContentDB.BONUSES[b][1] > 0 or b == "streak_kill":
			if b != "streak_kill":
				hud_popup(ContentDB.BONUSES[b][0].to_upper(), Color(1, 0.85, 0.3))
	if info.headshot:
		hud_popup("HEADSHOT", Color(1, 1, 1))


func _drop_ammo(victim: Soldier) -> void:
	var p := AmmoPickup.new()
	add_child(p)
	p.global_position = victim.global_position + Vector3.UP * 0.3


func _drop_weapon(victim: Soldier) -> void:
	var w := victim.weapon()
	if w == null or w.is_empty():
		return
	var p := WeaponPickup.new()
	p.weapon = w
	add_child(p)
	p.global_position = victim.global_position + Vector3.UP * 0.4


# --- Loop --------------------------------------------------------------------

func _process(delta: float) -> void:
	if pre_match and not ended:
		_update_countdown(delta)
		return
	if not in_progress:
		return
	elapsed += delta
	var before := time_left
	time_left -= delta
	if before > 60.0 and time_left <= 60.0:
		Sfx.play_2d("vo_one_minute", 0.0)
	mode.update(delta)
	_announce_lead()
	if time_left <= 0.0:
		time_left = 0.0
		end_match()
		return
	for s: Soldier in _respawn.keys():
		_respawn[s] -= delta
		var can := true
		if mode.has_method("can_respawn"):
			can = mode.can_respawn(s)
		if s == player:
			var t: float = _respawn[s]
			player_ctrl.hud.set_respawn_text("Respawning in %d" % ceili(maxf(t, 0.0)) if can else "Waiting for HQ to fall...")
		if _respawn[s] <= 0.0 and can:
			_respawn.erase(s)
			_spawn(s)
	_recent_deaths = _recent_deaths.filter(func(d: Dictionary) -> bool: return elapsed - d["time"] < 5.0)
	_update_player_interact()


func _update_player_interact() -> void:
	if player == null or not player.alive:
		player_ctrl.hud.set_interact("")
		return
	var best: Node3D = null
	var best_d := 2.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = (n as Node3D).global_position.distance_to(player.global_position)
		if d < best_d and n.can_interact(player):
			best = n
			best_d = d
	if best:
		var prog: float = best.interact_progress(player, player.input.interact, get_process_delta_time())
		player_ctrl.hud.set_interact(best.interact_text(player), prog)
	else:
		player_ctrl.hud.set_interact("")


var _lead_state := 0


## "We are winning / losing" when the lead changes hands by a margin.
func _announce_lead() -> void:
	if not mode.team_based:
		return
	var mine: int = mode.scores[player.team]
	var theirs: int = mode.scores[1 - player.team]
	var margin := maxi(mode.score_limit / 8, 3)
	var state := 0
	if mine - theirs >= margin:
		state = 1
	elif theirs - mine >= margin:
		state = -1
	if state != 0 and state != _lead_state:
		Sfx.play_2d("vo_winning" if state > 0 else "vo_losing", 0.0)
	if state != 0:
		_lead_state = state


func use_streak(s: Soldier) -> void:
	streaks.use(s)


# --- Objectives / HUD hooks --------------------------------------------------

func announce_capture(label: String, team: int, cappers: Array) -> void:
	var ours := team == player.team
	hud_banner("%s CAPTURED" % label if label == "HQ" else "FLAG %s CAPTURED" % label, "", TEAM_COLORS[0] if ours else TEAM_COLORS[1], 2.5)
	Sfx.play_2d("capture_friendly" if ours else "capture_enemy", -4.0)
	Sfx.play_2d("vo_flag_taken" if ours else "vo_flag_lost", 0.0)
	for s: Soldier in cappers:
		add_personal_score(s, 150)
		if s.is_player:
			GameEvents.report("bonus", {"bonus": "capture"})


func hud_banner(title: String, sub := "", color := Color(1, 0.85, 0.3), duration := 3.0) -> void:
	if player_ctrl and player_ctrl.hud:
		player_ctrl.hud.banner(title, sub, color, duration)


func hud_popup(text: String, color := Color.WHITE) -> void:
	if player_ctrl and player_ctrl.hud:
		player_ctrl.hud.popup(text, color)


func hud_score(viewer: Soldier) -> Dictionary:
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	var d := {"time": "%d:%02d" % [mins, secs], "mode": mode.short_name, "limit": mode.score_limit, "bars": []}
	if mode.team_based:
		var mine := viewer.team
		d["bars"] = [
			{"name": SoldierModel.FACTIONS[mine]["name"].to_upper(), "score": mode.scores[mine], "color": TEAM_COLORS[0]},
			{"name": SoldierModel.FACTIONS[1 - mine]["name"].to_upper(), "score": mode.scores[1 - mine], "color": TEAM_COLORS[1]},
		]
	else:
		var sorted := soldiers.duplicate()
		sorted.sort_custom(func(a: Soldier, b: Soldier) -> bool: return _stats[a]["kills"] > _stats[b]["kills"])
		var lead: Soldier = sorted[0]
		d["bars"] = [{"name": "YOU", "score": _stats[viewer]["kills"], "color": TEAM_COLORS[0]}]
		if lead != viewer:
			d["bars"].append({"name": lead.display_name.to_upper(), "score": _stats[lead]["kills"], "color": TEAM_COLORS[1]})
		elif sorted.size() > 1:
			d["bars"].append({"name": sorted[1].display_name.to_upper(), "score": _stats[sorted[1]]["kills"], "color": TEAM_COLORS[1]})
	return d


func hud_objectives(viewer: Soldier) -> Array:
	var out := mode.hud_objectives(viewer)
	out.append_array(streaks.hud_markers(viewer))
	return out


func uav_level(viewer: Soldier) -> int:
	return streaks.uav_level(viewer.team)


func enemy_uav_active(viewer: Soldier) -> bool:
	return streaks.enemy_uav(viewer.team)


func is_jammed(viewer: Soldier) -> bool:
	return streaks.is_jammed(viewer.team)


func is_blacked_out(viewer: Soldier) -> bool:
	return streaks.is_blacked_out(viewer.team)


func bot_goal(s: Soldier) -> Variant:
	var crate = streaks.bot_crate_goal(s)
	if crate != null:
		return crate
	return mode.bot_goal(s)


func scoreboard_rows() -> Dictionary:
	var groups := {}
	for s in soldiers:
		var key := s.team if mode.team_based else 0
		if not groups.has(key):
			groups[key] = []
		var st: Dictionary = _stats[s]
		var rank := Progression.rank if s == player else int(s.get_meta("bot_rank", 1))
		groups[key].append({"name": s.display_name, "score": st["score"], "kills": st["kills"], "deaths": st["deaths"],
			"assists": st["assists"], "ping": 0 if s == player else 20 + (s.get_instance_id() % 40), "me": s == player,
			"alive": s.alive, "rank": str(rank)})
	var teams: Array = []
	var order: Array = [player.team, 1 - player.team] if mode.team_based else [0]
	for key in order:
		var rows: Array = groups.get(key, [])
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
		var nm: String = SoldierModel.FACTIONS[key]["name"].to_upper() if mode.team_based else "FREE-FOR-ALL"
		teams.append({"name": nm, "score": mode.scores[key] if mode.team_based else 0,
			"color": TEAM_COLORS[0] if key == player.team else TEAM_COLORS[1], "rows": rows})
	return {"title": "%s  —  %s" % [mode.display_name.to_upper(), map.display_name.to_upper()], "teams": teams}


# --- Pause / end ---------------------------------------------------------------

func _toggle_pause() -> void:
	if ended:
		return
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.close()
		return
	_pause_menu = PauseMenu.new()
	_pause_menu.match_ref = self
	add_child(_pause_menu)


func _on_player_ranked_up(new_rank: int, unlocks: Array) -> void:
	if not in_progress:
		return
	hud_banner("PROMOTED", "%s  (Rank %d)" % [ContentDB.rank_name(new_rank), new_rank], Color(1, 0.85, 0.3), 4.0)
	Sfx.play_2d("rank_up", -2.0)
	for u: UnlockableData in unlocks:
		_match_unlocks.append(u.display_name)
		hud_popup("UNLOCKED: " + u.display_name.to_upper(), Color(0.6, 1.0, 0.6))


func _on_challenge_tier(c: ChallengeData, tier_index: int) -> void:
	if not in_progress:
		return
	_match_challenges.append(c.display_name)
	hud_popup("CHALLENGE COMPLETE: %s" % c.display_name.to_upper(), Color(1, 0.85, 0.3))
	Sfx.play_2d("challenge", -4.0)
	for r: Dictionary in c.tiers[tier_index].get("rewards", []):
		if r["type"] == "attachment" or r["type"] == "camo":
			var it := ContentDB.get_item(r["id"])
			var w := ContentDB.get_item(r["weapon"])
			if it and w:
				_match_unlocks.append("%s %s" % [w.display_name, it.display_name])
		elif r["type"] == "elite":
			var p := ContentDB.get_item(r["id"])
			if p:
				_match_unlocks.append(p.display_name + " Elite")


func end_match(winner_override := -2) -> void:
	if ended:
		return
	ended = true
	in_progress = false
	var won: bool
	if winner_override >= -1:
		won = winner_override == player.team
		if mode.team_based and winner_override >= 0:
			mode.scores[winner_override] = maxi(mode.scores[winner_override], mode.scores[1 - winner_override] + 1)
	else:
		won = mode.did_win(player)
	for s in soldiers:
		s.input.fire = false
		s.set_physics_process(false)
	var minutes := elapsed / 60.0
	GameEvents.report("match_end", {"won": won, "minutes": minutes})
	if Progression.ranked_up.is_connected(_on_player_ranked_up):
		Progression.ranked_up.disconnect(_on_player_ranked_up)
	if ChallengeTracker.tier_completed.is_connected(_on_challenge_tier):
		ChallengeTracker.tier_completed.disconnect(_on_challenge_tier)
	Sfx.play_2d("victory" if won else "defeat", -2.0)
	Sfx.play_2d("vo_victory" if won else "vo_defeat", 0.0)
	Sfx.stop_music()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var screen := EndScreen.new()
	screen.match_ref = self
	screen.won = won
	screen.tied = mode.team_based and mode.scores[0] == mode.scores[1] and winner_override < -1
	screen.xp_gained = Progression.xp - _xp_at_start if Progression.prestige == Progression.prestige else 0
	screen.rank_start = _rank_at_start
	screen.unlocks = _match_unlocks
	screen.challenges = _match_challenges
	add_child(screen)


func leave() -> void:
	get_tree().paused = false
	Fx.attach_to(null)
	Sfx.attach_to(null)
	Game.return_to_menu()


func _exit_tree() -> void:
	if Progression.ranked_up.is_connected(_on_player_ranked_up):
		Progression.ranked_up.disconnect(_on_player_ranked_up)
	if ChallengeTracker.tier_completed.is_connected(_on_challenge_tier):
		ChallengeTracker.tier_completed.disconnect(_on_challenge_tier)

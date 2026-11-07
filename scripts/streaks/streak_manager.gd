class_name StreakManager
extends Node
## Earns, stores and activates streak rewards, and tracks the per-team
## intel effects (scans, jamming, blackout).

var match_ref: Match
var _uav: Dictionary = {} # team -> until
var _deep: Dictionary = {}
var _jam: Dictionary = {} # team that is jammed -> until
var _blackout: Dictionary = {} # team blacked out -> until
var _doomsday_t := -1.0
var _doomsday_team := -1
var _doomsday_owner: Soldier
var crates: Array = []


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Earning / using -------------------------------------------------------

func on_kill(killer: Soldier, _info: DamageInfo) -> void:
	var ids: Array = killer.loadout.get("streaks", [])
	var shortcut := 1 if killer.has_perk("shortcut") else 0
	for id: String in ids:
		var st := ContentDB.get_item(id) as StreakData
		if st == null:
			continue
		var need := maxi(st.count - shortcut, 1)
		if killer.kills_this_life == need:
			_earn(killer, id)


func _earn(s: Soldier, id: String) -> void:
	s.streak_inventory.append(id)
	s.streak_index = s.streak_inventory.size() - 1
	if s.is_player:
		var st := ContentDB.get_item(id)
		match_ref.hud_banner(st.display_name.to_upper() + " READY", "Press [4] to use", Color(0.6, 1.0, 0.6), 3.0)
		Sfx.play_2d("streak_ready", -2.0)
		Sfx.play_2d("vo_streak_ready", 0.0)
		GameEvents.report("streak_earned", {"streak": id, "perks": s.perks})


func grant(s: Soldier, id: String) -> void:
	_earn(s, id)


func use(s: Soldier) -> void:
	if s.streak_inventory.is_empty() or not s.alive or match_ref.ended:
		return
	var idx := clampi(s.streak_index, 0, s.streak_inventory.size() - 1)
	var id: String = s.streak_inventory[idx]
	if not activate(s, id):
		return
	s.streak_inventory.remove_at(idx)
	s.streak_index = maxi(s.streak_inventory.size() - 1, 0)
	if s.is_player:
		GameEvents.report("streak_used", {"streak": id})


func _friendly(s: Soldier) -> bool:
	return not match_ref.are_enemies(s, match_ref.player)


func _announce(s: Soldier, friendly_text: String, enemy_text: String, voice: String) -> void:
	if _friendly(s):
		match_ref.hud_popup(friendly_text, Color(0.5, 0.9, 1.0))
		Sfx.play_2d("vo_friendly_" + voice, -2.0)
	else:
		match_ref.hud_popup(enemy_text, Color(1.0, 0.45, 0.35))
		Sfx.play_2d("vo_enemy_" + voice, -2.0)


func activate(s: Soldier, id: String) -> bool:
	var team := s.team
	match id:
		"pulse_scan":
			_uav[team] = maxf(_uav.get(team, 0.0), _now()) + 30.0
			_spawn_air(s, "uav", 30.0)
			_announce(s, "FRIENDLY PULSE SCAN ONLINE", "ENEMY PULSE SCAN SPOTTED", "uav")
		"deep_scan":
			_deep[team] = maxf(_deep.get(team, 0.0), _now()) + 40.0
			_spawn_air(s, "uav", 40.0)
			_announce(s, "DEEP SCAN ONLINE", "ENEMY DEEP SCAN OVERHEAD", "uav")
		"jammer":
			for t in _teams_against(team):
				_jam[t] = maxf(_jam.get(t, 0.0), _now()) + 30.0
			_spawn_air(s, "jammer", 30.0)
			_announce(s, "JAMMER ONLINE", "ENEMY JAMMER — RADAR DOWN", "jammer")
		"blackout_pulse":
			for t in _teams_against(team):
				_blackout[t] = _now() + 60.0
			for v in get_tree().get_nodes_in_group("air_vehicles"):
				if is_instance_valid(v) and match_ref.are_enemies(v.owner_soldier, s):
					v.destroy()
			Fx.explosion_happened.emit(Vector3.ZERO, 0.0)
			_announce(s, "BLACKOUT PULSE DETONATED", "ENEMY BLACKOUT PULSE — SYSTEMS DOWN", "emp")
			Sfx.play_2d("emp", 0.0)
		"supply_crate":
			_call_crate(s)
		"mortar_strike":
			if s.is_player:
				var rm := RemoteMissile.new()
				rm.owner_soldier = s
				rm.match_ref = match_ref
				match_ref.add_child(rm)
			else:
				var target := _bot_target_pos(s)
				_delayed_strike(s, target, 3.0, "mortar_strike", 9.0, 350.0)
			_announce(s, "MORTAR STRIKE INBOUND", "ENEMY MORTAR STRIKE INBOUND", "airstrike")
		"sentry_post":
			var st := SentryPost.new()
			st.owner_soldier = s
			st.match_ref = match_ref
			match_ref.add_child(st)
			var pos := s.global_position - s.global_basis.z * 1.5
			st.global_position = _ground(pos)
			st.rotation.y = s.yaw
			if s.is_player:
				Sfx.play_2d("vo_sentry", 0.0)
		"strafing_run":
			var p := _aim_point(s)
			var dir := -s.global_basis.z
			var jet := _spawn_air(s, "jet", 6.0)
			jet.flyby(p, dir, 50.0)
			for i in 9:
				_delayed_strike(s, p + dir * (i - 4) * 6.0 + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 2.2 + i * 0.09, "strafing_run", 6.0, 160.0)
			_announce(s, "STRAFING RUN INBOUND", "ENEMY STRAFING RUN INBOUND", "airstrike")
		"carpet_bomb":
			var p2 := _aim_point(s)
			var dir2 := -s.global_basis.z
			var bomber := _spawn_air(s, "bomber", 9.0)
			bomber.flyby(p2, dir2, 70.0)
			for i in 22:
				_delayed_strike(s, p2 + dir2 * (i - 11) * 5.0 + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 3.0 + i * 0.07, "carpet_bomb", 7.0, 200.0)
			_announce(s, "CARPET BOMB INBOUND", "ENEMY BOMBER INBOUND", "airstrike")
		"hunter_drone":
			var d := _spawn_air(s, "drone", 45.0)
			d.hover_at(_aim_point(s) + Vector3.UP * 22.0)
			_announce(s, "HUNTER DRONE DEPLOYED", "ENEMY HUNTER DRONE", "air")
		"escort_chopper":
			var h := _spawn_air(s, "chopper", 60.0)
			h.escort(s)
			_announce(s, "ESCORT CHOPPER EN ROUTE", "ENEMY CHOPPER INBOUND", "air")
		"overwatch_gunship":
			var g := _spawn_air(s, "gunship", 40.0)
			if s.is_player:
				var view := GunshipView.new()
				view.gunship = g
				view.owner_soldier = s
				view.match_ref = match_ref
				match_ref.add_child(view)
			else:
				g.auto_gunship = true
			_announce(s, "OVERWATCH GUNSHIP ONLINE", "ENEMY GUNSHIP OVERHEAD", "air")
		"doomsday":
			if _doomsday_t >= 0.0:
				return false
			_doomsday_t = 10.0
			_doomsday_team = team
			_doomsday_owner = s
			match_ref.hud_banner("DOOMSDAY INBOUND", "", Color(1, 0.3, 0.2), 10.0)
			Sfx.play_2d("doomsday_siren", 0.0)
			Sfx.play_2d("vo_doomsday", 2.0)
		_:
			return false
	return true


func _teams_against(team: int) -> Array:
	var out: Array = []
	for s: Soldier in match_ref.soldiers:
		if s.team != team and not out.has(s.team):
			out.append(s.team)
	return out


func _spawn_air(s: Soldier, kind: String, life: float) -> AirVehicle:
	var v := AirVehicle.new()
	v.kind = kind
	v.owner_soldier = s
	v.team = s.team
	v.life = life
	v.match_ref = match_ref
	match_ref.add_child(v)
	v.start(match_ref.map.center())
	return v


func _ground(p: Vector3) -> Vector3:
	var space := match_ref.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 30.0, Layers.WORLD)
	var r := space.intersect_ray(q)
	return r["position"] if not r.is_empty() else p


func _aim_point(s: Soldier) -> Vector3:
	if not s.is_player:
		return _bot_target_pos(s)
	var space := match_ref.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(s.aim_origin(), s.aim_origin() + s.aim_direction() * 250.0, Layers.WORLD)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		return r["position"]
	return _ground(s.global_position - s.global_basis.z * 40.0)


func _bot_target_pos(s: Soldier) -> Vector3:
	var enemies: Array = []
	for o: Soldier in match_ref.soldiers:
		if o.alive and match_ref.are_enemies(s, o):
			enemies.append(o)
	if enemies.is_empty():
		return match_ref.map.random_hotspot()
	var t: Soldier = enemies[randi() % enemies.size()]
	return t.global_position


func _delayed_strike(s: Soldier, pos: Vector3, delay: float, id: String, radius: float, dmg: float) -> void:
	var t := get_tree().create_timer(delay, false)
	t.timeout.connect(func() -> void:
		if match_ref.ended:
			return
		var p := _ground(pos)
		Equipment.explode(match_ref, p + Vector3.UP * 0.3, radius, dmg, s if is_instance_valid(s) else null, id, id, radius > 8.0))


func _call_crate(s: Soldier) -> void:
	var drop := _ground(s.global_position - s.global_basis.z * 3.0)
	var heli := _spawn_air(s, "transport", 14.0)
	heli.deliver(drop)
	if _friendly(s):
		match_ref.hud_popup("SUPPLY CRATE INBOUND", Color(0.5, 0.9, 1.0))
		if s.is_player:
			Sfx.play_2d("vo_crate", 0.0)
	var t := get_tree().create_timer(5.0, false)
	t.timeout.connect(func() -> void:
		if match_ref.ended:
			return
		var c := SupplyCrate.new()
		c.owner_soldier = s
		c.match_ref = match_ref
		match_ref.add_child(c)
		c.global_position = drop + Vector3.UP * 25.0
		c.target_y = drop.y
		crates.append(c))


## Random reward from a supply crate.
func crate_reward() -> String:
	var pool := [["pulse_scan", 20], ["jammer", 14], ["mortar_strike", 14], ["sentry_post", 14],
		["strafing_run", 10], ["hunter_drone", 8], ["escort_chopper", 6], ["deep_scan", 6], ["ammo", 12], ["overwatch_gunship", 2]]
	var total := 0
	for p in pool:
		total += p[1]
	var r := randi() % total
	for p in pool:
		r -= p[1]
		if r < 0:
			return p[0]
	return "pulse_scan"


func bot_crate_goal(s: Soldier) -> Variant:
	for c in crates:
		if is_instance_valid(c) and c.landed and c.owner_soldier == s and c.global_position.distance_to(s.global_position) < 40.0:
			return c.global_position
	return null


# --- Intel queries ------------------------------------------------------------

func uav_level(team: int) -> int:
	if is_blacked_out(team):
		return 0
	var now := _now()
	if _deep.get(team, 0.0) > now:
		return 2
	if _uav.get(team, 0.0) > now:
		return 1
	return 0


func enemy_uav(team: int) -> bool:
	var now := _now()
	for t in _uav:
		if t != team and _uav[t] > now:
			return true
	for t in _deep:
		if t != team and _deep[t] > now:
			return true
	return false


func is_jammed(team: int) -> bool:
	return _jam.get(team, 0.0) > _now()


func is_blacked_out(team: int) -> bool:
	return _blackout.get(team, 0.0) > _now()


func cancel_uav(team: int) -> void:
	_uav[team] = 0.0
	_deep[team] = 0.0


func cancel_jam_by(team: int) -> void:
	for t in _teams_against(team):
		_jam[t] = 0.0


func hud_markers(_viewer: Soldier) -> Array:
	var out: Array = []
	for c in crates:
		if is_instance_valid(c) and c.landed:
			out.append({"label": "▣", "pos": c.global_position, "color": Color(1.0, 0.85, 0.3)})
	return out


func _process(delta: float) -> void:
	crates = crates.filter(func(c) -> bool: return is_instance_valid(c))
	if _doomsday_t >= 0.0:
		var before := ceili(_doomsday_t)
		_doomsday_t -= delta
		if ceili(_doomsday_t) != before and _doomsday_t > 0.0:
			match_ref.hud_banner("DOOMSDAY  %d" % ceili(_doomsday_t), "", Color(1, 0.3, 0.2), 1.1)
			Sfx.play_2d("ui_tick", 0.0)
		if _doomsday_t <= 0.0:
			_doomsday_t = -1.0
			_detonate_doomsday()


func _detonate_doomsday() -> void:
	Sfx.play_2d("explosion_big", 6.0, 0.6)
	var flash := CanvasLayer.new()
	flash.layer = 40
	var rect := ColorRect.new()
	rect.color = Color(1, 0.95, 0.85, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.add_child(rect)
	match_ref.add_child(flash)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 3.5)
	for s: Soldier in match_ref.soldiers:
		if s.alive:
			s.add_shake(2.0)
			var info := DamageInfo.new()
			info.attacker = _doomsday_owner if is_instance_valid(_doomsday_owner) else null
			info.weapon_id = "doomsday"
			info.streak = "doomsday"
			info.amount = 10000.0
			info.explosive = true
			if s.team == _doomsday_team:
				info.attacker = null
			s.take_damage(info)
	var team := _doomsday_team
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void: match_ref.end_match(team))

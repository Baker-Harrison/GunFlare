class_name Hud
extends CanvasLayer
## In-match HUD. Mostly custom-drawn for crisp, fast updates.

const GREEN := Color(0.55, 1.0, 0.45)
const RED := Color(1.0, 0.32, 0.28)
const WHITE := Color(1, 1, 1)
const DIM := Color(1, 1, 1, 0.55)
const YELLOW := Color(1.0, 0.85, 0.3)
const MINIMAP_SIZE := 230.0
const MINIMAP_RANGE := 55.0 # metres from centre to edge

var player: PlayerController
var font: Font
var font_bold: Font
var canvas: Control
var _hit_t := 0.0
var _hit_kill := false
var _hit_head := false
var _damage_dirs: Array = [] # [{angle, t}]
var _killfeed: Array = [] # [{text parts, t}]
var _popups: Array = [] # [{text, t, color}]
var _xp_total := 0
var _xp_t := 0.0
var _xp_reason := ""
var _banner := ""
var _banner_sub := ""
var _banner_color := YELLOW
var _banner_t := 0.0
var _red_dots: Dictionary = {} # soldier -> time last seen
var _show_scoreboard := false
var _respawn_text := ""
var _interact_text := ""
var _interact_progress := -1.0
var _death_info := ""
var _flash_rect: ColorRect
var _fps_label: Label


func _ready() -> void:
	layer = 5
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Arial Narrow", "Segoe UI", "Sans-Serif"])
	sf.font_weight = 500
	font = sf
	var bf := SystemFont.new()
	bf.font_names = sf.font_names
	bf.font_weight = 700
	font_bold = bf
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	var s := player.soldier
	s.hit_confirmed.connect(_on_hit_confirmed)
	s.damaged.connect(_on_damaged)
	Progression.xp_gained.connect(_on_xp)


func _on_hit_confirmed(_target: Node, info: DamageInfo, killed: bool) -> void:
	_hit_t = 0.25 if not killed else 0.45
	_hit_kill = killed
	_hit_head = info.headshot
	Sfx.play_2d("hitmarker", -4.0 if not killed else -1.0, 1.0 if not killed else 0.85)


func _on_damaged(info: DamageInfo) -> void:
	var s := player.soldier
	var from := info.position - info.direction * 5.0
	if info.attacker and is_instance_valid(info.attacker) and info.attacker is Node3D:
		from = (info.attacker as Node3D).global_position
	var to := from - s.global_position
	var fwd := -s.global_basis.z
	var ang := atan2(to.x * fwd.z - to.z * fwd.x, to.x * fwd.x + to.z * fwd.z)
	_damage_dirs.append({"angle": ang, "t": 1.5})
	Sfx.play_2d("hurt", -8.0, randf_range(0.9, 1.1))


func _on_xp(amount: int, reason: String) -> void:
	if player.soldier.match_ref == null or not player.soldier.match_ref.get("in_progress"):
		return
	if _xp_t <= 0.0:
		_xp_total = 0
	_xp_total += amount
	_xp_t = 2.0
	_xp_reason = reason


func add_killfeed(killer: String, killer_color: Color, weapon: String, victim: String, victim_color: Color, headshot: bool) -> void:
	_killfeed.append({"k": killer, "kc": killer_color, "w": weapon + (" [HS]" if headshot else ""), "v": victim, "vc": victim_color, "t": 6.0})
	if _killfeed.size() > 6:
		_killfeed.pop_front()


func banner(title: String, sub := "", color := YELLOW, duration := 3.0) -> void:
	_banner = title
	_banner_sub = sub
	_banner_color = color
	_banner_t = duration


func popup(text: String, color := WHITE) -> void:
	_popups.append({"text": text, "t": 1.6, "color": color})
	if _popups.size() > 4:
		_popups.pop_front()


func set_respawn_text(t: String) -> void:
	_respawn_text = t


func set_death_info(t: String) -> void:
	_death_info = t


func set_interact(text: String, progress := -1.0) -> void:
	_interact_text = text
	_interact_progress = progress


func _process(delta: float) -> void:
	var s := player.soldier
	_hit_t = maxf(_hit_t - delta, 0.0)
	_xp_t = maxf(_xp_t - delta, 0.0)
	_banner_t = maxf(_banner_t - delta, 0.0)
	for d in _damage_dirs:
		d["t"] -= delta
	_damage_dirs = _damage_dirs.filter(func(d: Dictionary) -> bool: return d["t"] > 0.0)
	for k in _killfeed:
		k["t"] -= delta
	_killfeed = _killfeed.filter(func(k: Dictionary) -> bool: return k["t"] > 0.0)
	for p in _popups:
		p["t"] -= delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["t"] > 0.0)
	_show_scoreboard = Input.is_action_pressed("scoreboard")
	_flash_rect.color = Color(1, 1, 1, clampf(s.flash_amount * 1.4, 0.0, 1.0))
	canvas.queue_redraw()


# --- Drawing -----------------------------------------------------------------

func _text(pos: Vector2, t: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, bold := false, shadow := true) -> void:
	var f := font_bold if bold else font
	if shadow:
		canvas.draw_string(f, pos + Vector2(1.5, 1.5), t, align, width, size, Color(0, 0, 0, color.a * 0.7))
	canvas.draw_string(f, pos, t, align, width, size, color)


func _draw_hud() -> void:
	var s := player.soldier
	var vp := canvas.size
	var c := vp * 0.5
	var m := s.match_ref
	if s.alive:
		_draw_damage_vignette(vp, s)
		var w := s.weapon()
		if w and w.is_scoped() and s.ads > 0.92:
			_draw_scope(vp, w)
		elif w and s.ads < 0.5 and not s.sprinting:
			_draw_crosshair(c, s)
		_draw_hitmarker(c)
		_draw_damage_dirs(c)
		_draw_ammo(vp, s)
		_draw_minimap(s, m)
		_draw_streaks(vp, s, m)
		_draw_name_tags(s)
		if w and w.has("pulse_tracker"):
			_draw_pulse_tracker(vp, s)
		if s.downed:
			_text(Vector2(0, vp.y * 0.7), "DOWNED  %.0f" % s.downed_timer, 30, RED, HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
	else:
		_text(Vector2(0, vp.y * 0.72), _death_info, 26, WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
		_text(Vector2(0, vp.y * 0.72 + 36), _respawn_text, 20, DIM, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	_draw_score(vp, m)
	_draw_killfeed(vp)
	_draw_center_messages(vp)
	if _interact_text != "":
		_text(Vector2(0, c.y + 90), _interact_text, 20, WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		if _interact_progress >= 0.0:
			var bw := 220.0
			canvas.draw_rect(Rect2(c.x - bw * 0.5, c.y + 102, bw, 8), Color(0, 0, 0, 0.6))
			canvas.draw_rect(Rect2(c.x - bw * 0.5, c.y + 102, bw * _interact_progress, 8), WHITE)
	if _show_scoreboard and m:
		_draw_scoreboard(vp, m)
	if Settings.get_value("show_fps"):
		_text(Vector2(vp.x - 90, 20), "%d FPS" % Engine.get_frames_per_second(), 14, DIM)


func _draw_crosshair(c: Vector2, s: Soldier) -> void:
	var deg := s.spread_degrees()
	var cam := player.camera
	var px := tan(deg_to_rad(deg)) / tan(deg_to_rad(cam.fov * 0.5)) * canvas.size.y * 0.5
	var gap := clampf(px, 4.0, 160.0)
	var len := 10.0
	var col := Color(1, 1, 1, 0.85)
	# Turn red over enemies.
	if _aiming_at_enemy(s):
		col = Color(1.0, 0.3, 0.25, 0.95)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var a: Vector2 = c + d * gap
		var b: Vector2 = c + d * (gap + len)
		canvas.draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.5), 2.0)
		canvas.draw_line(a, b, col, 2.0)
	canvas.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)


func _aiming_at_enemy(s: Soldier) -> bool:
	var space := s.get_world_3d().direct_space_state
	var from := s.aim_origin()
	var q := PhysicsRayQueryParameters3D.create(from, from + s.aim_direction() * 120.0, Layers.WORLD | Layers.HITBOX, [s.get_rid()])
	q.collide_with_areas = true
	var r := space.intersect_ray(q)
	if r.is_empty():
		return false
	var col: Object = r["collider"]
	if col is Area3D and col.has_meta("soldier"):
		var t: Soldier = col.get_meta("soldier")
		return t != s and s.is_enemy(t) and t.alive and not (t.has_perk("ghostline") and t.has_elite("ghostline"))
	return false


func _draw_hitmarker(c: Vector2) -> void:
	if _hit_t <= 0.0:
		return
	var a := clampf(_hit_t / 0.25, 0.0, 1.0)
	var col := Color(1, 1, 1, a) if not _hit_kill else Color(1, 0.25, 0.2, a)
	var r0 := 8.0
	var r1 := 18.0 if not _hit_kill else 24.0
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		canvas.draw_line(c + n * r0, c + n * r1, Color(0, 0, 0, a * 0.5), 4.0)
		canvas.draw_line(c + n * r0, c + n * r1, col, 2.5)


func _draw_damage_dirs(c: Vector2) -> void:
	for d: Dictionary in _damage_dirs:
		var a := clampf(d["t"] / 1.5, 0.0, 1.0)
		var ang: float = d["angle"]
		var center_ang := -PI * 0.5 - ang
		canvas.draw_arc(c, 150.0, center_ang - 0.25, center_ang + 0.25, 16, Color(1, 0.15, 0.1, a * 0.85), 9.0, true)


func _draw_damage_vignette(vp: Vector2, s: Soldier) -> void:
	var hurt := 1.0 - clampf(s.health / Soldier.MAX_HEALTH, 0.0, 1.0)
	if hurt < 0.05:
		return
	var a := hurt * 0.65
	var steps := 10
	for i in steps:
		var f := float(i) / steps
		var inset := f * 120.0
		var col := Color(0.6, 0.0, 0.0, a * (1.0 - f) * 0.35)
		canvas.draw_rect(Rect2(inset, inset, vp.x - inset * 2, vp.y - inset * 2), col, false, 24.0)


func _draw_scope(vp: Vector2, w: WeaponState) -> void:
	var c := vp * 0.5
	var r := vp.y * 0.46
	var black := Color(0, 0, 0, 1)
	canvas.draw_rect(Rect2(0, 0, c.x - r, vp.y), black)
	canvas.draw_rect(Rect2(c.x + r, 0, vp.x - c.x - r, vp.y), black)
	# Ring mask approximation
	for i in 40:
		var f := float(i) / 40.0
		canvas.draw_arc(c, r + f * r * 0.8, 0, TAU, 96, black, r * 0.03, false)
	canvas.draw_arc(c, r, 0, TAU, 128, Color(0, 0, 0, 1), 6.0, true)
	var thermal := w.optic() == "thermal"
	var col := Color(0, 0, 0, 0.9) if not thermal else Color(1, 1, 1, 0.8)
	canvas.draw_line(Vector2(c.x - r, c.y), Vector2(c.x - 30, c.y), col, 3.0)
	canvas.draw_line(Vector2(c.x + 30, c.y), Vector2(c.x + r, c.y), col, 3.0)
	canvas.draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y - 30), col, 3.0)
	canvas.draw_line(Vector2(c.x, c.y + 30), Vector2(c.x, c.y + r), col, 3.0)
	canvas.draw_line(Vector2(c.x - 30, c.y), Vector2(c.x + 30, c.y), col, 1.0)
	canvas.draw_line(Vector2(c.x, c.y - 30), Vector2(c.x, c.y + 30), col, 1.0)
	for i in range(1, 5):
		var y := c.y + i * 22.0
		canvas.draw_line(Vector2(c.x - 8, y), Vector2(c.x + 8, y), col, 1.0)
	if player.viewmodel.hold_breath:
		_text(Vector2(0, c.y + r * 0.6), "HOLDING BREATH", 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_ammo(vp: Vector2, s: Soldier) -> void:
	var w := s.weapon()
	if w == null:
		return
	var right := vp.x - 40.0
	var base := vp.y - 40.0
	var low := w.current_ammo() <= int(w.current_mag_size() * 0.25)
	var ammo_col := RED if low else WHITE
	_text(Vector2(right - 300, base - 40), "%d" % w.current_ammo(), 52, ammo_col, HORIZONTAL_ALIGNMENT_RIGHT, 230, true)
	_text(Vector2(right - 66, base - 40), "/ %d" % w.current_reserve(), 24, DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	var nm := w.data.display_name
	if w.alt_mode:
		nm += "  [" + ("GRENADE LAUNCHER" if w.has("underbarrel_gl") else "SHOTGUN") + "]"
	_text(Vector2(right - 500, base), nm.to_upper(), 18, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 500, true)
	# Bullet tick row
	var n := mini(w.current_mag_size(), 60)
	var shown := mini(w.current_ammo(), n)
	var bw := 3.0
	var gap := 2.0
	var start_x := right - n * (bw + gap)
	for i in n:
		var col := Color(1, 1, 1, 0.85) if i >= n - shown else Color(1, 1, 1, 0.15)
		canvas.draw_rect(Rect2(start_x + i * (bw + gap), base - 104, bw, 12), col)
	if w.reloading:
		_text(Vector2(0, vp.y * 0.62), "RELOADING", 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
	elif w.current_ammo() == 0 and w.current_reserve() > 0:
		_text(Vector2(0, vp.y * 0.62), "PRESS R TO RELOAD", 18, YELLOW, HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
	elif w.is_empty():
		_text(Vector2(0, vp.y * 0.62), "NO AMMO", 18, RED, HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
	# Equipment
	var lethal := ContentDB.get_item(s.loadout.get("lethal", ""))
	var tactical := ContentDB.get_item(s.loadout.get("tactical", ""))
	var eq := ""
	if lethal:
		eq += "%s x%d" % [lethal.display_name, s.lethal_count]
	if tactical:
		eq += "     %s x%d" % [tactical.display_name, s.tactical_count]
	_text(Vector2(right - 500, base + 24), eq, 15, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 500)
	# Health bar (subtle)
	if s.health < Soldier.MAX_HEALTH:
		var hw := 180.0
		canvas.draw_rect(Rect2(vp.x * 0.5 - hw * 0.5, vp.y - 30, hw, 5), Color(0, 0, 0, 0.5))
		canvas.draw_rect(Rect2(vp.x * 0.5 - hw * 0.5, vp.y - 30, hw * s.health / Soldier.MAX_HEALTH, 5), Color(1, 1, 1, 0.8))


func _draw_minimap(s: Soldier, m: Node) -> void:
	var origin := Vector2(24, 24)
	var size := MINIMAP_SIZE
	var center := origin + Vector2(size, size) * 0.5
	var rect := Rect2(origin, Vector2(size, size))
	var jammed: bool = m != null and m.has_method("is_jammed") and m.is_jammed(s)
	var blackout: bool = m != null and m.has_method("is_blacked_out") and m.is_blacked_out(s)
	canvas.draw_rect(rect, Color(0.05, 0.07, 0.06, 0.72))
	canvas.draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.5)
	if blackout:
		_text(origin + Vector2(0, size * 0.5), "NO SIGNAL", 18, RED, HORIZONTAL_ALIGNMENT_CENTER, size, true)
		return
	if jammed:
		for i in 140:
			var p := origin + Vector2(randf() * size, randf() * size)
			canvas.draw_rect(Rect2(p, Vector2(3, 3)), Color(1, 1, 1, randf() * 0.4))
		_text(origin + Vector2(0, size + 18), "JAMMED", 14, RED, HORIZONTAL_ALIGNMENT_CENTER, size, true)
		return
	var scale := size * 0.5 / MINIMAP_RANGE
	var yaw := s.yaw
	var me := Vector2(s.global_position.x, s.global_position.z)
	var to_map := func(world: Vector2) -> Vector2:
		var d := (world - me).rotated(yaw)
		return center + d * scale
	# Buildings / walls
	if m and m.get("map") and m.map.get("minimap_rects"):
		for r: Rect2 in m.map.minimap_rects:
			var corners := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
			var pts := PackedVector2Array()
			var inside := false
			for cpt: Vector2 in corners:
				var p: Vector2 = to_map.call(cpt)
				pts.append(p)
				if rect.grow(60).has_point(p):
					inside = true
			if inside:
				_draw_clipped_poly(pts, rect, Color(0.55, 0.6, 0.55, 0.45))
	# Objectives
	if m and m.has_method("hud_objectives"):
		for o: Dictionary in m.hud_objectives(s):
			var p: Vector2 = to_map.call(Vector2(o["pos"].x, o["pos"].z))
			p = Vector2(clampf(p.x, rect.position.x + 8, rect.end.x - 8), clampf(p.y, rect.position.y + 8, rect.end.y - 8))
			canvas.draw_circle(p, 9.0, Color(0, 0, 0, 0.6))
			_text(p + Vector2(-8, 6), o["label"], 15, o["color"], HORIZONTAL_ALIGNMENT_CENTER, 16, true, false)
	# Soldiers
	var now := Time.get_ticks_msec() / 1000.0
	var uav: int = m.uav_level(s) if m and m.has_method("uav_level") else 0
	for o: Soldier in s.get_tree().get_nodes_in_group("soldiers"):
		if o == s or not o.alive:
			continue
		var p: Vector2 = to_map.call(Vector2(o.global_position.x, o.global_position.z))
		if not rect.has_point(p):
			continue
		if not s.is_enemy(o):
			canvas.draw_circle(p, 4.0, Color(0.4, 0.85, 1.0))
			continue
		var visible := false
		var alpha := 1.0
		if now - o.last_unsuppressed_shot < 2.0:
			visible = true
			alpha = 1.0 - (now - o.last_unsuppressed_shot) / 2.0
		if uav > 0 and not o.has_perk("ghostline"):
			visible = true
			alpha = 1.0
		if visible:
			canvas.draw_circle(p, 4.5, Color(1.0, 0.2, 0.15, alpha))
			if uav >= 2:
				var f := Vector2(0, -1).rotated(-(o.yaw - yaw))
				canvas.draw_line(p, p + f * 9.0, Color(1, 0.2, 0.15, alpha), 2.0)
	# Me
	var tri := PackedVector2Array([center + Vector2(0, -8), center + Vector2(-5.5, 6), center + Vector2(5.5, 6)])
	canvas.draw_colored_polygon(tri, YELLOW)
	if uav > 0:
		_text(origin + Vector2(6, size + 18), "PULSE SCAN ACTIVE" if uav == 1 else "DEEP SCAN ACTIVE", 13, GREEN, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	if m and m.has_method("enemy_uav_active") and m.enemy_uav_active(s):
		_text(origin + Vector2(6, size + 34), "ENEMY PULSE SCAN", 13, RED, HORIZONTAL_ALIGNMENT_LEFT, -1, true)


func _draw_clipped_poly(pts: PackedVector2Array, clip: Rect2, col: Color) -> void:
	var clipped := Geometry2D.intersect_polygons(pts, PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)]))
	for poly in clipped:
		if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
			canvas.draw_colored_polygon(poly, col)


func _draw_streaks(vp: Vector2, s: Soldier, m: Node) -> void:
	var ids: Array = s.loadout.get("streaks", Progression.selected_streaks) if s.is_player else []
	if ids.is_empty():
		ids = Progression.selected_streaks
	var x := vp.x - 70.0
	var y := vp.y * 0.36
	var shortcut := 1 if s.has_perk("shortcut") else 0
	for i in ids.size():
		var st := ContentDB.get_item(ids[ids.size() - 1 - i]) as StreakData
		if st == null:
			continue
		var need := maxi(st.count - shortcut, 1)
		var reached := s.kills_this_life >= need
		var col := GREEN if reached else Color(1, 1, 1, 0.4)
		_text(Vector2(x - 300, y + i * 46), st.display_name.to_upper(), 15, col, HORIZONTAL_ALIGNMENT_RIGHT, 290, true)
		_text(Vector2(x, y + i * 46), str(need), 20, col, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	if not s.streak_inventory.is_empty():
		var idx := clampi(s.streak_index, 0, s.streak_inventory.size() - 1)
		var cur := ContentDB.get_item(s.streak_inventory[idx])
		if cur:
			var label := "[4] %s" % cur.display_name.to_upper()
			if s.streak_inventory.size() > 1:
				label += "   (%d/%d  [5] next)" % [idx + 1, s.streak_inventory.size()]
			_text(Vector2(x - 500, y + ids.size() * 46 + 10), label, 17, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT, 540, true)
	# Kill streak counter
	_text(Vector2(x - 300, y - 30), "STREAK %d" % s.kills_this_life, 14, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 330)


func _draw_name_tags(s: Soldier) -> void:
	var cam := player.camera
	for o: Soldier in s.get_tree().get_nodes_in_group("soldiers"):
		if o == s or not o.alive:
			continue
		var head := o.head_position() + Vector3.UP * 0.35
		if cam.is_position_behind(head):
			continue
		var dist := cam.global_position.distance_to(head)
		if not s.is_enemy(o):
			if dist > 60.0:
				continue
			var p := cam.unproject_position(head)
			_text(p + Vector2(-100, 0), o.display_name, 14, Color(0.45, 0.9, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 200, true)


func _draw_pulse_tracker(vp: Vector2, s: Soldier) -> void:
	var c := Vector2(vp.x * 0.5, vp.y - 120)
	var r := 70.0
	canvas.draw_arc(c, r, PI, TAU, 32, Color(0.3, 1.0, 0.4, 0.5), 2.0)
	var t := fmod(Time.get_ticks_msec() / 1000.0, 3.0)
	if t < 0.25:
		canvas.draw_arc(c, r * (t / 0.25), PI, TAU, 32, Color(0.3, 1.0, 0.4, 0.4), 2.0)
	for o: Soldier in s.get_tree().get_nodes_in_group("soldiers"):
		if o == s or not o.alive or not s.is_enemy(o) or o.has_perk("ghostline"):
			continue
		var d := o.global_position - s.global_position
		if d.length() > 30.0:
			continue
		var local := Vector2(d.x, d.z).rotated(s.yaw)
		if local.y > 0:
			continue
		var p := c + local / 30.0 * r
		canvas.draw_circle(p, 4.0, Color(1, 0.25, 0.2, 0.9 - t * 0.25))


func _draw_score(vp: Vector2, m: Node) -> void:
	if m == null or not m.has_method("hud_score"):
		return
	var sc: Dictionary = m.hud_score(player.soldier)
	var x := 24.0
	var y := MINIMAP_SIZE + 70.0
	_text(Vector2(x, y), sc.get("time", ""), 22, WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	_text(Vector2(x + 90, y), sc.get("mode", ""), 14, DIM)
	var limit: int = sc.get("limit", 1)
	var bars: Array = sc.get("bars", [])
	for i in bars.size():
		var b: Dictionary = bars[i]
		var by := y + 16 + i * 26
		var frac := clampf(float(b["score"]) / maxf(limit, 1), 0.0, 1.0)
		canvas.draw_rect(Rect2(x, by, MINIMAP_SIZE, 18), Color(0, 0, 0, 0.5))
		canvas.draw_rect(Rect2(x, by, MINIMAP_SIZE * frac, 18), b["color"] * Color(1, 1, 1, 0.75))
		_text(Vector2(x + 6, by + 14), "%s  %d" % [b["name"], b["score"]], 14, WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, true)


func _draw_killfeed(vp: Vector2) -> void:
	var y := 40.0
	for k: Dictionary in _killfeed:
		var a := clampf(k["t"], 0.0, 1.0)
		var line := "%s   [%s]   %s" % [k["k"], k["w"], k["v"]]
		var x := vp.x - 30.0
		var wv := font.get_string_size(k["v"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var ww := font.get_string_size("   [%s]   " % k["w"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var wk := font.get_string_size(k["k"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var kc: Color = k["kc"]
		var vc: Color = k["vc"]
		_text(Vector2(x - wv, y), k["v"], 16, Color(vc.r, vc.g, vc.b, a), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		_text(Vector2(x - wv - ww, y), "   [%s]   " % k["w"], 16, Color(1, 1, 1, 0.8 * a))
		_text(Vector2(x - wv - ww - wk, y), k["k"], 16, Color(kc.r, kc.g, kc.b, a), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		y += 24.0


func _draw_center_messages(vp: Vector2) -> void:
	var c := vp * 0.5
	if _xp_t > 0.0:
		var a := clampf(_xp_t, 0.0, 1.0)
		_text(Vector2(c.x + 30, c.y - 40), "+%d" % _xp_total, 26, Color(1.0, 0.9, 0.4, a), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		if _xp_reason != "" and _xp_reason != "kill":
			_text(Vector2(c.x + 30, c.y - 18), _xp_reason.to_upper(), 14, Color(1, 1, 1, a * 0.8))
	var py := c.y - 140.0
	for p: Dictionary in _popups:
		var col: Color = p["color"]
		col.a = clampf(p["t"], 0.0, 1.0)
		_text(Vector2(0, py), p["text"], 22, col, HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
		py -= 30.0
	if _banner_t > 0.0:
		var a := clampf(_banner_t, 0.0, 1.0)
		var col := _banner_color
		col.a = a
		_text(Vector2(0, vp.y * 0.22), _banner, 44, col, HORIZONTAL_ALIGNMENT_CENTER, vp.x, true)
		if _banner_sub != "":
			_text(Vector2(0, vp.y * 0.22 + 36), _banner_sub, 20, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_scoreboard(vp: Vector2, m: Node) -> void:
	if not m.has_method("scoreboard_rows"):
		return
	var data: Dictionary = m.scoreboard_rows()
	var w := 900.0
	var x := vp.x * 0.5 - w * 0.5
	var y := 110.0
	var teams: Array = data["teams"]
	var h := 60.0 + teams.size() * 40.0
	for t: Dictionary in teams:
		h += t["rows"].size() * 28.0
	canvas.draw_rect(Rect2(x - 10, y - 40, w + 20, h + 20), Color(0, 0, 0, 0.75))
	_text(Vector2(x, y - 10), data.get("title", ""), 24, WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var cols := ["SCORE", "KILLS", "DEATHS", "ASSISTS", "PING"]
	for t: Dictionary in teams:
		y += 30.0
		_text(Vector2(x, y), "%s   %d" % [t["name"], t["score"]], 20, t["color"], HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		for i in cols.size():
			_text(Vector2(x + 440 + i * 92, y), cols[i], 13, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 80)
		y += 8.0
		for r: Dictionary in t["rows"]:
			y += 28.0
			var col := YELLOW if r.get("me", false) else WHITE
			if r.get("me", false):
				canvas.draw_rect(Rect2(x - 4, y - 20, w + 8, 26), Color(1, 1, 1, 0.08))
			var dead_mark := "" if r.get("alive", true) else "  †"
			_text(Vector2(x, y), "%s  %s%s" % [r["rank"], r["name"], dead_mark], 17, col)
			var vals := [r["score"], r["kills"], r["deaths"], r["assists"], r["ping"]]
			for i in vals.size():
				_text(Vector2(x + 440 + i * 92, y), str(vals[i]), 17, col, HORIZONTAL_ALIGNMENT_RIGHT, 80)

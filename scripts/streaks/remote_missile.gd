class_name RemoteMissile
extends Node3D
## Player-guided mortar shell: view from the shell as it falls, steer with the
## mouse, click to boost. Explodes on impact.

var owner_soldier: Soldier
var match_ref: Match
var _cam: Camera3D
var _vel := Vector3.ZERO
var _boost := false
var _yaw := 0.0
var _pitch := -1.2
var _overlay: Control
var _layer: CanvasLayer
var _done := false
var _life := 14.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var c := match_ref.map.center()
	var from_dir := (c - owner_soldier.global_position)
	from_dir.y = 0.0
	global_position = c - from_dir.normalized() * 50.0 + Vector3.UP * 110.0
	_yaw = atan2(-from_dir.x, -from_dir.z)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 1500.0
	add_child(_cam)
	_cam.current = true
	_layer = CanvasLayer.new()
	_layer.layer = 8
	add_child(_layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_layer.add_child(_overlay)
	owner_soldier.controller.enabled = false
	owner_soldier.controller.hud.visible = false
	Sfx.play_2d("rocket_loop", -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.002
		_pitch = clampf(_pitch - event.relative.y * 0.002, -1.5, -0.6)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_boost = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	var dir := Basis.from_euler(Vector3(_pitch, _yaw, 0)) * Vector3.FORWARD
	var speed := 38.0 if not _boost else 110.0
	_vel = dir * speed
	var from := global_position
	var to := from + _vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.HITBOX)
	q.collide_with_areas = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() or _life <= 0.0 or not owner_soldier.alive:
		_explode(r["position"] if not r.is_empty() else from)
		return
	global_position = to
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0)), global_position)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var vp := _overlay.size
	var c := vp * 0.5
	var col := Color(1, 1, 1, 0.8)
	_overlay.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.1, 0.12, 0.1, 0.25))
	_overlay.draw_arc(c, 60, 0, TAU, 48, col, 2.0)
	_overlay.draw_line(c - Vector2(120, 0), c - Vector2(60, 0), col, 2.0)
	_overlay.draw_line(c + Vector2(60, 0), c + Vector2(120, 0), col, 2.0)
	_overlay.draw_line(c - Vector2(0, 120), c - Vector2(0, 60), col, 2.0)
	_overlay.draw_line(c + Vector2(0, 60), c + Vector2(0, 120), col, 2.0)
	# Mark enemies (friendly ones in blue) on screen.
	for s: Soldier in match_ref.soldiers:
		if not s.alive or _cam.is_position_behind(s.global_position):
			continue
		var p := _cam.unproject_position(s.global_position + Vector3.UP)
		var enemy := match_ref.are_enemies(owner_soldier, s)
		if enemy and s.has_perk("ghostline"):
			continue
		var cc := Color(1, 0.25, 0.2) if enemy else Color(0.4, 0.8, 1.0)
		_overlay.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), cc, false, 2.0)
	var alt := global_position.y - match_ref.map.center().y
	_overlay.draw_string(ThemeDB.fallback_font, Vector2(40, vp.y - 60), "ALT %dm   %s" % [int(alt), "BOOST" if _boost else "[LMB] BOOST"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)


func _explode(pos: Vector3) -> void:
	_done = true
	Equipment.explode(match_ref, pos + Vector3.UP * 0.3, 10.0, 400.0, owner_soldier, "mortar_strike", "mortar_strike", true)
	if is_instance_valid(owner_soldier) and owner_soldier.controller:
		owner_soldier.controller.enabled = true
		owner_soldier.controller.hud.visible = true
		owner_soldier.controller.camera.current = true
	queue_free()

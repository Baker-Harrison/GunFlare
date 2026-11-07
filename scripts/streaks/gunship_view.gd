class_name GunshipView
extends Node3D
## Player control of the Overwatch Gunship: thermal view from the orbiting
## aircraft, three cannons (105mm, 40mm, 25mm) switched with 1/2/3 or scroll.

const WEAPONS := [
	{"cal": 105, "name": "105mm", "reload": 4.0, "fov": 55.0},
	{"cal": 40, "name": "40mm", "reload": 0.9, "fov": 35.0},
	{"cal": 25, "name": "25mm", "reload": 0.07, "fov": 22.0},
]

var gunship: AirVehicle
var owner_soldier: Soldier
var match_ref: Match
var _cam: Camera3D
var _layer: CanvasLayer
var _overlay: Control
var _thermal: ColorRect
var _yaw := 0.0
var _pitch := -1.1
var _weapon := 0
var _cd := [0.0, 0.0, 0.0]
var _firing := false


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.far = 1500.0
	add_child(_cam)
	_cam.current = true
	_layer = CanvasLayer.new()
	_layer.layer = 8
	add_child(_layer)
	_thermal = ColorRect.new()
	_thermal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thermal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear;\nvoid fragment(){ vec3 c = texture(screen_tex, SCREEN_UV).rgb; float l = dot(c, vec3(0.3,0.59,0.11)); l = pow(l, 0.8); float n = fract(sin(dot(SCREEN_UV*TIME, vec2(12.9898,78.233)))*43758.5453); COLOR = vec4(vec3(l*0.9 + n*0.06), 1.0); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_thermal.material = sm
	_layer.add_child(_thermal)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_layer.add_child(_overlay)
	owner_soldier.controller.enabled = false
	owner_soldier.controller.hud.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var f: float = WEAPONS[_weapon]["fov"] / 55.0
		_yaw -= event.relative.x * 0.002 * f
		_pitch = clampf(_pitch - event.relative.y * 0.002 * f, -1.5, -0.35)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_firing = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_weapon = (_weapon + 1) % 3
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_weapon = (_weapon + 2) % 3
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1:
				_weapon = 0
			KEY_2:
				_weapon = 1
			KEY_3:
				_weapon = 2


func _process(delta: float) -> void:
	if not is_instance_valid(gunship) or gunship._dead or not is_instance_valid(owner_soldier) or not owner_soldier.alive or match_ref.ended:
		_exit()
		return
	for i in 3:
		_cd[i] = maxf(_cd[i] - delta, 0.0)
	var c := match_ref.map.center()
	var to_center := (c - gunship.global_position)
	var base_yaw := atan2(-to_center.x, -to_center.z)
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, base_yaw + _yaw, 0)), gunship.global_position + Vector3.DOWN * 2.0)
	_cam.fov = lerpf(_cam.fov, WEAPONS[_weapon]["fov"], delta * 8.0)
	if _firing and _cd[_weapon] <= 0.0:
		_cd[_weapon] = WEAPONS[_weapon]["reload"]
		var space := get_world_3d().direct_space_state
		var from := _cam.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from - _cam.global_basis.z * 600.0, Layers.WORLD | Layers.HITBOX, [gunship.get_rid()])
		q.collide_with_areas = true
		var r := space.intersect_ray(q)
		var target: Vector3 = r["position"] if not r.is_empty() else from - _cam.global_basis.z * 200.0
		gunship.fire_cannon(target, WEAPONS[_weapon]["cal"])
		Sfx.play_2d("gun_gunship_%d" % WEAPONS[_weapon]["cal"], -2.0)
		match_ref.player_ctrl.add_shake(0.3 if _weapon == 0 else 0.1)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var vp := _overlay.size
	var c := vp * 0.5
	var col := Color(1, 1, 1, 0.85)
	var w: Dictionary = WEAPONS[_weapon]
	match _weapon:
		0:
			_overlay.draw_rect(Rect2(c - Vector2(70, 70), Vector2(140, 140)), col, false, 2.0)
			_overlay.draw_line(c - Vector2(140, 0), c - Vector2(70, 0), col, 2.0)
			_overlay.draw_line(c + Vector2(70, 0), c + Vector2(140, 0), col, 2.0)
		1:
			_overlay.draw_arc(c, 40, 0, TAU, 32, col, 2.0)
			_overlay.draw_line(c - Vector2(90, 0), c + Vector2(90, 0), col, 1.0)
			_overlay.draw_line(c - Vector2(0, 90), c + Vector2(0, 90), col, 1.0)
		2:
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				_overlay.draw_line(c + d * 10, c + d * 40, col, 2.0)
	for s: Soldier in match_ref.soldiers:
		if not s.alive or _cam.is_position_behind(s.global_position):
			continue
		var p := _cam.unproject_position(s.global_position + Vector3.UP)
		var enemy := match_ref.are_enemies(owner_soldier, s)
		if not enemy:
			# Friendlies flash with an IR strobe so you don't hit them.
			if int(Time.get_ticks_msec() / 250) % 2 == 0:
				_overlay.draw_circle(p, 4.0, Color(0.5, 0.9, 1.0))
	var font := ThemeDB.fallback_font
	_overlay.draw_string(font, Vector2(40, 60), "OVERWATCH  —  %s %s" % [w["name"], "READY" if _cd[_weapon] <= 0.0 else "RELOADING"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	_overlay.draw_string(font, Vector2(40, 90), "[1] 105mm   [2] 40mm   [3] 25mm", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
	_overlay.draw_string(font, Vector2(40, vp.y - 50), "TIME %d" % ceili(gunship.life), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)


func _exit() -> void:
	if is_instance_valid(owner_soldier) and owner_soldier.controller:
		owner_soldier.controller.enabled = true
		owner_soldier.controller.hud.visible = true
		owner_soldier.controller.camera.current = true
	queue_free()

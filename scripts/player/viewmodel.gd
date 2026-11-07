class_name Viewmodel
extends Node3D
## First-person weapon and arms. Rendered by an overlay camera (layer 2) so it
## never clips into walls. All motion is procedural: sway, bob, sprint pose,
## ADS alignment, recoil, reload, swap, melee and equipment throws.

const LAYER := 2
const HIP_OFFSET := Vector3(0.13, -0.15, -0.28)
const ADS_DISTANCE := 0.16

var soldier: Soldier
var gun: Node3D
var arms: Node3D
var _left_hand: MeshInstance3D
var _right_hand: MeshInstance3D
var _mag: Node3D
var _mag_rest := Vector3.ZERO
var _ads_marker := Vector3(0, 0.08, 0.1)
var _muzzle: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _weapon: WeaponState

var _sway := Vector2.ZERO
var _sway_target := Vector2.ZERO
var _bob_t := 0.0
var _kick := 0.0
var _kick_rot := Vector3.ZERO
var _reload_t := -1.0
var _reload_total := 1.0
var _reload_empty := false
var _swap_anim := 0.0
var _land := 0.0
var _was_on_floor := true
var _melee_anim := 0.0
var _throw_anim := 0.0
var _sprint_blend := 0.0
var _breath_t := 0.0
var hold_breath := false


func _ready() -> void:
	soldier.weapon_changed.connect(_on_weapon_changed)
	soldier.shot_fired.connect(_on_shot)
	if soldier.weapon():
		_on_weapon_changed(soldier.weapon())


func _set_layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_layer(c)


func _on_weapon_changed(w: WeaponState) -> void:
	if w == null:
		return
	if _weapon and _weapon.reload_started.is_connected(_on_reload_started):
		_weapon.reload_started.disconnect(_on_reload_started)
		_weapon.reload_finished.disconnect(_on_reload_finished)
		_weapon.shell_loaded.disconnect(_on_shell)
	_weapon = w
	w.reload_started.connect(_on_reload_started)
	w.reload_finished.connect(_on_reload_finished)
	w.shell_loaded.connect(_on_shell)
	if gun:
		gun.queue_free()
	if arms:
		arms.queue_free()
	gun = WeaponModels.create(w.data.id, w.attachments, w.camo)
	add_child(gun)
	if w.has("akimbo"):
		var second := WeaponModels.create(w.data.id, [], w.camo)
		second.name = "Akimbo"
		second.position = Vector3(-0.26, 0, 0)
		gun.add_child(second)
	_mag = gun.find_child("Mag", true, false) as Node3D
	_mag_rest = _mag.position if _mag else Vector3.ZERO
	var ads := gun.find_child("ADS", true, false) as Node3D
	_ads_marker = ads.position if ads else Vector3(0, 0.08, 0.1)
	_muzzle = gun.find_child("MuzzleTip", true, false) as Node3D
	if _muzzle == null:
		_muzzle = gun.find_child("Muzzle", true, false) as Node3D
	_build_arms()
	_build_flash()
	_set_layer(self)
	_swap_anim = 1.0
	_reload_t = -1.0


func _build_arms() -> void:
	arms = Node3D.new()
	arms.name = "Arms"
	gun.add_child(arms)
	var f: Dictionary = SoldierModel.FACTIONS[clampi(soldier.team, 0, 1)]
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = f["fatigue"]
	sleeve.roughness = 0.9
	var glove := StandardMaterial3D.new()
	glove.albedo_color = f["gloves"]
	glove.roughness = 0.7
	# Right hand on the grip, forearm running back and down out of view.
	_right_hand = _arm_piece(arms, Vector3(0.045, 0.07, 0.09), Vector3(0.0, -0.02, 0.03), glove)
	var r_fore := _arm_capsule(arms, 0.04, 0.34, Vector3(0.035, -0.08, 0.2), Vector3(-1.1, 0.25, 0.0), sleeve)
	r_fore.name = "RightForearm"
	var lh := gun.find_child("LeftHand", true, false) as Node3D
	var lpos := lh.position if lh else Vector3(0, 0.03, -0.25)
	_left_hand = _arm_piece(arms, Vector3(0.05, 0.06, 0.1), lpos + Vector3(-0.01, -0.03, 0), glove)
	_arm_capsule(arms, 0.04, 0.38, lpos + Vector3(-0.1, -0.1, 0.16), Vector3(-1.0, -0.6, 0.3), sleeve).name = "LeftForearm"


func _arm_piece(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _arm_capsule(parent: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_flash() -> void:
	if _muzzle == null:
		return
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	_flash.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _flash_texture()
	m.albedo_color = Color(1.0, 0.8, 0.5)
	_flash.material_override = m
	_flash.visible = false
	_muzzle.add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.72, 0.4)
	_flash_light.omni_range = 5.0
	_flash_light.light_energy = 0.0
	_flash_light.layers = 1 | LAYER
	_flash_light.light_cull_mask = 1 | LAYER
	_muzzle.add_child(_flash_light)


static var _flash_tex: ImageTexture


static func _flash_texture() -> ImageTexture:
	if _flash_tex:
		return _flash_tex
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := Vector2(x - s * 0.5 + 0.5, y - s * 0.5 + 0.5) / (s * 0.5)
			var d := v.length()
			var ang := atan2(v.y, v.x)
			var star := pow(absf(cos(ang * 2.5)), 6.0) * (1.0 - d)
			var a := clampf(pow(maxf(1.0 - d, 0.0), 2.5) + star * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex


func muzzle_world_position() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position


func _on_shot(w: WeaponState) -> void:
	var r := w.recoil_mult()
	var scale := clampf(w.data.recoil_vertical, 0.3, 2.5)
	_kick = minf(_kick + 0.6 + scale * 0.3, 1.6)
	_kick_rot += Vector3(deg_to_rad(1.6 * scale * r), deg_to_rad(randf_range(-0.8, 0.8) * r), deg_to_rad(randf_range(-2.0, 2.0)))
	if not w.has("suppressor") or w.alt_mode:
		_flash_t = 0.05
		if _flash:
			_flash.visible = true
			_flash.rotation.z = randf() * TAU
			var sz := randf_range(0.8, 1.3) * (1.6 if w.data.weapon_class in ["shotgun", "lmg", "sniper", "launcher"] else 1.0)
			_flash.scale = Vector3(sz, sz, sz)
		if _flash_light:
			_flash_light.light_energy = 2.5
	if w.data.fire_mode in ["bolt", "pump"] and not w.alt_mode:
		_reload_t = -2.0 # chamber animation
		_chamber_t = 0.0


var _chamber_t := -1.0


func _on_reload_started(total: float, empty: bool) -> void:
	_reload_total = maxf(total, 0.2)
	_reload_empty = empty
	_reload_t = 0.0
	Sfx.play_2d("reload_out", -6.0)


func _on_reload_finished() -> void:
	_reload_t = -1.0
	Sfx.play_2d("reload_in", -6.0)


func _on_shell() -> void:
	Sfx.play_2d("shell_in", -8.0, randf_range(0.95, 1.05))
	_reload_t = 0.0


func play_melee() -> void:
	_melee_anim = 1.0


func play_throw() -> void:
	_throw_anim = 1.0


func _process(delta: float) -> void:
	if soldier == null or gun == null:
		return
	var w := soldier.weapon()
	var ads := soldier.ads
	var speed := Vector2(soldier.velocity.x, soldier.velocity.z).length()
	var on_floor := soldier.is_on_floor()
	if on_floor and not _was_on_floor:
		_land = 1.0
	_was_on_floor = on_floor
	_land = move_toward(_land, 0.0, delta * 4.0)
	_sprint_blend = move_toward(_sprint_blend, 1.0 if soldier.sprinting else 0.0, delta * 6.0)
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	_kick_rot = _kick_rot.lerp(Vector3.ZERO, minf(delta * 14.0, 1.0))
	_swap_anim = move_toward(_swap_anim, 0.0, delta * 3.0)
	_melee_anim = move_toward(_melee_anim, 0.0, delta * 2.4)
	_throw_anim = move_toward(_throw_anim, 0.0, delta * 2.0)
	_sway = _sway.lerp(_sway_target, minf(delta * 10.0, 1.0))
	_sway_target = _sway_target.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			if _flash:
				_flash.visible = false
			if _flash_light:
				_flash_light.light_energy = 0.0
	if _reload_t >= 0.0:
		_reload_t += delta
	if _chamber_t >= 0.0:
		_chamber_t += delta
		if _chamber_t > 0.9:
			_chamber_t = -1.0

	# Bob
	if on_floor:
		_bob_t += delta * speed * (1.25 if soldier.sprinting else 1.6)
	var bob_amt := clampf(speed / 5.0, 0.0, 1.5) * lerpf(1.0, 0.12, ads)
	var bob := Vector3(sin(_bob_t) * 0.012, -absf(cos(_bob_t)) * 0.01, 0.0) * bob_amt
	if soldier.sprinting:
		bob *= 2.2

	# Base position: hip or ADS.
	var ads_pos := Vector3(0, 0, -ADS_DISTANCE) - _ads_marker
	var pos := HIP_OFFSET.lerp(ads_pos, ads)
	var rot := Vector3.ZERO
	# Breathing / idle sway, stronger when scoped and not holding breath.
	_breath_t += delta
	var breath := Vector3(sin(_breath_t * 1.1) * 0.002, sin(_breath_t * 2.2) * 0.0015, 0.0)
	pos += breath * lerpf(1.0, 0.4, ads)
	# Mouse sway lag
	rot.y += _sway.x * 0.04 * lerpf(1.0, 0.25, ads)
	rot.x += _sway.y * 0.04 * lerpf(1.0, 0.25, ads)
	rot.z += _sway.x * 0.06 * lerpf(1.0, 0.2, ads)
	pos += bob
	# Strafe lean
	var local_v := soldier.global_basis.inverse() * soldier.velocity
	rot.z += clampf(-local_v.x * 0.012, -0.06, 0.06) * (1.0 - ads)
	# Sprint
	pos += Vector3(-0.04, -0.03, 0.02) * _sprint_blend
	rot += Vector3(-0.35, 0.65, 0.25) * _sprint_blend
	# Crouch / prone dip
	if soldier.stance == Soldier.Stance.PRONE:
		pos += Vector3(0, -0.01, 0) * (1.0 - ads)
	# Landing
	pos.y -= _land * 0.03
	rot.x -= _land * 0.06
	# Recoil
	pos.z += _kick * 0.045 * lerpf(1.0, 0.6, ads)
	pos.y += _kick * 0.006
	rot += _kick_rot
	# Swap (raise from below)
	pos.y -= _swap_anim * _swap_anim * 0.25
	rot.x -= _swap_anim * 0.8
	# Melee: swing gun away left
	var m := sin(_melee_anim * PI)
	pos += Vector3(-0.12, -0.05, -0.05) * m
	rot += Vector3(0.1, 0.5, 0.6) * m
	# Throw
	var t := sin(_throw_anim * PI)
	pos += Vector3(0.05, -0.15, 0.05) * t
	rot.x -= t * 0.5
	if soldier.lethal_cook >= 0.0:
		pos += Vector3(0.05, -0.18, 0.06)
		rot.x -= 0.6
	# Reload: tilt the gun and pull the magazine.
	if _reload_t >= 0.0 and w and w.reloading:
		var f := clampf(_reload_t / _reload_total, 0.0, 1.0)
		var tilt := sin(clampf(f * 1.15, 0.0, 1.0) * PI)
		if w.shell_reload and not w.alt_mode:
			var sh := sin(clampf(_reload_t / _reload_total, 0.0, 1.0) * PI)
			rot += Vector3(0.25, -0.2, 0.55)
			pos += Vector3(-0.02, -0.03, 0.0)
			if _left_hand:
				_left_hand.position.y = -0.06 - sh * 0.06
		else:
			rot += Vector3(0.3, -0.25, 0.6) * tilt
			pos += Vector3(-0.03, -0.04, 0.02) * tilt
			if _mag:
				var out := 0.0
				if f < 0.35:
					out = f / 0.35
				elif f < 0.55:
					out = 1.0
				elif f < 0.8:
					out = 1.0 - (f - 0.55) / 0.25
				_mag.position = _mag_rest + Vector3(0, -0.25, 0.05) * out
				_mag.visible = not (f > 0.33 and f < 0.5)
	else:
		if _mag:
			_mag.position = _mag_rest
			_mag.visible = true
	if _chamber_t >= 0.0:
		var c := sin(clampf(_chamber_t / 0.9, 0.0, 1.0) * PI)
		rot += Vector3(0.1, -0.15, 0.3) * c
		pos += Vector3(0.0, -0.02, 0.02) * c
	# Hide the gun when fully scoped with a sniper scope (HUD overlay takes over).
	var scoped := w != null and w.is_scoped() and ads > 0.92
	gun.visible = not scoped
	gun.position = pos
	gun.rotation = rot


func add_mouse_sway(delta_px: Vector2) -> void:
	_sway_target += Vector2(-delta_px.x, -delta_px.y) * 0.004
	_sway_target = _sway_target.limit_length(1.5)

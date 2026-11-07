class_name TitleStage
extends MapBase
## Cinematic 3D diorama behind the main menu: a squad at a dusk staging area
## with burning barrels, drifting smoke, embers, a falling signal flare,
## distant artillery flashes and a slow, hand-held camera.

const HERO_POS := Vector3(1.25, 0.0, -0.9)

var camera: Camera3D
var _t := 0.0
var _hero: SoldierModel
var _squad: Array[SoldierModel] = []
var _fires: Array[OmniLight3D] = []
var _flare: Node3D
var _flare_light: OmniLight3D
var _flash: OmniLight3D
var _flash_t := 3.0
var _weapon_key := ""
var _cam_offset := Vector3.ZERO
var _cam_target_offset := Vector3.ZERO


func _init() -> void:
	super._init()
	size = Vector2(70, 70)


func _ready() -> void:
	build()


func build() -> void:
	begin("dusk")
	_grade_environment()
	ground("dirt", 30.0)
	_set_dressing()
	_spawn_squad()
	_spawn_fx()
	_spawn_camera()


## Low, warm backlight from behind the squad and a cool fill from the camera.
func _grade_environment() -> void:
	sun.rotation_degrees = Vector3(-9, 165, 0)
	sun.light_color = Color(1.0, 0.58, 0.32)
	sun.light_energy = 1.5
	sun.directional_shadow_max_distance = 60.0
	var env := environment_node.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color(0.09, 0.12, 0.24)
	sky.sky_horizon_color = Color(0.92, 0.42, 0.22)
	sky.ground_horizon_color = Color(0.42, 0.26, 0.2)
	sky.sun_angle_max = 14.0
	sky.sun_curve = 0.08
	env.ambient_light_energy = 0.35
	env.fog_light_color = Color(0.85, 0.48, 0.3)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.55
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -20, 0)
	fill.light_color = Color(0.45, 0.6, 0.95)
	fill.light_energy = 0.35
	add_child(fill)


func _set_dressing() -> void:
	# Container wall behind the squad.
	_container(Vector3(-6.5, 0, -9.0), PI * 0.5, "container_blue")
	_container(Vector3(-0.5, 0, -10.5), PI * 0.5 + 0.08, "container_red")
	_container(Vector3(-3.5, 2.6, -9.6), PI * 0.5 - 0.05, "container_green")
	_container(Vector3(7.5, 0, -12.0), PI * 0.5 - 0.2, "container_yellow")
	prop("water_tower", Vector3(13.0, 0, -22.0), 0.4)
	prop("car_wreck", Vector3(-9.0, 0, -3.5), 0.9)
	prop("barrier", Vector3(5.5, 0, -4.0), -0.25)
	prop("barrier", Vector3(8.2, 0, -4.6), -0.4)
	for i in 4:
		prop("sandbags", Vector3(-5.6 + i * 1.15, 0, -4.2 - absf(i - 1.5) * 0.2), 0.05 * (i - 2))
	prop("crate", Vector3(-2.2, 0, -2.6), 0.3)
	prop("crate_small", Vector3(-2.0, 1.2, -2.7), 0.7)
	prop("crate", Vector3(-3.6, 0, -2.0), -0.2)
	prop("pallets", Vector3(4.0, 0, -2.2), 0.5)
	prop("tires", Vector3(-6.5, 0, 0.5), 0.0)
	prop("barrel", Vector3(4.6, 0, -0.6), 0.0)
	prop("barrel", Vector3(-1.0, 0, -4.6), 0.0)
	prop("lamp", Vector3(-7.5, 0, -6.0), 0.6)
	for i in 6:
		prop("pine", Vector3(-28.0 + i * 11.0, 0, -34.0 - (i % 2) * 6.0), i * 1.3)
	prop("rock", Vector3(10.0, 0, 3.0), 1.2)


func _spawn_squad() -> void:
	_hero = _soldier(HERO_POS, PI + 0.35, 0)
	_squad.append(_hero)
	var left := _soldier(Vector3(-0.4, 0, -2.4), PI + 0.2, 0)
	_kneel(left)
	_squad.append(left)
	var right := _soldier(Vector3(3.3, 0, -3.1), PI - 0.3, 0)
	_squad.append(right)
	_arm(left, "hk416", ["holo", "grip"])
	_arm(right, "m249", [])


func _soldier(pos: Vector3, yaw: float, faction_id: int) -> SoldierModel:
	var m := SoldierModel.new()
	m.position = pos
	m.rotation.y = yaw
	geometry.add_child(m)
	if faction_id != 0:
		m.set_faction(faction_id)
	_ready_pose(m, 0.0)
	return m


## Low-ready rifle pose: both hands on the weapon, muzzle angled down.
func _ready_pose(m: SoldierModel, breath: float) -> void:
	if m.shoulders.size() < 2:
		return
	m.shoulders[1].rotation = Vector3(0.85, 0.0, -0.3)
	m.elbows[1].rotation = Vector3(1.05, 0.0, 0.0)
	m.shoulders[0].rotation = Vector3(1.15, 0.0, 0.55)
	m.elbows[0].rotation = Vector3(0.4, 0.0, 0.0)
	m.gun_mount.rotation = Vector3(-0.32, 0.18, 0.1)
	m.gun_mount.position = Vector3(0.06, -0.16, -0.36)
	m.chest.rotation.x = -0.04 + breath * 0.02
	m.torso.rotation.x = 0.03 + breath * 0.01
	m.head_node.rotation.x = 0.05 + breath * 0.015


func _kneel(m: SoldierModel) -> void:
	m.pelvis.position.y = 0.55
	m.hips[0].rotation.x = 1.5
	m.knees[0].rotation.x = -1.55
	m.hips[1].rotation.x = -0.15
	m.knees[1].rotation.x = -1.45
	m.set_meta("kneel", true)


func _arm(m: SoldierModel, weapon_id: String, attachments: Array, camo := "") -> void:
	if m.gun_model:
		m.gun_model.queue_free()
	m.gun_model = WeaponModels.create(weapon_id, attachments, camo)
	m.gun_mount.add_child(m.gun_model)


## Puts the player's selected primary weapon in the hero's hands.
func show_loadout(weapon_id: String, attachments: Array = [], camo := "") -> void:
	var key := "%s|%s|%s" % [weapon_id, ",".join(attachments), camo]
	if key == _weapon_key or _hero == null:
		return
	_weapon_key = key
	_arm(_hero, weapon_id, attachments, camo)


func _spawn_fx() -> void:
	_fire_barrel(Vector3(-2.6, 0, -3.4))
	_fire_barrel(Vector3(6.8, 0, -6.5))
	_smoke(Vector3(-4.0, 0.0, -6.0), 1.0)
	_smoke(Vector3(9.0, 0.0, -14.0), 1.6)
	_smoke(Vector3(-14.0, 0.0, -20.0), 2.2)
	_embers(Vector3(1.0, 0.5, -1.0))
	_spawn_flare()
	_flash = OmniLight3D.new()
	_flash.position = Vector3(-18, 6, -45)
	_flash.omni_range = 60.0
	_flash.light_color = Color(1.0, 0.7, 0.4)
	_flash.light_energy = 0.0
	add_child(_flash)


func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex


func _particle_material(color: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _soft_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _fire_barrel(pos: Vector3) -> void:
	prop("barrel", pos, 0.0)
	var flames := GPUParticles3D.new()
	flames.position = pos + Vector3(0, 1.0, 0)
	flames.amount = 32
	flames.lifetime = 0.7
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 1.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.color_ramp = _ramp([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.6, 0.2, 0.55), Color(0.8, 0.2, 0.05, 0.0)], [0.0, 0.25, 1.0])
	flames.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.55)
	quad.material = _particle_material(Color(1.0, 0.6, 0.35), true)
	flames.draw_pass_1 = quad
	geometry.add_child(flames)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.5, 0)
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.shadow_enabled = true
	geometry.add_child(light)
	_fires.append(light)
	_smoke(pos + Vector3(0, 1.4, 0), 0.5)


func _smoke(pos: Vector3, scale_mul: float) -> void:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 18
	p.lifetime = 9.0
	p.preprocess = 9.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.8 * scale_mul
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0.35, 0.15, 0)
	pm.scale_min = 2.0 * scale_mul
	pm.scale_max = 3.5 * scale_mul
	pm.scale_curve = _curve_grow()
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = _ramp([Color(0.3, 0.27, 0.25, 0.0), Color(0.3, 0.27, 0.25, 0.35), Color(0.4, 0.36, 0.34, 0.0)], [0.0, 0.2, 1.0])
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var mat := _particle_material(Color(1, 1, 1), false)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 30, 40))
	geometry.add_child(p)


func _curve_grow() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _embers(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 90
	p.lifetime = 6.0
	p.preprocess = 6.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 0.5, 5)
	pm.direction = Vector3(0.4, 1, 0.2)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.25, 0.12, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color_ramp = _ramp([Color(1, 0.7, 0.3, 0), Color(1, 0.55, 0.2, 1), Color(1, 0.3, 0.1, 0)], [0.0, 0.15, 1.0])
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = _particle_material(Color(3.0, 1.6, 0.6), true)
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-12, -2, -8), Vector3(24, 14, 16))
	geometry.add_child(p)


func _spawn_flare() -> void:
	_flare = Node3D.new()
	add_child(_flare)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	core.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.2)
	mat.emission_energy_multiplier = 12.0
	core.material_override = mat
	_flare.add_child(core)
	_flare_light = OmniLight3D.new()
	_flare_light.light_color = Color(1.0, 0.35, 0.25)
	_flare_light.light_energy = 3.0
	_flare_light.omni_range = 30.0
	_flare.add_child(_flare_light)
	var trail := GPUParticles3D.new()
	trail.amount = 60
	trail.lifetime = 5.0
	trail.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.4, 0.2, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.scale_curve = _curve_grow()
	pm.color_ramp = _ramp([Color(1, 0.5, 0.4, 0.5), Color(0.6, 0.5, 0.5, 0.25), Color(0.5, 0.5, 0.5, 0)], [0.0, 0.3, 1.0])
	trail.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = _particle_material(Color(1, 1, 1), false)
	trail.draw_pass_1 = quad
	trail.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	_flare.add_child(trail)


func _spawn_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.05
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 14.0
	attrs.dof_blur_far_transition = 12.0
	attrs.dof_blur_amount = 0.08
	camera.attributes = attrs
	add_child(camera)
	camera.current = true
	_update_camera(0.0)


## Moves the camera focus. Home = wide hero shot, side = framing for panels.
func set_focus(side_panel: bool) -> void:
	_cam_target_offset = Vector3(1.6, 0.25, 1.0) if side_panel else Vector3.ZERO


func _update_camera(delta: float) -> void:
	_cam_offset = _cam_offset.lerp(_cam_target_offset, clampf(delta * 1.5, 0.0, 1.0))
	var orbit := sin(_t * 0.07) * 0.18
	var push := sin(_t * 0.05) * 0.6
	var base := Vector3(-0.6, 1.5, 5.6 - push)
	base = base.rotated(Vector3.UP, orbit) + _cam_offset
	# Hand-held drift: a few slow sines.
	var shake := Vector3(sin(_t * 0.9) * 0.02 + sin(_t * 2.3) * 0.006, sin(_t * 1.1) * 0.015 + sin(_t * 2.9) * 0.005, 0.0)
	camera.position = base + shake
	var look := Vector3(-0.2, 1.3, -2.0) + _cam_offset * 0.6
	camera.look_at(look, Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD, sin(_t * 0.4) * 0.006)


func _process(delta: float) -> void:
	_t += delta
	if camera:
		_update_camera(delta)
	for i in _squad.size():
		var m := _squad[i]
		var breath := sin(_t * 1.6 + i * 1.7)
		_ready_pose(m, breath)
	for i in _fires.size():
		var f := _fires[i]
		f.light_energy = 2.2 + sin(_t * 13.0 + i) * 0.35 + sin(_t * 7.3 + i * 2.0) * 0.45 + randf() * 0.25
	# Signal flare: drifts down, then relaunches.
	if _flare:
		var cycle := fmod(_t + 4.0, 22.0) / 22.0
		_flare.position = Vector3(lerpf(-12.0, -4.0, cycle), lerpf(26.0, 6.0, cycle), -24.0)
		_flare_light.light_energy = 3.0 * clampf(cycle * 8.0, 0.0, 1.0) * clampf((1.0 - cycle) * 6.0, 0.0, 1.0) + randf() * 0.4
	# Distant artillery flashes on the horizon.
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = randf_range(3.5, 8.0)
		_flash.position = Vector3(randf_range(-40, 25), randf_range(3, 9), randf_range(-60, -40))
		_flash.light_energy = randf_range(6.0, 12.0)
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 18.0)

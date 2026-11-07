extends Node
## Pooled visual effects: bullet impacts, decals, tracers, blood, muzzle
## flashes and explosions. Everything is reused to keep frame times flat.

signal explosion_happened(position: Vector3, radius: float)

const DECAL_POOL := 160
const PARTICLE_POOL := 40

var _decals: Array[Decal] = []
var _decal_i := 0
var _bursts: Dictionary = {} # kind -> Array[CPUParticles3D]
var _burst_i: Dictionary = {}
var _tracers: Array[MeshInstance3D] = []
var _tracer_i := 0
var _tex_hole: ImageTexture
var _tex_scorch: ImageTexture
var _tex_puff: ImageTexture
var _tex_spark: ImageTexture
var _root: Node3D


func _ready() -> void:
	_tex_hole = _make_hole_texture()
	_tex_scorch = _make_scorch_texture()
	_tex_puff = _make_radial(64, Color(1, 1, 1, 1), 2.0)
	_tex_spark = _make_radial(16, Color(1, 0.9, 0.6, 1), 1.0)


## Called when a match world is created/destroyed so pools live in it.
func attach_to(world_root: Node3D) -> void:
	_root = world_root
	_decals.clear()
	_bursts.clear()
	_burst_i.clear()
	_tracers.clear()
	if world_root == null:
		return
	for i in DECAL_POOL:
		var d := Decal.new()
		d.size = Vector3(0.12, 0.2, 0.12)
		d.texture_albedo = _tex_hole
		d.cull_mask = 1
		d.visible = false
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		world_root.add_child(d)
		_decals.append(d)
	for i in 48:
		var t := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.012, 0.012, 1.0)
		t.mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.5)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.35)
		mat.emission_energy_multiplier = 6.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		t.material_override = mat
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		world_root.add_child(t)
		_tracers.append(t)


# --- Particles ---------------------------------------------------------------

func _particle_material(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	return m


func _make_burst(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	var quad := QuadMesh.new()
	p.mesh = quad
	match kind:
		"dust":
			quad.size = Vector2(0.25, 0.25)
			quad.material = _particle_material(_tex_puff, false)
			p.amount = 8
			p.lifetime = 0.9
			p.direction = Vector3(0, 0, 1)
			p.spread = 35.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 2.2
			p.gravity = Vector3(0, -1.0, 0)
			p.damping_min = 2.0
			p.damping_max = 3.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.6
			p.color_ramp = _ramp(Color(0.55, 0.52, 0.47, 0.7), Color(0.55, 0.52, 0.47, 0.0))
		"sparks":
			quad.size = Vector2(0.03, 0.03)
			quad.material = _particle_material(_tex_spark, true)
			p.amount = 10
			p.lifetime = 0.35
			p.direction = Vector3(0, 0, 1)
			p.spread = 50.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector3(0, -12.0, 0)
			p.color_ramp = _ramp(Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.1, 0.0))
		"wood":
			quad.size = Vector2(0.06, 0.06)
			quad.material = _particle_material(_tex_puff, false)
			p.amount = 10
			p.lifetime = 0.7
			p.direction = Vector3(0, 0, 1)
			p.spread = 40.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -9.0, 0)
			p.color_ramp = _ramp(Color(0.45, 0.32, 0.2, 1.0), Color(0.45, 0.32, 0.2, 0.0))
		"blood":
			quad.size = Vector2(0.18, 0.18)
			quad.material = _particle_material(_tex_puff, false)
			p.amount = 10
			p.lifetime = 0.5
			p.direction = Vector3(0, 0, 1)
			p.spread = 30.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, -6.0, 0)
			p.damping_min = 3.0
			p.damping_max = 4.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.5
			p.color_ramp = _ramp(Color(0.45, 0.02, 0.02, 0.9), Color(0.3, 0.0, 0.0, 0.0))
		"fire":
			quad.size = Vector2(2.2, 2.2)
			quad.material = _particle_material(_tex_puff, true)
			p.amount = 28
			p.lifetime = 0.6
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 11.0
			p.gravity = Vector3(0, 2.0, 0)
			p.damping_min = 9.0
			p.damping_max = 12.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.8
			p.color_ramp = _ramp(Color(1.0, 0.85, 0.45, 1.0), Color(0.8, 0.2, 0.05, 0.0))
		"smoke":
			quad.size = Vector2(3.0, 3.0)
			quad.material = _particle_material(_tex_puff, false)
			p.amount = 24
			p.lifetime = 4.0
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 5.0
			p.gravity = Vector3(0, 0.6, 0)
			p.damping_min = 1.5
			p.damping_max = 2.5
			p.scale_amount_min = 0.8
			p.scale_amount_max = 2.2
			p.color_ramp = _ramp(Color(0.2, 0.19, 0.18, 0.75), Color(0.35, 0.34, 0.33, 0.0))
		"debris":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.08, 0.08, 0.08)
			var dm := StandardMaterial3D.new()
			dm.albedo_color = Color(0.25, 0.23, 0.2)
			bm.material = dm
			p.mesh = bm
			p.amount = 20
			p.lifetime = 1.6
			p.direction = Vector3(0, 1, 0)
			p.spread = 75.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 14.0
			p.gravity = Vector3(0, -14.0, 0)
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


func _emit(kind: String, pos: Vector3, normal: Vector3) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	if not _bursts.has(kind):
		var pool: Array[CPUParticles3D] = []
		var n := 6 if kind in ["fire", "smoke", "debris"] else PARTICLE_POOL / 2
		for i in n:
			var p := _make_burst(kind)
			_root.add_child(p)
			pool.append(p)
		_bursts[kind] = pool
		_burst_i[kind] = 0
	var pool: Array = _bursts[kind]
	var i: int = _burst_i[kind]
	_burst_i[kind] = (i + 1) % pool.size()
	var p: CPUParticles3D = pool[i]
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	p.global_transform = Transform3D(Basis.looking_at(-normal, up), pos)
	p.restart()
	p.emitting = true


# --- Public effects ----------------------------------------------------------

func impact(pos: Vector3, normal: Vector3, surface: String) -> void:
	match surface:
		"metal", "sheet_metal":
			_emit("sparks", pos, normal)
			if randf() < 0.35:
				_emit("dust", pos, normal)
		"wood":
			_emit("wood", pos, normal)
			_emit("dust", pos, normal)
			if randf() < 0.5:
				_emit("debris", pos, normal)
		_:
			_emit("dust", pos, normal)
			if randf() < 0.6:
				_emit("debris", pos, normal)
			if randf() < 0.35:
				_emit("sparks", pos, normal)
	_place_decal(pos, normal, _tex_hole, randf_range(0.08, 0.13))
	if randf() < 0.5:
		Sfx.play_3d("impact_" + ("metal" if surface in ["metal", "sheet_metal"] else "concrete"), pos, -12.0, randf_range(0.85, 1.2))


func _place_decal(pos: Vector3, normal: Vector3, tex: Texture2D, size: float) -> void:
	if _decals.is_empty():
		return
	var d := _decals[_decal_i]
	_decal_i = (_decal_i + 1) % _decals.size()
	d.texture_albedo = tex
	d.size = Vector3(size, 0.15, size)
	# Decals project along their local -Y.
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var b := Basis(x, y, z).rotated(y, randf() * TAU)
	d.global_transform = Transform3D(b, pos)
	d.visible = true


func blood(pos: Vector3, dir: Vector3) -> void:
	_emit("blood", pos, -dir)


func tracer(from: Vector3, to: Vector3, from_player: bool) -> void:
	if _tracers.is_empty():
		return
	var len := from.distance_to(to)
	if len < 2.0:
		return
	var t := _tracers[_tracer_i]
	_tracer_i = (_tracer_i + 1) % _tracers.size()
	# Draw a moving streak along the path rather than the whole line.
	var streak := minf(len * 0.35, 9.0)
	var dir := (to - from) / len
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	t.visible = true
	var start_offset := 1.5 if from_player else 0.3
	var mat := t.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9
	var tw := create_tween()
	var travel := maxf(len - streak, 0.01)
	var dur := clampf(len / 650.0, 0.03, 0.4)
	tw.tween_method(func(f: float) -> void:
		var center := from + dir * (start_offset + streak * 0.5 + travel * f)
		t.global_transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3(1, 1, streak)), center), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void: t.visible = false)


func muzzle_flash_world(shooter: Soldier, w: WeaponState) -> void:
	if shooter.is_player or _root == null or w.has("suppressor"):
		return
	var pos := shooter.muzzle_position()
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 3.0
	l.omni_range = 4.0
	l.shadow_enabled = false
	_root.add_child(l)
	l.global_position = pos
	_emit("sparks", pos, shooter.aim_direction())
	get_tree().create_timer(0.05).timeout.connect(l.queue_free)


func explosion(pos: Vector3, radius: float, big := false) -> void:
	if _root == null:
		return
	_emit("fire", pos, Vector3.UP)
	_emit("smoke", pos, Vector3.UP)
	_emit("debris", pos, Vector3.UP)
	if big:
		_emit("fire", pos + Vector3(1, 1, 0), Vector3.UP)
		_emit("smoke", pos + Vector3(-1, 2, 1), Vector3.UP)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.light_energy = 12.0
	l.omni_range = radius * 2.5
	l.shadow_enabled = true
	_root.add_child(l)
	l.global_position = pos + Vector3.UP * 0.5
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.45)
	tw.tween_callback(l.queue_free)
	_place_decal(pos + Vector3.UP * 0.05, Vector3.UP, _tex_scorch, radius * 0.7)
	Sfx.play_3d("explosion_big" if big else "explosion", pos, 4.0 if big else 2.0, randf_range(0.9, 1.05))
	explosion_happened.emit(pos, radius)


# --- Procedural textures -----------------------------------------------------

func _make_radial(size: int, c: Color, falloff: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - h + 0.5, y - h + 0.5).length() / h
			var a := pow(clampf(1.0 - d, 0.0, 1.0), falloff)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a * c.a))
	return ImageTexture.create_from_image(img)


func _make_hole_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cracks: Array[float] = []
	for i in 6:
		cracks.append(rng.randf() * TAU)
	for y in size:
		for x in size:
			var v := Vector2(x - h + 0.5, y - h + 0.5)
			var d := v.length() / h
			var a := 0.0
			var col := Color(0.03, 0.03, 0.03)
			if d < 0.18:
				a = 1.0
			elif d < 0.45:
				a = 0.85 * (1.0 - (d - 0.18) / 0.27)
				col = Color(0.12, 0.11, 0.1)
			var ang := atan2(v.y, v.x)
			for c in cracks:
				var diff := absf(wrapf(ang - c, -PI, PI))
				if diff < 0.06 * (1.0 - d) and d < 0.9:
					a = maxf(a, 0.7 * (1.0 - d))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


func _make_scorch_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.06
	var h := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - h, y - h).length() / h
			var n := noise.get_noise_2d(x, y) * 0.35
			var a := clampf(1.0 - d + n, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.04, 0.035, 0.03, a * 0.9))
	return ImageTexture.create_from_image(img)

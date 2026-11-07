class_name ThrownItem
extends RigidBody3D
## A thrown or placed piece of equipment. Behaviour depends on `kind`.

var kind := "shard_grenade"
var owner_soldier: Soldier
var fuse := -1.0 # seconds to detonation; < 0 = no fuse
var placed := false
var weapon_override := ""
var _stuck := false
var _armed_time := 0.0
var _done := false
var _health := 40.0
var _bounce_sound_cd := 0.0


func _ready() -> void:
	collision_layer = Layers.PROJECTILE
	collision_mask = Layers.WORLD | Layers.SOLDIER | Layers.VEHICLE
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	mass = 0.4
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.8
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.06 if kind != "tripwire_mine" else 0.1
	cs.shape = sh
	add_child(cs)
	var model := WeaponModels.create_equipment(kind)
	add_child(model)
	if owner_soldier and is_instance_valid(owner_soldier):
		set_meta("team", owner_soldier.team)
	body_entered.connect(_on_body_entered)
	if kind in ["breach_charge", "tripwire_mine", "spawn_beacon", "sticky_charge"]:
		add_to_group("damageable")
	if kind == "breach_charge":
		add_to_group("breach_charges")
	if kind in ["tripwire_mine", "breach_charge", "spawn_beacon", "sticky_charge"]:
		add_to_group("enemy_equipment")
	if kind == "hatchet":
		gravity_scale = 0.6
	if kind in ["tripwire_mine", "breach_charge", "spawn_beacon"]:
		var t := get_tree().create_timer(90.0)
		t.timeout.connect(func() -> void:
			if is_instance_valid(self) and not _done:
				queue_free())
	else:
		var t2 := get_tree().create_timer(30.0)
		t2.timeout.connect(func() -> void:
			if is_instance_valid(self) and not _done:
				queue_free())


func _physics_process(delta: float) -> void:
	if _done:
		return
	_armed_time += delta
	_bounce_sound_cd = maxf(_bounce_sound_cd - delta, 0.0)
	if fuse >= 0.0:
		fuse -= delta
		if fuse <= 0.0:
			_detonate_kind()
			return
	if kind == "tripwire_mine" and _armed_time > 1.0:
		_check_tripwire()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if kind == "hatchet" and not _stuck:
		if body is Soldier and body != owner_soldier:
			var info := DamageInfo.new()
			info.attacker = owner_soldier
			info.weapon_id = "hatchet"
			info.amount = 200.0
			info.zone = "chest"
			info.position = global_position
			info.direction = linear_velocity.normalized()
			info.attacker_perks = owner_soldier.perks if is_instance_valid(owner_soldier) else []
			body.take_damage(info)
			Sfx.play_3d("knife_hit", global_position, -2.0)
		_stick(body)
		return
	if kind in ["sticky_charge", "breach_charge"] and not _stuck:
		_stick(body)
		Sfx.play_3d("sticky", global_position, -4.0)
		return
	if _bounce_sound_cd <= 0.0 and linear_velocity.length() > 2.0:
		_bounce_sound_cd = 0.15
		Sfx.play_3d("grenade_bounce", global_position, -8.0, randf_range(0.9, 1.1))


func _stick(body: Node) -> void:
	_stuck = true
	set_deferred("freeze", true)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if body is Soldier:
		# Ride along with the stuck soldier.
		var s := body as Soldier
		var off := s.to_local(global_position)
		set_meta("stuck_to", s)
		set_meta("stuck_offset", off)
	set_physics_process(true)


func _process(_delta: float) -> void:
	if has_meta("stuck_to"):
		var s = get_meta("stuck_to")
		if is_instance_valid(s) and s.alive:
			global_position = s.to_global(get_meta("stuck_offset"))


func _check_tripwire() -> void:
	var fwd := -global_basis.z
	for s: Soldier in get_tree().get_nodes_in_group("soldiers"):
		if not s.alive or s == owner_soldier:
			continue
		if is_instance_valid(owner_soldier) and not owner_soldier.is_enemy(s):
			continue
		var to := s.global_position - global_position
		if to.length() > 3.2 or to.length() < 0.2:
			continue
		if fwd.dot(Vector3(to.x, 0, to.z).normalized()) < 0.5:
			continue
		Sfx.play_3d("mine_trigger", global_position, 0.0)
		fuse = 0.25
		kind = "tripwire_fired"
		return


func detonate() -> void:
	if _done:
		return
	fuse = -1.0
	_explode(160.0, 6.5)


func take_damage(_info: DamageInfo) -> void:
	_health -= _info.amount
	if _health <= 0.0 and not _done:
		if kind in ["breach_charge", "tripwire_mine", "tripwire_fired", "sticky_charge"]:
			_explode(130.0, 5.0)
		else:
			_done = true
			queue_free()
		if _info.attacker is Soldier and _info.attacker != owner_soldier and _info.attacker.is_player:
			GameEvents.report("equipment_destroyed", {"perks": _info.attacker.perks})


func _detonate_kind() -> void:
	match kind:
		"shard_grenade":
			_explode(130.0, 7.0)
		"sticky_charge":
			_explode(150.0, 6.0)
		"tripwire_fired":
			_explode(160.0, 5.0)
		"flash_pop":
			_flash()
		"dazer":
			_stun()
		"smoke_canister":
			_smoke()
		_:
			_done = true
			queue_free()


func _explode(damage: float, radius: float) -> void:
	_done = true
	var wid := weapon_override if weapon_override != "" else kind.replace("tripwire_fired", "tripwire_mine")
	Equipment.explode(get_parent() as Node3D, global_position + Vector3.UP * 0.1, radius, damage,
		owner_soldier if is_instance_valid(owner_soldier) else null, wid)
	queue_free()


func _flash() -> void:
	_done = true
	Fx.impact(global_position, Vector3.UP, "metal")
	Sfx.play_3d("flashbang", global_position, 4.0)
	for s: Soldier in get_tree().get_nodes_in_group("soldiers"):
		if not s.alive:
			continue
		var head := s.aim_origin()
		var d := head.distance_to(global_position)
		if d > 22.0 or not Ballistics.has_line_of_sight(self, global_position + Vector3.UP * 0.2, head):
			continue
		var facing := s.aim_direction().dot((global_position - head).normalized())
		var strength := clampf(1.2 - d / 22.0, 0.0, 1.0) * lerpf(0.45, 1.0, clampf(facing * 0.5 + 0.5, 0.0, 1.0))
		if s == owner_soldier:
			strength *= 0.6
		s.apply_flash(strength)
		s.apply_stun(strength * 0.4)
	_light_pop(Color(1, 1, 1), 30.0)
	queue_free()


func _stun() -> void:
	_done = true
	Sfx.play_3d("stun", global_position, 2.0)
	for s: Soldier in get_tree().get_nodes_in_group("soldiers"):
		if not s.alive:
			continue
		var d := s.center_mass().distance_to(global_position)
		if d > 11.0 or not Ballistics.has_line_of_sight(self, global_position + Vector3.UP * 0.2, s.center_mass()):
			continue
		s.apply_stun(clampf(1.3 - d / 11.0, 0.0, 1.0))
	_light_pop(Color(0.7, 0.85, 1.0), 8.0)
	queue_free()


func _smoke() -> void:
	_done = true
	Sfx.play_3d("smoke", global_position, -2.0)
	var until := Time.get_ticks_msec() / 1000.0 + 22.0
	Equipment.smokes.append({"pos": global_position + Vector3.UP * 1.5, "radius": 5.5, "until": until})
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 4.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx._tex_puff
	quad.material = m
	p.mesh = quad
	p.amount = 70
	p.lifetime = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.85, 0.0))
	g.add_point(0.15, Color(0.82, 0.82, 0.8, 0.85))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = g
	p.local_coords = false
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 0.5
	p.emitting = true
	var t := get_tree().create_timer(20.0)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			get_tree().create_timer(8.5).timeout.connect(p.queue_free))
	queue_free()


func _light_pop(c: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 18.0
	get_parent().add_child(l)
	l.global_position = global_position + Vector3.UP * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)

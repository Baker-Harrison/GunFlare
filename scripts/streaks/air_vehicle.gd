class_name AirVehicle
extends AnimatableBody3D
## Streak aircraft: scan drones, jets, bombers, attack drone, escort chopper,
## gunship and the supply transport. Enemy aircraft can be shot down.

var kind := "uav"
var owner_soldier: Soldier
var team := 0
var life := 30.0
var health := 300.0
var match_ref: Match
var auto_gunship := false
var _center := Vector3.ZERO
var _t := 0.0
var _radius := 50.0
var _alt := 70.0
var _speed := 0.4 # rad/s for orbits
var _mode := "orbit"
var _flyby_from := Vector3.ZERO
var _flyby_dir := Vector3.FORWARD
var _hover := Vector3.ZERO
var _escort: Soldier
var _deliver_to := Vector3.ZERO
var _fire_cd := 0.0
var _target: Soldier
var _dead := false
var _model: Node3D
var _rotor: Node3D


func _ready() -> void:
	collision_layer = Layers.VEHICLE
	collision_mask = 0
	sync_to_physics = false
	add_to_group("damageable")
	add_to_group("air_vehicles")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	match kind:
		"uav", "jammer":
			health = 250.0
			bs.size = Vector3(6, 1, 2)
		"drone":
			health = 600.0
			bs.size = Vector3(4, 2, 4)
		"chopper", "transport":
			health = 1200.0
			bs.size = Vector3(3, 3, 12)
		"gunship":
			health = 3000.0
			bs.size = Vector3(30, 5, 22)
		_:
			health = 99999.0
			bs.size = Vector3(10, 2, 14)
	cs.shape = bs
	add_child(cs)
	_model = AircraftModels.create(kind)
	add_child(_model)
	_rotor = _model.find_child("Rotor", true, false) as Node3D
	var loop := {"uav": "drone_loop", "jammer": "drone_loop", "drone": "drone_loop", "chopper": "heli_loop",
		"transport": "heli_loop", "gunship": "gunship_loop", "jet": "jet_flyby", "bomber": "jet_flyby"}
	Sfx.attach_loop(self, loop.get(kind, "drone_loop"), 4.0 if kind in ["jet", "bomber"] else 0.0, 400.0)


func start(map_center: Vector3) -> void:
	_center = map_center
	match kind:
		"uav", "jammer":
			_alt = 75.0
			_radius = 55.0
			_speed = 0.25
		"gunship":
			_alt = 95.0
			_radius = 70.0
			_speed = 0.12
	_t = randf() * TAU
	global_position = _orbit_pos()


func _orbit_pos() -> Vector3:
	return _center + Vector3(cos(_t) * _radius, _alt, sin(_t) * _radius)


func flyby(target: Vector3, dir: Vector3, alt: float) -> void:
	_mode = "flyby"
	dir.y = 0.0
	_flyby_dir = dir.normalized()
	_flyby_from = target - _flyby_dir * 140.0 + Vector3.UP * alt
	global_position = _flyby_from
	look_at(global_position + _flyby_dir, Vector3.UP)


func hover_at(p: Vector3) -> void:
	_mode = "hover"
	_hover = p
	global_position = p + Vector3(0, 30, -80)


func escort(s: Soldier) -> void:
	_mode = "escort"
	_escort = s
	_alt = 28.0
	_radius = 22.0
	_speed = 0.35
	global_position = s.global_position + Vector3(0, 40, -120)


func deliver(p: Vector3) -> void:
	_mode = "deliver"
	_deliver_to = p
	global_position = p + Vector3(-150, 35, 0)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	life -= delta
	_t += delta * _speed
	if _rotor:
		_rotor.rotate_y(delta * 30.0)
	match _mode:
		"orbit":
			var p := _orbit_pos()
			_face_and_move(p, delta, 999.0)
		"flyby":
			global_position += _flyby_dir * 70.0 * delta
		"hover":
			var p2 := _hover + Vector3(sin(_t * 2.0) * 6.0, sin(_t * 3.0) * 1.0, cos(_t * 1.6) * 6.0)
			global_position = global_position.lerp(p2, minf(delta * 0.8, 1.0))
			_attack(delta, 0.12, 10.0, 60.0)
		"escort":
			var c := _escort.global_position if is_instance_valid(_escort) and _escort.alive else _center
			_center = _center.lerp(c, minf(delta * 0.4, 1.0))
			global_position = global_position.lerp(_orbit_pos(), minf(delta * 0.6, 1.0))
			_attack(delta, 0.09, 13.0, 70.0)
		"deliver":
			var target := _deliver_to + Vector3.UP * 25.0
			var to := target - global_position
			if life > 8.0:
				global_position += to.limit_length(40.0 * delta)
			else:
				global_position += Vector3(1, 0.15, 0) * 45.0 * delta
	if kind == "gunship" and auto_gunship:
		_gunship_ai(delta)
	if _mode in ["orbit", "escort"]:
		var tangent := Vector3(-sin(_t), 0, cos(_t))
		if tangent.length() > 0.1:
			look_at(global_position + tangent, Vector3.UP)
			rotate_object_local(Vector3.FORWARD, 0.25 if kind != "gunship" else 0.35)
	if life <= 0.0:
		_leave()


func _face_and_move(p: Vector3, delta: float, _max_speed: float) -> void:
	global_position = p


func _visible_enemy(max_range: float) -> Soldier:
	var best: Soldier = null
	var best_d := max_range
	for s: Soldier in match_ref.soldiers:
		if not s.alive or not match_ref.are_enemies(owner_soldier, s) or s.has_perk("ghostline"):
			continue
		var d := s.global_position.distance_to(global_position)
		if d > best_d:
			continue
		if not Ballistics.has_line_of_sight(self, global_position + Vector3.DOWN * 2.0, s.center_mass(), [get_rid()]):
			continue
		best = s
		best_d = d
	return best


func _attack(delta: float, rate: float, dmg: float, rng: float) -> void:
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	if _target == null or not is_instance_valid(_target) or not _target.alive or randf() < 0.05:
		_target = _visible_enemy(rng)
	if _target == null:
		_fire_cd = 0.4
		return
	_fire_cd = rate
	var from := global_position + Vector3.DOWN * 2.0
	var aim := _target.center_mass() + Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.5), randf_range(-0.8, 0.8))
	var dir := (aim - from).normalized()
	Ballistics.shoot_ray(match_ref, from, dir, dmg, owner_soldier, kind_streak(), [get_rid()], randi() % 2 == 0)
	Sfx.play_3d("gun_heli", from, 2.0, randf_range(0.95, 1.05), 300.0)


func kind_streak() -> String:
	match kind:
		"drone":
			return "hunter_drone"
		"chopper":
			return "escort_chopper"
		"gunship":
			return "overwatch_gunship"
	return kind


var _gs_cd := 0.0


func _gunship_ai(delta: float) -> void:
	_gs_cd -= delta
	if _gs_cd > 0.0:
		return
	var t := _visible_enemy(200.0)
	if t == null:
		_gs_cd = 0.6
		return
	_gs_cd = 1.4
	fire_cannon(t.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 105)


## Gunship cannon round toward a ground point. caliber: 105, 40, 25
func fire_cannon(target: Vector3, caliber: int) -> void:
	var from := global_position + Vector3.DOWN * 3.0
	var dir := (target - from).normalized()
	if caliber == 25:
		Ballistics.shoot_ray(match_ref, from, (dir + Vector3(randf_range(-0.01, 0.01), 0, randf_range(-0.01, 0.01))).normalized(),
			34.0, owner_soldier, "overwatch_gunship", [get_rid()])
		if owner_soldier and owner_soldier.is_player:
			Sfx.play_2d("gun_gunship_25", -6.0)
		return
	var p := Projectile.new()
	p.owner_soldier = owner_soldier
	p.weapon_id = "overwatch_gunship"
	p.streak = "overwatch_gunship"
	p.velocity = dir * (220.0 if caliber == 105 else 260.0)
	p.radius = 9.0 if caliber == 105 else 4.5
	p.damage = 400.0 if caliber == 105 else 140.0
	p.big = caliber == 105
	p.arm_distance = 0.0
	match_ref.add_child(p)
	p.global_position = from


func take_damage(info: DamageInfo) -> void:
	if _dead:
		return
	var a := info.attacker as Soldier
	if a == null or not match_ref.are_enemies(a, owner_soldier):
		return
	if kind in ["jet", "bomber"]:
		return
	var dmg := info.amount
	if info.weapon_id in ["rpg7", "at4", "m79", "underbarrel_gl"]:
		dmg *= 6.0 # launchers are for this
	if a.has_elite("heavy_rounds") and not info.explosive:
		dmg *= 1.5
	if a.has_elite("blast_master") and info.explosive:
		dmg *= 1.5
	health -= dmg
	if a.is_player:
		a.hit_confirmed.emit(self, info, health <= 0.0)
	if health <= 0.0:
		if a.is_player:
			GameEvents.report("streak_destroyed", {"streak": kind_streak(), "perks": a.perks})
			match_ref.hud_popup("AIR SUPPORT DESTROYED", Color(1, 0.85, 0.3))
			GameEvents.report("bonus", {"bonus": "spoiler"})
		destroy()


func destroy() -> void:
	if _dead:
		return
	_dead = true
	if kind in ["uav"]:
		match_ref.streaks.cancel_uav(team)
	elif kind == "jammer":
		match_ref.streaks.cancel_jam_by(team)
	Fx.explosion(global_position, 6.0, true)
	# Tumble out of the sky.
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3(randf_range(-20, 20), -global_position.y + 2.0, randf_range(-20, 20)), 2.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation", rotation + Vector3(1.5, 3.0, 2.0), 2.5)
	tw.tween_callback(func() -> void:
		Fx.explosion(global_position, 8.0, true)
		queue_free())


func _leave() -> void:
	_dead = true
	var away := global_position + (global_position - _center).normalized() * 300.0 + Vector3.UP * 40.0
	var tw := create_tween()
	tw.tween_property(self, "global_position", away, 4.0)
	tw.tween_callback(queue_free)

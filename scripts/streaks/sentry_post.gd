class_name SentryPost
extends StaticBody3D
## Automated turret. Sweeps, acquires enemies in view and fires bursts.

var owner_soldier: Soldier
var match_ref: Match
var health := 450.0
var life := 90.0
var _head: Node3D
var _muzzle: Node3D
var _target: Soldier
var _cd := 0.0
var _sweep := 0.0
var _dead := false


func _ready() -> void:
	collision_layer = Layers.VEHICLE | Layers.WORLD
	collision_mask = 0
	add_to_group("damageable")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 1.2, 0.6)
	cs.shape = bs
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)
	var model := AircraftModels.create("sentry")
	add_child(model)
	_head = model.find_child("Head", true, false)
	_muzzle = model.find_child("Muzzle", true, false)
	Sfx.play_3d("place", global_position, -2.0)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	life -= delta
	if life <= 0.0 or not is_instance_valid(owner_soldier):
		_break()
		return
	_cd -= delta
	if _target == null or not is_instance_valid(_target) or not _target.alive or not _can_see(_target):
		_target = _find()
	if _target == null:
		_sweep += delta
		_head.rotation.y = sin(_sweep * 0.8) * 1.2
		return
	var to := _target.center_mass() - _head.global_position
	var want := atan2(-to.x, -to.z) - rotation.y
	_head.rotation.y = rotate_toward(_head.rotation.y, want, delta * 4.0)
	_head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	if absf(wrapf(want - _head.rotation.y, -PI, PI)) < 0.15 and _cd <= 0.0:
		_cd = 0.11
		var from := _muzzle.global_position
		var dir := (_target.center_mass() + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4)) - from).normalized()
		Ballistics.shoot_ray(match_ref, from, dir, 16.0, owner_soldier, "sentry_post", [get_rid()], randi() % 2 == 0)
		Sfx.play_3d("gun_sentry", from, 0.0, randf_range(0.95, 1.05))


func _find() -> Soldier:
	var best: Soldier = null
	var best_d := 45.0
	for s: Soldier in match_ref.soldiers:
		if not s.alive or not match_ref.are_enemies(owner_soldier, s) or s.has_perk("ghostline"):
			continue
		var d := s.global_position.distance_to(global_position)
		if d < best_d and _can_see(s):
			best = s
			best_d = d
	return best


func _can_see(s: Soldier) -> bool:
	return Ballistics.has_line_of_sight(self, _head.global_position, s.center_mass(), [get_rid()]) \
		and not Equipment.is_in_smoke(_head.global_position, s.center_mass())


func take_damage(info: DamageInfo) -> void:
	var a := info.attacker as Soldier
	if a == null or not match_ref.are_enemies(a, owner_soldier):
		return
	health -= info.amount * (3.0 if info.explosive else 1.0)
	if a.is_player:
		a.hit_confirmed.emit(self, info, health <= 0.0)
	if health <= 0.0:
		if a.is_player:
			GameEvents.report("streak_destroyed", {"streak": "sentry_post", "perks": a.perks})
			match_ref.hud_popup("SENTRY DESTROYED", Color(1, 0.85, 0.3))
		_break()


func _break() -> void:
	if _dead:
		return
	_dead = true
	Fx.explosion(global_position + Vector3.UP * 0.6, 3.0)
	queue_free()

class_name Equipment
## Lethal and tactical equipment, launcher projectiles and explosions.

## Active smoke clouds: [{pos: Vector3, radius: float, until: float}]
static var smokes: Array = []
## Soldier -> ThrownItem spawn beacon
static var beacons: Dictionary = {}


static func world_of(s: Node) -> Node:
	return s.get_tree().current_scene


static func fuse_time(id: String) -> float:
	match id:
		"shard_grenade":
			return 3.5
		"sticky_charge":
			return 2.5
	return 0.0


static func throw_lethal(s: Soldier, id: String, cooked: float) -> void:
	match id:
		"tripwire_mine":
			_place(s, id)
			return
		"spawn_beacon":
			_place(s, id)
			return
	var speed := 26.0 if id == "hatchet" else (14.0 if id == "breach_charge" else 19.0)
	var item := _spawn_thrown(s, id, speed)
	if id == "shard_grenade":
		item.fuse = maxf(fuse_time(id) - cooked, 0.05)
	elif id == "sticky_charge":
		item.fuse = fuse_time(id)
	Sfx.play_3d("throw", s.global_position + Vector3.UP, -6.0)


static func throw_tactical(s: Soldier, id: String) -> void:
	var item := _spawn_thrown(s, id, 17.0)
	item.fuse = 1.2 if id == "smoke_canister" else 1.5
	Sfx.play_3d("throw", s.global_position + Vector3.UP, -6.0)


static func _spawn_thrown(s: Soldier, id: String, speed: float) -> ThrownItem:
	var item := ThrownItem.new()
	item.kind = id
	item.owner_soldier = s
	world_of(s).add_child(item)
	var dir := s.aim_direction()
	dir = (dir + Vector3.UP * 0.12).normalized()
	item.global_position = s.aim_origin() + dir * 0.5 + s.global_basis.x * 0.15
	item.linear_velocity = dir * speed + s.velocity * 0.5
	item.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	if id == "hatchet":
		item.angular_velocity = s.global_basis.x * -20.0
	item.add_collision_exception_with(s)
	return item


static func _place(s: Soldier, id: String) -> void:
	var item := ThrownItem.new()
	item.kind = id
	item.owner_soldier = s
	item.placed = true
	world_of(s).add_child(item)
	var fwd := -s.global_basis.z
	var space := s.get_world_3d().direct_space_state
	var start := s.global_position + fwd * 0.8 + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * 3.0, Layers.WORLD)
	var r := space.intersect_ray(q)
	var pos: Vector3 = r["position"] if not r.is_empty() else s.global_position + fwd * 0.8
	item.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos + Vector3.UP * 0.02)
	item.freeze = true
	if id == "spawn_beacon":
		if beacons.has(s) and is_instance_valid(beacons[s]):
			beacons[s].queue_free()
		beacons[s] = item
	Sfx.play_3d("place", pos, -6.0)


static func detonate_breach_charges(s: Soldier) -> bool:
	var any := false
	for n in s.get_tree().get_nodes_in_group("breach_charges"):
		if n.owner_soldier == s:
			n.detonate()
			any = true
	return any


static func drop_live_grenade(s: Soldier) -> void:
	var item := ThrownItem.new()
	item.kind = "shard_grenade"
	item.owner_soldier = s
	item.weapon_override = "parting_gift"
	world_of(s).add_child(item)
	item.global_position = s.global_position + Vector3.UP * 0.6
	item.linear_velocity = Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1))
	item.fuse = 2.5


static func launch_projectile(s: Soldier, id: String, from: Vector3, dir: Vector3, speed: float,
		gravity: float, radius: float, damage: float) -> void:
	var p := Projectile.new()
	p.owner_soldier = s
	p.weapon_id = id
	p.velocity = dir * speed
	p.gravity = gravity
	p.radius = radius
	p.damage = damage
	p.arm_distance = 8.0 if gravity > 0.0 else 4.0
	world_of(s).add_child(p)
	p.global_position = from


static func is_in_smoke(a: Vector3, b: Vector3) -> bool:
	var t := Time.get_ticks_msec() / 1000.0
	for sm: Dictionary in smokes:
		if t > sm["until"]:
			continue
		var c: Vector3 = sm["pos"]
		var r: float = sm["radius"]
		# Segment-sphere test.
		var ab := b - a
		var tt := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * tt).distance_to(c) < r:
			return true
	return false


## Area damage with line-of-sight falloff. Also hits damageable objects.
static func explode(world: Node3D, pos: Vector3, radius: float, damage: float, attacker: Soldier,
		weapon_id: String, streak := "", big := false) -> void:
	Fx.explosion(pos, radius, big)
	var space := world.get_world_3d().direct_space_state
	for s: Soldier in world.get_tree().get_nodes_in_group("soldiers"):
		if not s.alive:
			continue
		var target := s.center_mass()
		var d := pos.distance_to(target)
		if d > radius:
			continue
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, target, Layers.WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		var info := DamageInfo.new()
		info.attacker = attacker if is_instance_valid(attacker) else null
		info.weapon_id = weapon_id
		info.streak = streak
		info.explosive = true
		info.amount = damage * lerpf(1.0, 0.2, d / radius)
		info.position = target
		info.direction = (target - pos).normalized()
		info.distance = d
		if attacker and is_instance_valid(attacker):
			info.attacker_perks = attacker.perks
		s.take_damage(info)
	for n in world.get_tree().get_nodes_in_group("damageable"):
		if not n is Node3D or not is_instance_valid(n):
			continue
		var d2 := pos.distance_to((n as Node3D).global_position)
		if d2 < radius:
			var info2 := DamageInfo.new()
			info2.attacker = attacker if is_instance_valid(attacker) else null
			info2.weapon_id = weapon_id
			info2.explosive = true
			info2.amount = damage * lerpf(1.0, 0.3, d2 / radius)
			n.take_damage(info2)
	# Nearby players feel it.
	for s: Soldier in world.get_tree().get_nodes_in_group("soldiers"):
		if s.is_player and s.alive:
			var d3 := pos.distance_to(s.global_position)
			if d3 < radius * 4.0 and s.has_method("add_shake"):
				s.add_shake(clampf(1.0 - d3 / (radius * 4.0), 0.0, 1.0) * (1.5 if big else 1.0))

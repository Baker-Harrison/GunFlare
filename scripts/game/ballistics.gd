class_name Ballistics
## Hitscan bullets with spread, damage falloff, hit zones and wall
## penetration; projectile weapons hand off to Equipment.

const MAX_RANGE := 400.0
const MAX_PENETRATIONS := 2


static func fire(shooter: Soldier, w: WeaponState) -> void:
	var origin := shooter.aim_origin()
	var forward := shooter.aim_direction()
	var muzzle := shooter.muzzle_position()
	Sfx.play_gunshot(w, muzzle, shooter.is_player)
	Fx.muzzle_flash_world(shooter, w)
	if w.is_projectile():
		var spread_dir := _spread(forward, shooter.spread_degrees() * 0.3)
		if w.alt_mode:
			Equipment.launch_projectile(shooter, "underbarrel_gl", muzzle, spread_dir, 45.0, 9.8, 5.0, 130.0)
		else:
			Equipment.launch_projectile(shooter, w.data.id, muzzle, spread_dir, w.data.projectile_speed,
				w.data.projectile_gravity, w.data.blast_radius, w.data.damage_max)
		return

	var space := shooter.get_world_3d().direct_space_state
	var exclude: Array[RID] = [shooter.get_rid()]
	for h in shooter.model._hitboxes:
		exclude.append(h.get_rid())
	var spread := shooter.spread_degrees()
	var pellets := w.pellets()
	var per_target := {} # target -> DamageInfo
	var tracer_every := 1 if pellets > 1 else (2 if shooter.is_player else 3)
	for p in pellets:
		var dir := _spread(forward, spread if pellets == 1 else maxf(spread, 3.5 if not w.alt_mode else 4.5))
		var result := trace(space, origin, dir, w, shooter, exclude)
		var end: Vector3 = result["end"]
		if p == 0 and randi() % tracer_every == 0:
			Fx.tracer(muzzle, end, shooter.is_player)
		for hit: Dictionary in result["hits"]:
			var target: Node = hit["target"]
			var info: DamageInfo = per_target.get(target)
			if info == null:
				info = DamageInfo.new()
				info.attacker = shooter
				info.weapon_id = w.data.id
				info.zone = hit["zone"]
				info.position = hit["position"]
				info.direction = dir
				info.distance = hit["distance"]
				info.penetrated = hit["penetrated"]
				info.attachment_count = w.attachments.size()
				info.attacker_perks = shooter.perks
				info.attacker_downed = shooter.downed
				info.suppressed = w.has("suppressor")
				per_target[target] = info
			elif hit["zone"] == "head":
				info.zone = "head"
			info.amount += hit["damage"]
	for target: Node in per_target:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(per_target[target])


static func _spread(forward: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.001:
		return forward
	# Uniform over a disc, so most bullets land near the centre.
	var r := deg_to_rad(degrees) * sqrt(randf())
	var a := randf() * TAU
	var basis := Basis.looking_at(forward, Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT)
	var local := Vector3(cos(a) * r, sin(a) * r, -1.0).normalized()
	return (basis * local).normalized()


## Traces one bullet. Returns {"end": Vector3, "hits": [{target, zone, damage, position, distance, penetrated}]}
static func trace(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, w: WeaponState,
		shooter: Soldier, exclude: Array[RID]) -> Dictionary:
	var hits: Array = []
	var from := origin
	var travelled := 0.0
	var dmg_scale := 1.0
	var penetrations := 0
	var excl := exclude.duplicate()
	var end := origin + dir * MAX_RANGE
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(from, origin + dir * MAX_RANGE, Layers.BULLET_MASK, excl)
		q.collide_with_areas = true
		q.collide_with_bodies = true
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var pos: Vector3 = r["position"]
		var collider: Object = r["collider"]
		travelled = origin.distance_to(pos)
		var dist_dmg := w.data.damage_at(travelled / w.range_mult())
		if w.alt_mode and w.has("underbarrel_shotgun"):
			dist_dmg = lerpf(30.0, 8.0, clampf(travelled / 15.0, 0.0, 1.0))
		if collider is Area3D and collider.has_meta("soldier"):
			var s: Soldier = collider.get_meta("soldier")
			if s == shooter or not is_instance_valid(s) or not s.alive:
				excl.append(r["rid"])
				from = pos + dir * 0.01
				continue
			var zone: String = collider.get_meta("zone")
			var mult := w.data.chest_mult
			if zone == "head":
				mult = w.data.head_mult
			elif zone == "limb":
				mult = w.data.limb_mult
			var already := false
			for h: Dictionary in hits:
				if h["target"] == s:
					already = true
			if not already:
				hits.append({"target": s, "zone": zone, "damage": dist_dmg * mult * dmg_scale, "position": pos,
					"distance": travelled, "penetrated": penetrations > 0})
				Fx.blood(pos, dir)
			# Bullets pass through bodies at reduced power (allows multi-kills).
			for hb in s.model._hitboxes:
				excl.append(hb.get_rid())
			dmg_scale *= 0.7
			from = pos + dir * 0.01
			end = pos
			continue
		if collider is Node and (collider as Node).is_in_group("damageable"):
			var dmg := dist_dmg * dmg_scale * (1.5 if w.has("fmj") else 1.0)
			hits.append({"target": collider, "zone": "chest", "damage": dmg, "position": pos,
				"distance": travelled, "penetrated": penetrations > 0})
			Fx.impact(pos, r["normal"], "metal")
			end = pos
			break
		# World surface.
		var surface := "concrete"
		if collider is Node and (collider as Node).has_meta("surface"):
			surface = (collider as Node).get_meta("surface")
		Fx.impact(pos, r["normal"], surface)
		end = pos
		if penetrations >= MAX_PENETRATIONS:
			break
		var max_thick := w.penetration() * (0.9 if surface in ["wood", "plaster", "sheet_metal"] else 0.35)
		if max_thick <= 0.02:
			break
		var exit := _find_exit(space, pos, dir, max_thick, collider)
		if exit == Vector3.INF:
			break
		penetrations += 1
		dmg_scale *= 0.65 if surface in ["wood", "plaster", "sheet_metal"] else 0.5
		Fx.impact(exit, dir, surface)
		from = exit + dir * 0.01
	return {"end": end, "hits": hits}


static func _find_exit(space: PhysicsDirectSpaceState3D, entry: Vector3, dir: Vector3, max_thick: float, collider: Object) -> Vector3:
	var far := entry + dir * (max_thick + 0.02)
	var q := PhysicsRayQueryParameters3D.create(far, entry - dir * 0.01, Layers.WORLD)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return Vector3.INF
	if r["collider"] != collider:
		return Vector3.INF
	# Make sure the far point isn't still inside something else.
	return r["position"]


## Generic bullet for turrets and aircraft guns.
static func shoot_ray(world: Node3D, from: Vector3, dir: Vector3, damage: float, attacker: Soldier,
		streak_id: String, exclude: Array[RID] = [], tracer := true) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0, Layers.BULLET_MASK, exclude)
	q.collide_with_areas = true
	var r := space.intersect_ray(q)
	var end := from + dir * 300.0
	if not r.is_empty():
		end = r["position"]
		var c: Object = r["collider"]
		if c is Area3D and c.has_meta("soldier"):
			var s: Soldier = c.get_meta("soldier")
			if is_instance_valid(s) and s.alive:
				var info := DamageInfo.new()
				info.attacker = attacker if is_instance_valid(attacker) else null
				info.weapon_id = streak_id
				info.streak = streak_id
				info.amount = damage * (1.4 if c.get_meta("zone") == "head" else 1.0)
				info.zone = c.get_meta("zone")
				info.position = end
				info.direction = dir
				info.distance = from.distance_to(end)
				s.take_damage(info)
				Fx.blood(end, dir)
		else:
			Fx.impact(end, r["normal"], "concrete")
	if tracer:
		Fx.tracer(from, end, false)
	return end


static func has_line_of_sight(from_node: Node3D, a: Vector3, b: Vector3, extra_exclude: Array[RID] = []) -> bool:
	var space := from_node.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, Layers.LOS_MASK, extra_exclude)
	return space.intersect_ray(q).is_empty()

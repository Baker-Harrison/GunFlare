class_name Projectile
extends Node3D
## A rocket or launched grenade, stepped with raycasts so fast shots never
## tunnel through walls.

var owner_soldier: Soldier
var weapon_id := ""
var streak := ""
var velocity := Vector3.ZERO
var gravity := 0.0
var radius := 6.0
var damage := 150.0
var arm_distance := 4.0
var life := 8.0
var big := false
var _travelled := 0.0
var _trail: CPUParticles3D


func _ready() -> void:
	var model := WeaponModels.create_equipment("rocket" if gravity == 0.0 else "grenade_round")
	add_child(model)
	if velocity.length() > 0.1:
		look_at_from_position(global_position, global_position + velocity, Vector3.UP)
	if gravity == 0.0:
		_trail = CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.6, 0.6)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = Fx._tex_puff
		q.material = m
		_trail.mesh = q
		_trail.amount = 60
		_trail.lifetime = 1.6
		_trail.local_coords = false
		_trail.direction = Vector3(0, 0, 1)
		_trail.spread = 10.0
		_trail.initial_velocity_min = 0.5
		_trail.initial_velocity_max = 1.5
		_trail.gravity = Vector3(0, 0.4, 0)
		_trail.scale_amount_min = 0.8
		_trail.scale_amount_max = 2.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.8, 0.5, 0.9))
		g.add_point(0.1, Color(0.6, 0.6, 0.6, 0.6))
		g.set_color(g.get_point_count() - 1, Color(0.7, 0.7, 0.7, 0.0))
		_trail.color_ramp = g
		add_child(_trail)
		_trail.emitting = true
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 2.0
		l.omni_range = 5.0
		add_child(l)
		Sfx.play_3d("rocket_loop", global_position, 0.0)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_explode(global_position)
		return
	velocity.y -= gravity * delta
	var step := velocity * delta
	var from := global_position
	var to := from + step
	var excl: Array[RID] = []
	if is_instance_valid(owner_soldier):
		excl.append(owner_soldier.get_rid())
		for h in owner_soldier.model._hitboxes:
			excl.append(h.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.HITBOX | Layers.VEHICLE, excl)
	q.collide_with_areas = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		var pos: Vector3 = r["position"]
		_travelled += from.distance_to(pos)
		if _travelled < arm_distance:
			# Unarmed: direct impact only.
			var c: Object = r["collider"]
			if c is Area3D and c.has_meta("soldier"):
				var info := DamageInfo.new()
				info.attacker = owner_soldier
				info.weapon_id = weapon_id
				info.amount = 100.0
				info.position = pos
				info.direction = velocity.normalized()
				(c.get_meta("soldier") as Soldier).take_damage(info)
			Sfx.play_3d("grenade_bounce", pos, 0.0)
			queue_free()
			return
		_explode(pos + (r["normal"] as Vector3) * 0.2)
		return
	_travelled += step.length()
	global_position = to
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _explode(pos: Vector3) -> void:
	Equipment.explode(get_parent() as Node3D, pos, radius, damage,
		owner_soldier if is_instance_valid(owner_soldier) else null, weapon_id, streak, big)
	if _trail:
		_trail.emitting = false
		var tr := _trail
		remove_child(tr)
		get_parent().add_child(tr)
		tr.global_position = pos
		get_tree().create_timer(2.0).timeout.connect(tr.queue_free)
	queue_free()

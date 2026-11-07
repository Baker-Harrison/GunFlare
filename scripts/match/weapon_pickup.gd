class_name WeaponPickup
extends Node3D
## A dropped weapon. Hold Interact to swap it with the gun in your hands.

var weapon: WeaponState
var _model: Node3D
var _life := 35.0
var _hold := 0.0


func _ready() -> void:
	add_to_group("interactable")
	_model = WeaponModels.create(weapon.data.id, weapon.attachments, weapon.camo)
	add_child(_model)
	_model.rotation = Vector3(0, randf() * TAU, PI * 0.5)
	# Drop to the floor.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 4.0, Layers.WORLD)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"] + Vector3.UP * 0.05


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()


func can_interact(s: Soldier) -> bool:
	if not s.alive or s.downed or s.weapons.is_empty():
		return false
	for w in s.weapons:
		if w.data.id == weapon.data.id:
			# Same gun: just take the ammo.
			return w.reserve < w.mag_size * (w.data.reserve_mags + 1)
	return true


func interact_text(s: Soldier) -> String:
	for w in s.weapons:
		if w.data.id == weapon.data.id:
			return "Hold [F] to take ammo"
	return "Hold [F] to swap for %s" % weapon.data.display_name


func interact_progress(s: Soldier, holding: bool, delta: float) -> float:
	if not holding:
		_hold = 0.0
		return -1.0
	_hold += delta
	if _hold >= 0.4:
		_take(s)
		return 1.0
	return _hold / 0.4


func _take(s: Soldier) -> void:
	for w in s.weapons:
		if w.data.id == weapon.data.id:
			w.reserve += weapon.mag + weapon.reserve
			Sfx.play_2d("ammo_pickup", -4.0)
			queue_free()
			return
	var mine := s.weapon()
	var idx := s.current
	weapon.cancel_reload()
	s.weapons[idx] = weapon
	s.weapon_changed.emit(weapon)
	Sfx.play_2d("weapon_pickup", -4.0)
	# Leave ours behind.
	if mine:
		weapon = mine
		remove_child(_model)
		_model.queue_free()
		_model = WeaponModels.create(weapon.data.id, weapon.attachments, weapon.camo)
		add_child(_model)
		_model.rotation = Vector3(0, randf() * TAU, PI * 0.5)
		_life = 35.0
		_hold = -0.5
	else:
		queue_free()

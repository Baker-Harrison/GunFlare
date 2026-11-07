class_name SupplyCrate
extends StaticBody3D
## Air-dropped crate holding a random streak reward. Owner opens it fast;
## anyone else can steal it with a longer hold.

var owner_soldier: Soldier
var match_ref: Match
var target_y := 0.0
var landed := false
var reward := ""
var _hold := 0.0
var _life := 60.0
var _bot_t := 0.0


func _ready() -> void:
	collision_layer = Layers.WORLD | Layers.INTERACT
	collision_mask = 0
	add_to_group("interactable")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 0.9, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)
	add_child(AircraftModels.create("crate"))
	reward = match_ref.streaks.crate_reward()


func _physics_process(delta: float) -> void:
	if not landed:
		global_position.y = move_toward(global_position.y, target_y, delta * 14.0)
		# Crushing anyone underneath.
		for s: Soldier in match_ref.soldiers:
			if s.alive and Vector2(s.global_position.x - global_position.x, s.global_position.z - global_position.z).length() < 0.9 \
					and global_position.y - s.global_position.y < 1.8 and global_position.y > s.global_position.y:
				var info := DamageInfo.new()
				info.attacker = owner_soldier
				info.weapon_id = "supply_crate"
				info.streak = "supply_crate"
				info.amount = 500.0
				s.take_damage(info)
		if is_equal_approx(global_position.y, target_y):
			landed = true
			Sfx.play_3d("crate_land", global_position, 2.0)
			Fx.impact(global_position, Vector3.UP, "wood")
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Bots open their own crates when standing next to them.
	if is_instance_valid(owner_soldier) and not owner_soldier.is_player and owner_soldier.alive \
			and owner_soldier.global_position.distance_to(global_position) < 2.2:
		_bot_t += delta
		if _bot_t > 1.5:
			_open(owner_soldier)


func can_interact(s: Soldier) -> bool:
	return landed and s.alive


func interact_text(s: Soldier) -> String:
	var it := ContentDB.get_item(reward)
	var nm := it.display_name if it else "Ammo"
	return ("Hold [F] for %s" if s == owner_soldier else "Hold [F] to steal %s") % nm


func interact_progress(s: Soldier, holding: bool, delta: float) -> float:
	if not holding:
		_hold = 0.0
		return -1.0
	var need := 1.0 if s == owner_soldier else 4.0
	_hold += delta
	if _hold >= need:
		_open(s)
		return 1.0
	return _hold / need


func _open(s: Soldier) -> void:
	if reward == "ammo":
		for w in s.weapons:
			w.refill(4)
		s.lethal_count = 2
		s.tactical_count = 2
		if s.is_player:
			match_ref.hud_popup("AMMO RESUPPLIED", Color(0.7, 1, 0.6))
	else:
		match_ref.streaks.grant(s, reward)
		if s.is_player and s != owner_soldier:
			match_ref.hud_popup("CRATE STOLEN", Color(1, 0.85, 0.3))
	Sfx.play_3d("crate_open", global_position, 0.0)
	queue_free()

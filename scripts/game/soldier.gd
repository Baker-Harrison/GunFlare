class_name Soldier
extends CharacterBody3D
## A combatant. The player and bots are both Soldiers; a controller fills
## `input` every frame (PlayerController or BotBrain).

signal died(victim: Soldier, info: DamageInfo)
signal damaged(info: DamageInfo)
signal shot_fired(weapon: WeaponState)
signal weapon_changed(weapon: WeaponState)
signal hit_confirmed(target: Node, info: DamageInfo, killed: bool)
signal downed_changed(is_downed: bool)

enum Stance { STAND, CROUCH, PRONE }

const RADIUS := 0.35
const HEIGHTS := {Stance.STAND: 1.8, Stance.CROUCH: 1.2, Stance.PRONE: 0.72}
const EYES := {Stance.STAND: 1.62, Stance.CROUCH: 1.04, Stance.PRONE: 0.42}
const SPEED_MULT := {Stance.STAND: 1.0, Stance.CROUCH: 0.55, Stance.PRONE: 0.2}

const WALK_SPEED := 5.0
const SPRINT_MULT := 1.5
const SPRINT_DURATION := 4.0
const JUMP_VELOCITY := 5.0
const GRAVITY := 16.0
const GROUND_ACCEL := 55.0
const AIR_ACCEL := 9.0
const MAX_HEALTH := 100.0
const REGEN_DELAY := 4.5
const REGEN_RATE := 60.0
const MELEE_RANGE := 1.7
const MELEE_LONG_RANGE := 3.6
const DOWNED_TIME := 10.0

var team := 0
var display_name := "Soldier"
var is_player := false
var is_bot := true
var match_ref: Node = null
var difficulty := 1

var loadout: Dictionary = {}
var perks: Array = []
var elite: Array = []
var health := MAX_HEALTH
var alive := false
var input := SoldierInput.new()

var yaw := 0.0
var pitch := 0.0
var stance := Stance.STAND
var sprinting := false
var sprint_stamina := SPRINT_DURATION
var sprint_recover := 0.0 # time before firing is allowed after sprint
var eye_height := 1.62

var weapons: Array[WeaponState] = []
var current := 0
var swap_timer := 0.0
var _pending_swap := -1
var ads := 0.0 # 0 hip .. 1 aimed
var melee_timer := 0.0
var lethal_count := 1
var tactical_count := 2
var lethal_cook := -1.0 # seconds cooked; < 0 = not holding
var tactical_held := false
var equipment_timer := 0.0

var kills_this_life := 0
var deaths_without_kill := 0
var streak_inventory: Array = [] # earned streak rewards, newest last
var streak_index := 0
var deathstreak_active := ""
var last_damage_time := -100.0
var last_attacker: Soldier = null
var last_unsuppressed_shot := -100.0 # for minimap red dots
var downed := false
var downed_timer := 0.0
var used_last_laugh := false
var flash_amount := 0.0
var stun_amount := 0.0
var spawn_time := 0.0
var bonus_health := 0.0 # Second Wind
var bonus_health_time := 0.0
var footstep_phase := 0.0
var recoil_pitch := 0.0 # accumulated kick, recovered over time
var recoil_yaw := 0.0
var scan_revealed_until := 0.0

var head: Node3D
var model: SoldierModel
var collision: CollisionShape3D
var capsule := CapsuleShape3D.new()
var footstep_player: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = Layers.SOLDIER
	collision_mask = Layers.WORLD | Layers.SOLDIER | Layers.VEHICLE
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.45
	safe_margin = 0.02
	capsule.radius = RADIUS
	collision = CollisionShape3D.new()
	collision.shape = capsule
	add_child(collision)
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	model = SoldierModel.new()
	model.soldier = self
	add_child(model)
	_apply_stance_shape(true)
	add_to_group("soldiers")


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func has_perk(id: String) -> bool:
	return perks.has(id)


func has_elite(id: String) -> bool:
	return perks.has(id) and elite.has(id)


func weapon() -> WeaponState:
	return weapons[current] if current < weapons.size() else null


# --- Spawning ----------------------------------------------------------------

func spawn(at: Transform3D, class_loadout: Dictionary, perk_elites: Array) -> void:
	global_transform = Transform3D(Basis.IDENTITY, at.origin)
	yaw = at.basis.get_euler().y
	pitch = 0.0
	velocity = Vector3.ZERO
	loadout = class_loadout.duplicate(true)
	perks = loadout.get("perks", []).duplicate()
	elite = perk_elites.duplicate()
	health = MAX_HEALTH
	bonus_health = 0.0
	alive = true
	downed = false
	used_last_laugh = false
	stance = Stance.STAND
	_apply_stance_shape(true)
	sprinting = false
	sprint_stamina = SPRINT_DURATION
	ads = 0.0
	kills_this_life = 0
	last_attacker = null
	flash_amount = 0.0
	stun_amount = 0.0
	spawn_time = now()
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	melee_timer = 0.0
	lethal_cook = -1.0
	_build_weapons()
	lethal_count = 2 if loadout.get("lethal", "") == "hatchet" else 1
	tactical_count = 2
	if has_elite("scrounger"):
		lethal_count += 1
	# Setback perks (deathstreaks)
	deathstreak_active = ""
	var ds: String = loadout.get("deathstreak", "")
	var ds_data := ContentDB.get_item(ds) as StreakData
	if ds_data:
		var need := ds_data.count - (1 if has_elite("shortcut") else 0)
		if deaths_without_kill >= need:
			deathstreak_active = ds
			if ds == "second_wind":
				bonus_health = MAX_HEALTH * 2.0
				bonus_health_time = 10.0
	model.reset_pose()
	model.visible = true
	collision.disabled = false
	set_physics_process(true)


func _build_weapons() -> void:
	weapons.clear()
	var reload_mult := 0.5 if has_perk("quickhands") else 1.0
	var extra := 2 if has_elite("scrounger") else 0
	for slot in ["primary", "secondary"]:
		var w := ContentDB.get_item(loadout.get(slot, "")) as WeaponData
		if w == null:
			continue
		var atts: Array = loadout.get(slot + "_attachments", [])
		var camo: String = loadout.get(slot + "_camo", "") if slot == "primary" else ""
		var ws := WeaponState.new(w, atts, camo, extra, reload_mult)
		weapons.append(ws)
	current = 0
	swap_timer = 0.0
	_pending_swap = -1
	weapon_changed.emit(weapon())


# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var t := now()
	flash_amount = move_toward(flash_amount, 0.0, delta * 0.35)
	stun_amount = move_toward(stun_amount, 0.0, delta * 0.3)
	if bonus_health > 0.0:
		bonus_health_time -= delta
		if bonus_health_time <= 0.0:
			bonus_health = 0.0

	_update_look(delta)
	_update_stance()
	_update_movement(delta)
	_update_weapon(delta)
	_update_equipment(delta)
	_update_health(delta, t)
	if downed:
		downed_timer -= delta
		if downed_timer <= 0.0:
			if deathstreak_active == "last_laugh" and not used_last_laugh:
				_revive()
			else:
				var info := DamageInfo.new()
				info.attacker = last_attacker
				info.weapon_id = "bleed_out"
				_die(info)
				return
	if input.use_streak and match_ref and match_ref.has_method("use_streak"):
		match_ref.use_streak(self)
	input.clear_pulses()


func _update_look(delta: float) -> void:
	var stun_mult := 1.0 - stun_amount * 0.7
	yaw += input.look_delta.x * stun_mult
	pitch = clampf(pitch + input.look_delta.y * stun_mult, deg_to_rad(-85.0), deg_to_rad(85.0))
	# Recoil recovery pulls the kick back down.
	var rec := minf(delta * 7.0, 1.0)
	var back_p := recoil_pitch * rec
	var back_y := recoil_yaw * rec
	recoil_pitch -= back_p
	recoil_yaw -= back_y
	pitch -= back_p * 0.65
	yaw -= back_y * 0.65
	rotation = Vector3(0.0, yaw, 0.0)
	head.rotation = Vector3(pitch, 0.0, 0.0)
	var target_eye: float = EYES[stance]
	eye_height = move_toward(eye_height, target_eye, delta * 4.5)
	head.position = Vector3(0.0, eye_height, 0.0)


func _update_stance() -> void:
	if downed:
		if stance != Stance.PRONE:
			_set_stance(Stance.PRONE)
		return
	if input.prone_pressed:
		_set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)
	elif input.crouch_pressed:
		_set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)
	if input.jump and stance != Stance.STAND:
		_set_stance(Stance.CROUCH if stance == Stance.PRONE else Stance.STAND)
		input.jump = false
	if input.sprint and stance != Stance.STAND and input.move.y > 0.5:
		_set_stance(Stance.STAND)


func _set_stance(s: Stance) -> void:
	if s == stance:
		return
	if HEIGHTS[s] > HEIGHTS[stance] and not _has_headroom(HEIGHTS[s]):
		return
	stance = s
	_apply_stance_shape(false)


func _apply_stance_shape(instant: bool) -> void:
	var h: float = HEIGHTS[stance]
	capsule.height = maxf(h, RADIUS * 2.0)
	collision.position = Vector3(0.0, h * 0.5, 0.0)
	if instant:
		eye_height = EYES[stance]


func _has_headroom(height: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS - 0.05
	shape.height = height
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, height * 0.5 + 0.05, 0.0))
	q.collision_mask = Layers.WORLD
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func move_speed() -> float:
	var w := weapon()
	var s: float = WALK_SPEED * SPEED_MULT[stance]
	if w:
		s *= w.data.move_mult
		s *= lerpf(1.0, w.data.ads_move_mult, ads)
	if has_perk("fleetfoot"):
		s *= 1.08
	if downed:
		s = 0.6
	s *= 1.0 - stun_amount * 0.6
	return s


func _update_movement(delta: float) -> void:
	var w := weapon()
	var wants_sprint := input.sprint and input.move.y > 0.3 and stance == Stance.STAND and not downed \
		and lethal_cook < 0.0 and (sprint_stamina > 0.0 or has_perk("tireless"))
	if wants_sprint and not sprinting:
		if w and w.reloading and not has_perk("quickhands"):
			w.cancel_reload()
	sprinting = wants_sprint
	if sprinting:
		if not has_perk("tireless"):
			sprint_stamina = maxf(sprint_stamina - delta, 0.0)
		sprint_recover = w.data.sprint_out_time * (0.5 if has_elite("fleetfoot") else 1.0) if w else 0.25
		ads = move_toward(ads, 0.0, delta * 8.0)
	else:
		sprint_stamina = minf(sprint_stamina + delta * 0.8, SPRINT_DURATION)
		sprint_recover = maxf(sprint_recover - delta, 0.0)

	var speed := move_speed() * (SPRINT_MULT if sprinting else 1.0)
	var dir := (global_basis * Vector3(input.move.x, 0.0, -input.move.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * speed
	var on_floor := is_on_floor()
	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var fall_speed := velocity.y
	if on_floor:
		if input.jump and stance == Stance.STAND and not downed:
			velocity.y = JUMP_VELOCITY
			model.on_jump()
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if is_on_floor() and not on_floor and fall_speed < -11.0 and not has_elite("long_reach"):
		var info := DamageInfo.new()
		info.weapon_id = "fall"
		info.amount = (absf(fall_speed) - 11.0) * 9.0
		take_damage(info)
	# Footsteps
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 1.0:
		footstep_phase += hs * delta / (2.2 if sprinting else 1.6)
		if footstep_phase >= 1.0:
			footstep_phase -= 1.0
			if not has_perk("hush") and stance != Stance.PRONE:
				Sfx.play_3d("footstep", global_position, -14.0 if stance == Stance.CROUCH else (-4.0 if sprinting else -9.0), randf_range(0.9, 1.1))
	if global_position.y < -40.0:
		var info := DamageInfo.new()
		info.weapon_id = "fall"
		info.amount = 1000.0
		take_damage(info)


func can_fire() -> bool:
	var w := weapon()
	return w != null and not sprinting and sprint_recover <= 0.0 and swap_timer <= 0.0 \
		and melee_timer <= 0.4 and lethal_cook < 0.0 and flash_amount < 0.85


func _update_weapon(delta: float) -> void:
	melee_timer = maxf(melee_timer - delta, 0.0)
	if swap_timer > 0.0:
		swap_timer -= delta
		if _pending_swap >= 0 and swap_timer <= _swap_half:
			current = _pending_swap
			_pending_swap = -1
			weapon_changed.emit(weapon())
	var w := weapon()
	if w == null:
		return
	if downed and w.data.slot == "primary" and weapons.size() > 1:
		_begin_swap(1)

	if input.swap and swap_timer <= 0.0 and weapons.size() > 1 and not downed:
		_begin_swap((current + 1) % weapons.size())
	if input.toggle_attachment and w.toggle_alt():
		swap_timer = 0.45
		_swap_half = 0.0
		weapon_changed.emit(w)
	if input.melee and melee_timer <= 0.0 and not downed:
		_melee()

	var wants_ads := input.ads and not sprinting and w.can_ads() and swap_timer <= 0.0 and melee_timer <= 0.0
	var ads_mult := 0.5 if has_elite("quickhands") else 1.0
	var ads_rate := 1.0 / maxf(w.ads_time(ads_mult), 0.05)
	ads = move_toward(ads, 1.0 if wants_ads else 0.0, delta * ads_rate)

	if input.reload and not sprinting:
		w.start_reload()
	if input.fire and w.current_ammo() <= 0 and w.current_reserve() > 0 and not w.reloading and can_fire():
		w.start_reload()

	var shots := w.tick(delta, input.fire, can_fire())
	if shots > 0:
		_fire(w)
	if w.is_empty() and not w.reloading and weapons.size() > 1 and input.fire and swap_timer <= 0.0:
		_begin_swap((current + 1) % weapons.size())


var _swap_half := 0.0


func _begin_swap(to: int) -> void:
	if to == current or to >= weapons.size():
		return
	var w := weapon()
	if w:
		w.cancel_reload()
	var t := 0.6
	var next := weapons[to]
	t = (w.data.swap_time if w else 0.3) * 0.5 + next.data.swap_time * 0.5
	if has_elite("second_holster"):
		t *= 0.5
	swap_timer = t
	_swap_half = t * 0.5
	_pending_swap = to
	ads = 0.0


func _fire(w: WeaponState) -> void:
	var suppressed := w.has("suppressor") and not w.alt_mode
	if not suppressed:
		last_unsuppressed_shot = now()
	Ballistics.fire(self, w)
	var kick := w.data.recoil_vertical * w.recoil_mult()
	var side := w.data.recoil_horizontal * w.recoil_mult()
	if stance == Stance.CROUCH:
		kick *= 0.85
	elif stance == Stance.PRONE:
		kick *= 0.6
	kick *= lerpf(1.0, 0.8, ads)
	var dp := deg_to_rad(kick * randf_range(0.8, 1.2))
	var dy := deg_to_rad(side * randf_range(-1.0, 1.0))
	pitch = clampf(pitch + dp, deg_to_rad(-85.0), deg_to_rad(85.0))
	yaw += dy
	recoil_pitch += dp
	recoil_yaw += dy
	shot_fired.emit(w)
	model.on_fire()


## Current spread cone in degrees.
func spread_degrees() -> float:
	var w := weapon()
	if w == null:
		return 0.0
	var hip := w.data.hip_spread
	if w.has("akimbo"):
		hip *= 1.4
	if has_perk("steady_hand"):
		hip *= 0.65
	var moving := Vector2(velocity.x, velocity.z).length() / WALK_SPEED
	hip *= 1.0 + clampf(moving, 0.0, 1.0) * 0.5
	if stance == Stance.CROUCH:
		hip *= 0.8
	elif stance == Stance.PRONE:
		hip *= 0.6
	if not is_on_floor():
		hip *= 2.0
	var s := lerpf(hip + w.bloom, w.data.ads_spread + w.bloom * 0.15, ads)
	if w.alt_mode and w.has("underbarrel_shotgun"):
		s = maxf(s, 4.5)
	return s


func _melee() -> void:
	melee_timer = 0.9 if not (weapon() and weapon().has("tactical_knife")) else 0.6
	model.on_melee()
	Sfx.play_3d("knife_swing", global_position, -6.0)
	var reach := MELEE_LONG_RANGE if has_perk("long_reach") else MELEE_RANGE
	var best: Soldier = null
	var best_d := reach
	var fwd := -global_basis.z
	for s: Soldier in get_tree().get_nodes_in_group("soldiers"):
		if s == self or not s.alive or not is_enemy(s):
			continue
		var to := s.global_position - global_position
		var d := to.length()
		if d > best_d:
			continue
		if fwd.dot(Vector3(to.x, 0.0, to.z).normalized()) < 0.6:
			continue
		if not Ballistics.has_line_of_sight(self, head.global_position, s.global_position + Vector3.UP * 1.0):
			continue
		best = s
		best_d = d
	if best:
		if best_d > 1.2:
			velocity += (best.global_position - global_position).normalized() * 9.0
		var info := DamageInfo.new()
		info.attacker = self
		info.weapon_id = "knife"
		info.amount = 200.0
		info.melee = true
		info.zone = "chest"
		info.position = best.global_position + Vector3.UP
		info.direction = (best.global_position - global_position).normalized()
		info.distance = best_d
		info.attacker_perks = perks
		best.take_damage(info)
		Sfx.play_3d("knife_hit", best.global_position, -2.0)


func _update_equipment(delta: float) -> void:
	equipment_timer = maxf(equipment_timer - delta, 0.0)
	var lethal: String = loadout.get("lethal", "")
	var can_use := not sprinting and swap_timer <= 0.0 and equipment_timer <= 0.0 and (not downed or has_elite("last_gasp"))
	# Breach charges detonate on a second press.
	if input.lethal and lethal == "breach_charge" and Equipment.detonate_breach_charges(self):
		input.lethal = false
		equipment_timer = 0.4
		return
	if lethal_cook >= 0.0:
		lethal_cook += delta
		var fuse := Equipment.fuse_time(lethal)
		if fuse > 0.0 and lethal == "shard_grenade" and lethal_cook >= fuse:
			Equipment.throw_lethal(self, lethal, lethal_cook) # cooked too long
			lethal_cook = -1.0
		elif not input.lethal:
			Equipment.throw_lethal(self, lethal, lethal_cook)
			lethal_cook = -1.0
			equipment_timer = 0.6
	elif input.lethal and can_use and lethal_count > 0:
		lethal_count -= 1
		lethal_cook = 0.0
		var w := weapon()
		if w:
			w.cancel_reload()
	if input.tactical and not tactical_held and can_use and tactical_count > 0:
		tactical_count -= 1
		Equipment.throw_tactical(self, loadout.get("tactical", ""))
		equipment_timer = 0.6
	tactical_held = input.tactical


func _update_health(delta: float, t: float) -> void:
	if downed:
		return
	if health < MAX_HEALTH and t - last_damage_time > REGEN_DELAY:
		health = minf(health + REGEN_RATE * delta, MAX_HEALTH)


# --- Damage ------------------------------------------------------------------

func is_enemy(other: Node) -> bool:
	if other == null or other == self:
		return false
	if match_ref and match_ref.has_method("are_enemies"):
		return match_ref.are_enemies(self, other)
	return other.get("team") != team


func take_damage(info: DamageInfo) -> void:
	if not alive:
		return
	var attacker := info.attacker as Soldier
	if attacker and attacker != self and not is_enemy(attacker):
		return # no friendly fire
	var amount := info.amount
	if attacker and attacker != self:
		if not info.explosive and not info.melee and attacker.has_perk("heavy_rounds"):
			amount *= 1.4
		if info.explosive and attacker.has_perk("blast_master"):
			amount *= 1.5
	if info.explosive and attacker == self:
		amount *= 0.5
	if bonus_health > 0.0 and not info.melee:
		var absorbed := minf(bonus_health, amount * 0.66)
		bonus_health -= absorbed
		amount -= absorbed
	health -= amount
	last_damage_time = now()
	if attacker and attacker != self:
		last_attacker = attacker
	damaged.emit(info)
	if attacker and attacker != self:
		attacker.hit_confirmed.emit(self, info, health <= 0.0)
	if health <= 0.0:
		if not downed and not info.melee and not info.headshot and not info.explosive \
				and (has_perk("last_gasp") or (deathstreak_active == "last_laugh" and not used_last_laugh)) \
				and info.weapon_id != "fall":
			_go_down()
		else:
			_die(info)


func _go_down() -> void:
	downed = true
	downed_timer = DOWNED_TIME
	health = 30.0
	sprinting = false
	_set_stance(Stance.PRONE)
	if not _has_pistol_out():
		for i in weapons.size():
			if weapons[i].data.slot == "secondary":
				_begin_swap(i)
	downed_changed.emit(true)


func _has_pistol_out() -> bool:
	var w := weapon()
	return w != null and w.data.slot == "secondary"


func _revive() -> void:
	used_last_laugh = true
	downed = false
	health = MAX_HEALTH * 0.5
	_set_stance(Stance.CROUCH)
	downed_changed.emit(false)


func _die(info: DamageInfo) -> void:
	if not alive:
		return
	alive = false
	downed = false
	health = 0.0
	sprinting = false
	lethal_cook = -1.0
	collision.set_deferred("disabled", true)
	model.die(info.direction * (6.0 if info.explosive else 2.5), info.explosive)
	if deathstreak_active == "parting_gift" or has_perk("parting_gift"):
		Equipment.drop_live_grenade(self)
	died.emit(self, info)


func apply_flash(strength: float) -> void:
	flash_amount = maxf(flash_amount, clampf(strength, 0.0, 1.0))


func apply_stun(strength: float) -> void:
	stun_amount = maxf(stun_amount, clampf(strength, 0.0, 1.0))


## Set by PlayerController so tracers come out of the first-person gun.
var viewmodel: Node3D = null
var controller: Node = null


func add_shake(amount: float) -> void:
	if controller and controller.has_method("add_shake"):
		controller.add_shake(amount)


func muzzle_position() -> Vector3:
	if viewmodel and viewmodel.has_method("muzzle_world_position"):
		return viewmodel.muzzle_world_position()
	if model and model.gun_model and is_instance_valid(model.gun_model):
		var m := model.gun_model.find_child("Muzzle", true, false) as Node3D
		if m:
			return m.global_position
	return aim_origin() + aim_direction() * 0.6


func aim_origin() -> Vector3:
	return head.global_position


func aim_direction() -> Vector3:
	return -head.global_basis.z


func center_mass() -> Vector3:
	return global_position + Vector3.UP * (HEIGHTS[stance] * 0.6)


func head_position() -> Vector3:
	return model.head_global_position() if model else global_position + Vector3.UP * 1.65

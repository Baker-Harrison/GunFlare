class_name BotBrain
extends Node
## AI controller for a Soldier. Fills soldier.input like a player would, so
## bots obey the same weapon, recoil and movement rules.

enum State { ROAM, COMBAT, SEARCH }

## Per difficulty: recruit, regular, hardened, veteran
const REACTION := [0.62, 0.42, 0.28, 0.18]
const TURN_RATE := [160.0, 260.0, 380.0, 560.0] # deg/s
const AIM_ERROR := [5.5, 3.2, 1.8, 0.9] # deg at acquisition
const AIM_SETTLE := [1.2, 2.0, 3.2, 4.5] # error decay rate
const HEADSHOT_CHANCE := [0.05, 0.12, 0.22, 0.35]
const VIEW_RANGE := [70.0, 95.0, 120.0, 150.0]
const FOV_DEG := [100.0, 115.0, 130.0, 140.0]
const RECOIL_COMP := [0.3, 0.55, 0.75, 0.9]
const GRENADE_RATE := [0.01, 0.025, 0.04, 0.05] # chance / s while engaged

var soldier: Soldier
var match_ref: Node
var difficulty := 1
var agent: NavigationAgent3D

var state := State.ROAM
var target: Soldier = null
var target_since := 0.0
var last_seen_pos := Vector3.ZERO
var last_seen_time := -100.0
var _aim_error := Vector2.ZERO
var _goal := Vector3.ZERO
var _goal_time := 0.0
var _think_t := 0.0
var _strafe_dir := 1.0
var _strafe_t := 0.0
var _burst_t := 0.0
var _burst_pause := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _crouch_t := 0.0
var _jump_cd := 0.0
var _want_crouch := false
var _semi_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_physics_priority = -10
	_rng.randomize()
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.2
	agent.radius = 0.4
	agent.height = 1.8
	agent.path_max_distance = 3.0
	agent.avoidance_enabled = false
	soldier.add_child(agent)
	soldier.damaged.connect(_on_damaged)


func _on_damaged(info: DamageInfo) -> void:
	var a := info.attacker as Soldier
	if a and a != soldier and is_instance_valid(a) and a.alive:
		# Turn toward whoever shot us.
		last_seen_pos = a.global_position
		last_seen_time = _now()
		if target == null or _rng.randf() < 0.6:
			_acquire(a)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _physics_process(delta: float) -> void:
	if soldier == null or not soldier.alive or match_ref == null or not match_ref.get("in_progress"):
		if soldier:
			soldier.input.fire = false
			soldier.input.move = Vector2.ZERO
		return
	var i := soldier.input
	_think_t -= delta
	_jump_cd -= delta
	if _think_t <= 0.0:
		_think_t = _rng.randf_range(0.12, 0.22)
		_perceive()
	if target and (not is_instance_valid(target) or not target.alive):
		target = null
	if target:
		state = State.COMBAT
	elif _now() - last_seen_time < 6.0:
		state = State.SEARCH
	else:
		state = State.ROAM

	i.fire = false
	i.ads = false
	i.sprint = false
	match state:
		State.COMBAT:
			_combat(delta)
		State.SEARCH:
			_move_to(last_seen_pos, delta, false)
			_look_along_path(delta)
		State.ROAM:
			_roam(delta)

	# Reload when safe or empty.
	var w := soldier.weapon()
	if w and not w.reloading:
		if w.current_ammo() == 0 or (state != State.COMBAT and w.current_ammo() < w.current_mag_size() * 0.5):
			i.reload = true
		if w.is_empty() and soldier.weapons.size() > 1:
			i.swap = true
	# Streak rewards: call them in as soon as they're earned.
	if not soldier.streak_inventory.is_empty() and _rng.randf() < delta * 0.5:
		i.use_streak = true
	_unstick(delta)


# --- Perception --------------------------------------------------------------

func _perceive() -> void:
	var best: Soldier = null
	var best_score := INF
	var eye := soldier.aim_origin()
	var fwd := -soldier.global_basis.z
	var now := _now()
	var view_range: float = VIEW_RANGE[difficulty]
	var fov_cos := cos(deg_to_rad(FOV_DEG[difficulty] * 0.5))
	for o: Soldier in soldier.get_tree().get_nodes_in_group("soldiers"):
		if o == soldier or not o.alive or not soldier.is_enemy(o):
			continue
		var to := o.global_position - soldier.global_position
		var d := to.length()
		if d > view_range:
			continue
		var heard := (now - o.last_unsuppressed_shot < 1.0 and d < 45.0) or (d < 7.0 and o.sprinting and not o.has_perk("hush"))
		var in_fov := fwd.dot(to.normalized()) > fov_cos
		if not in_fov and not heard and o != target:
			continue
		var aim_pt := o.center_mass()
		if not Ballistics.has_line_of_sight(soldier, eye, aim_pt) and not Ballistics.has_line_of_sight(soldier, eye, o.head_position()):
			if heard:
				last_seen_pos = o.global_position
				last_seen_time = now
			continue
		if Equipment.is_in_smoke(eye, aim_pt):
			continue
		# Prone, still targets far away are harder to spot.
		if o.stance == Soldier.Stance.PRONE and d > 30.0 and o.velocity.length() < 0.5 and _rng.randf() < 0.6:
			continue
		var score := d * (0.5 if o == target else 1.0) * (0.6 if heard else 1.0)
		if score < best_score:
			best_score = score
			best = o
	if best:
		if best != target:
			_acquire(best)
		last_seen_pos = best.global_position
		last_seen_time = now
	elif target:
		# Lost sight.
		target = null


func _acquire(o: Soldier) -> void:
	target = o
	target_since = _now()
	var e: float = AIM_ERROR[difficulty]
	_aim_error = Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e * 0.6, e * 0.6))
	_strafe_t = 0.0


# --- Combat ------------------------------------------------------------------

func _combat(delta: float) -> void:
	var i := soldier.input
	var w := soldier.weapon()
	var to := target.global_position - soldier.global_position
	var dist := to.length()
	# Aim point: chest, sometimes head.
	var aim_pt := target.center_mass()
	if _rng.randf() < HEADSHOT_CHANCE[difficulty] * delta * 10.0:
		aim_pt = target.head_position()
	_aim_error = _aim_error.lerp(Vector2.ZERO, minf(delta * AIM_SETTLE[difficulty], 1.0))
	# Moving targets are harder to track.
	var tv := target.velocity.length()
	var wobble := tv * 0.08 * (1.0 - difficulty * 0.2)
	var err := _aim_error + Vector2(sin(_now() * 3.1) * wobble, cos(_now() * 2.3) * wobble * 0.5)
	if soldier.flash_amount > 0.3:
		err += Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-10, 10)) * soldier.flash_amount
	var on_target := _aim_at(aim_pt, err, delta)

	var reacted: bool = _now() - target_since > REACTION[difficulty] * (1.0 + soldier.stun_amount)
	if w:
		var cls := w.data.weapon_class
		var want_ads := dist > 12.0 or cls == "sniper"
		i.ads = want_ads and w.can_ads()
		var effective := w.data.range_max * 1.6 if cls != "sniper" else 999.0
		if reacted and on_target and dist < effective:
			if w.data.fire_mode == "auto" and not w.alt_mode:
				_burst_t -= delta
				if _burst_t > 0.0:
					i.fire = true
				else:
					_burst_pause -= delta
					if _burst_pause <= 0.0:
						var long := dist > 30.0
						_burst_t = _rng.randf_range(0.25, 0.5) if long else _rng.randf_range(0.6, 1.4)
						_burst_pause = _rng.randf_range(0.15, 0.35) if long else 0.08
			else:
				_semi_t -= delta
				if _semi_t <= 0.0:
					i.fire = true
					_semi_t = _rng.randf_range(0.12, 0.3) * (2.0 - difficulty * 0.3) + (0.5 if cls == "sniper" else 0.0)
				elif w.trigger_prev:
					i.fire = false
		# Pull down against recoil.
		soldier.pitch -= soldier.recoil_pitch * RECOIL_COMP[difficulty] * minf(delta * 10.0, 1.0)
		soldier.yaw -= soldier.recoil_yaw * RECOIL_COMP[difficulty] * minf(delta * 10.0, 1.0)

	# Knife if close.
	if dist < 1.7 and soldier.melee_timer <= 0.0:
		i.melee = true
	# Grenade
	if dist > 10.0 and dist < 28.0 and soldier.lethal_count > 0 and _rng.randf() < GRENADE_RATE[difficulty] * delta \
			and soldier.loadout.get("lethal", "") in ["shard_grenade", "sticky_charge"]:
		i.lethal = true
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if is_instance_valid(soldier):
				soldier.input.lethal = false)

	# Movement: strafe, keep a preferred distance.
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = _rng.randf_range(0.4, 1.3)
		_strafe_dir = -_strafe_dir if _rng.randf() < 0.7 else _strafe_dir
		_want_crouch = _rng.randf() < 0.25 and difficulty >= 1
	var pref := 14.0
	if w:
		match w.data.weapon_class:
			"smg", "shotgun", "machine_pistol":
				pref = 7.0
			"sniper":
				pref = 40.0
			"lmg":
				pref = 22.0
	var fwd_move := 0.0
	if dist > pref * 1.4:
		fwd_move = 0.8
	elif dist < pref * 0.5:
		fwd_move = -0.6
	if fwd_move > 0.0:
		# Close the distance along the navmesh.
		_move_to(target.global_position, delta, false, true)
		i.move.x = _strafe_dir * 0.5
	else:
		i.move = Vector2(_strafe_dir * 0.8, fwd_move)
	if _want_crouch and i.fire and dist > 10.0:
		if soldier.stance == Soldier.Stance.STAND:
			i.crouch_pressed = true
	elif soldier.stance == Soldier.Stance.CROUCH and not _want_crouch:
		i.crouch_pressed = true
	if _rng.randf() < delta * 0.25 and difficulty >= 2 and dist < 20.0 and _jump_cd <= 0.0:
		i.jump = true
		_jump_cd = 3.0


## Turns toward a point with limited turn rate. Returns true when close enough to shoot.
func _aim_at(point: Vector3, err_deg: Vector2, delta: float) -> bool:
	var eye := soldier.aim_origin()
	var d := point - eye
	var want_yaw := atan2(-d.x, -d.z) + deg_to_rad(err_deg.x)
	var want_pitch := atan2(d.y, Vector2(d.x, d.z).length()) + deg_to_rad(err_deg.y)
	var rate := deg_to_rad(TURN_RATE[difficulty]) * delta * (1.0 - soldier.stun_amount * 0.6)
	var dy := wrapf(want_yaw - soldier.yaw, -PI, PI)
	var dp := want_pitch - soldier.pitch
	soldier.yaw += clampf(dy, -rate, rate)
	soldier.pitch = clampf(soldier.pitch + clampf(dp, -rate, rate), deg_to_rad(-85), deg_to_rad(85))
	var remaining := absf(wrapf(want_yaw - soldier.yaw, -PI, PI)) + absf(want_pitch - soldier.pitch)
	var dist := d.length()
	var tolerance := atan2(0.6, dist) + deg_to_rad(1.5)
	return remaining < tolerance


# --- Movement ----------------------------------------------------------------

func _roam(delta: float) -> void:
	if _goal_time <= 0.0 or soldier.global_position.distance_to(_goal) < 2.5 or agent.is_navigation_finished():
		_goal = _pick_goal()
		var objective_mode: bool = match_ref.mode.id in ["dom", "kc", "hq"]
		_goal_time = _rng.randf_range(3.0, 7.0) if objective_mode else _rng.randf_range(10.0, 25.0)
		agent.target_position = _goal
	_goal_time -= delta
	_move_to(_goal, delta, true)
	_look_along_path(delta)
	if soldier.stance != Soldier.Stance.STAND:
		soldier.input.jump = true


func _pick_goal() -> Vector3:
	if match_ref.has_method("bot_goal"):
		var g = match_ref.bot_goal(soldier)
		if g is Vector3:
			return g
	return soldier.global_position + Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30))


func _move_to(pos: Vector3, _delta: float, sprint: bool, keep_aim := false) -> void:
	if agent.target_position.distance_to(pos) > 1.5:
		agent.target_position = pos
	var next := agent.get_next_path_position()
	var to := next - soldier.global_position
	to.y = 0.0
	if to.length() < 0.05:
		to = pos - soldier.global_position
		to.y = 0.0
	if to.length() < 0.3:
		soldier.input.move = Vector2.ZERO
		return
	var local := soldier.global_basis.inverse() * to.normalized()
	soldier.input.move = Vector2(local.x, -local.z).limit_length(1.0)
	if sprint and not keep_aim and local.z < -0.7 and soldier.global_position.distance_to(pos) > 12.0:
		soldier.input.sprint = true
	if not keep_aim:
		_path_dir = to.normalized()


var _path_dir := Vector3.FORWARD


func _look_along_path(delta: float) -> void:
	var want_yaw := atan2(-_path_dir.x, -_path_dir.z)
	var rate := deg_to_rad(TURN_RATE[difficulty] * 0.6) * delta
	soldier.yaw += clampf(wrapf(want_yaw - soldier.yaw, -PI, PI), -rate, rate)
	soldier.pitch = move_toward(soldier.pitch, 0.0, delta)


func _unstick(delta: float) -> void:
	var moved := soldier.global_position.distance_to(_last_pos)
	_last_pos = soldier.global_position
	if soldier.input.move.length() > 0.5 and moved < 0.5 * delta:
		_stuck_t += delta
		if _stuck_t > 0.8 and _jump_cd <= 0.0:
			soldier.input.jump = true
			_jump_cd = 1.0
		if _stuck_t > 2.5:
			_goal_time = 0.0
			_stuck_t = 0.0
			_strafe_dir = -_strafe_dir
	else:
		_stuck_t = 0.0

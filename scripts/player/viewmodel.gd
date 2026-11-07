class_name Viewmodel
extends Node3D
## First-person weapon and arms. Rendered by an overlay camera (layer 2) so it
## never clips into walls. All motion is procedural and physical:
##
## - Springs carry the weapon weight: look sway, movement inertia, footsteps,
##   jumps, landings, stance changes and recoil all push the same springs, so
##   each motion flows into the next one.
## - The arms have a skeleton (tools/rig_arms.py). Each hand follows a target
##   on the weapon; a two-bone IK from a fixed shoulder places the elbow, and
##   the forearm turns with the hand. Each finger has its own spring, so the
##   grip opens, closes and squeezes with a natural delay from finger to finger.
## - Reloads are hand-driven: the left hand takes the magazine out, carries it
##   down, brings a new one up, seats it and racks the charging handle. Bolt
##   and pump actions, shell loading, throws, melee and idle checks use the
##   same hand system. Each reload varies a little, so no two look the same.

const LAYER := 2
const HIP_OFFSET := Vector3(0.15, -0.155, -0.36)
const ADS_DISTANCE := 0.26
## Field of view of the overlay camera. Narrower than the world camera, so
## the arms and the weapon fill more of the screen.
const FOV_HIP := 54.0
const FOV_ADS := 46.0
## Rotation pivot in weapon space: behind the grip, towards the shoulder.
const PIVOT := Vector3(0.0, 0.0, 0.14)
## Shoulder positions in camera space for the arm IK.
const SHOULDER_R := Vector3(0.21, -0.3, 0.16)
const SHOULDER_L := Vector3(-0.2, -0.3, 0.06)
## Rear charging handles (pulled straight back from the top of the receiver).
const AR_FAMILY := ["m4a1", "m16a4", "hk416"]

# Finger poses: curl offsets from the modelled grip, per finger
# (thumb, index, middle, ring, pinky), per joint. Positive values close the hand.
const F_ZERO := Vector3.ZERO
const F_OPEN := Vector3(-0.8, -0.5, -0.35)
const F_OPEN_THUMB := Vector3(-0.45, -0.35, -0.25)
const F_RELAX := Vector3(-0.22, -0.15, -0.1)
const F_MAG := Vector3(0.28, 0.4, 0.32)
const F_PINCH := Vector3(0.7, 0.8, 0.5)
const F_PINCH_INDEX := Vector3(0.5, 0.6, 0.4)
const F_PINCH_THUMB := Vector3(0.3, 0.4, 0.3)
const F_FIST := Vector3(0.9, 1.0, 0.7)
const F_TRIGGER_OFF := Vector3(-0.15, -0.9, -0.6)
const F_TRIGGER_PULL := Vector3(0.06, 0.3, 0.25)

var soldier: Soldier
var gun: Node3D
var arms: Node3D
var hold_breath := false

var _weapon: WeaponState
var _mag: Node3D
var _mag_parent_inv := Transform3D.IDENTITY
var _mag_rest := Transform3D.IDENTITY # weapon space
var _mag_bounds := AABB()
var _has_mag_mesh := false
var _ads_marker := Vector3(0, 0.08, 0.1)
var _lpos := Vector3(0, 0.03, -0.25)
var _under := Vector3(0, 0.02, -0.3)
var _muzzle: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _stock_parts: Array[Node3D] = []
var _pistol := false
var _mass := 1.0
var _shell: MeshInstance3D

# Arm rigs.
var _rig_r: ArmRig
var _rig_l: ArmRig
var _l_rest := Transform3D.IDENTITY # left hand rest, weapon space
var _l_center := Vector3.ZERO # centre of the part the left hand holds
var _r_rest := Transform3D.IDENTITY
var _r_center := Vector3(0.0, -0.0428, 0.0339)
var _l_mag_grab := Transform3D.IDENTITY # left hand relative to the magazine
var _rack_point := Vector3.ZERO
var _rack_over_top := true

# Springs.
var _sway_p := Spring.new(170.0, 0.6)
var _sway_r := Spring.new(150.0, 0.55)
var _rec_p := Spring.new(520.0, 0.42)
var _rec_r := Spring.new(480.0, 0.38)
var _sprint := Spring1.new(70.0, 0.85)
var _vel_s := Spring.new(40.0, 1.0)

# Motion state.
var _t := 0.0
var _look_acc := Vector2.ZERO
var _look_vel := Vector2.ZERO
var _stride := 0.0
var _was_on_floor := true
var _prev_vy := 0.0
var _prev_eye := -1.0
var _idle_t := 0.0
var _squeeze := 0.0
var _trigger := 0.0
var _dry := 0.0

# Actions.
var _reload_t := -1.0
var _reload_total := 1.0
var _reload_empty := false
var _reload_prev := 0.0
var _rv := Vector3.ZERO # per-reload variation
var _shell_cycle := 1.0
var _shell_first := false
var _pump_after := false
var _chamber_t := -1.0
var _chamber_len := 0.9
var _chamber_prev := 0.0
var _rack_t := -1.0
var _rack_delay := 0.0
var _rack_prev := 0.0
var _raise := 1.0
var _raise_len := 0.35
var _lower := 0.0
var _lowering := false
var _swap_total := 0.0
var _prev_swap_timer := 0.0
var _changed_frame := -1
var _alt_anim := 0.0
var _melee_t := -1.0
var _melee_len := 0.9
var _throw_t := -1.0
var _fidget_t := -1.0
var _pistol_mag_drop := -1.0
# 1 while an action moves a hand, then falls to 0: the hand returns on its spring.
var _l_free := 0.0
var _r_free := 0.0


func _ready() -> void:
	soldier.weapon_changed.connect(_on_weapon_changed)
	soldier.shot_fired.connect(_on_shot)
	if soldier.weapon():
		_on_weapon_changed(soldier.weapon())


# --- Small maths helpers ---------------------------------------------------------

static func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _seg(f: float, a: float, b: float) -> float:
	return _ss((f - a) / (b - a))


static func _bump(f: float, a: float, b: float) -> float:
	if f <= a or f >= b:
		return 0.0
	return sin((f - a) / (b - a) * PI)


static func _out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c := 1.7
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


static func _soft(x: float, limit: float) -> float:
	return limit * tanh(x / limit)


static func _cross(prev: float, now: float, at: float) -> bool:
	return prev < at and now >= at


static func _rel(node: Node, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _lerp_xf(a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	return a.interpolate_with(b, clampf(w, 0.0, 1.0))


static func _offset(xf: Transform3D, pos: Vector3, rot := Vector3.ZERO, pivot := Vector3.ZERO) -> Transform3D:
	## Moves a weapon-space transform by pos and turns it by rot about pivot.
	var b := Basis.from_euler(rot)
	var o := pivot + b * (xf.origin - pivot) + pos
	return Transform3D(b * xf.basis, o)


static func _fingers(thumb: Vector3, index: Vector3, rest: Vector3) -> Array:
	return [thumb, index, rest, rest, rest]


# --- Springs -----------------------------------------------------------------------

class Spring:
	## A damped spring on a Vector3. Impulses go into the velocity.
	var x := Vector3.ZERO
	var v := Vector3.ZERO
	var k := 200.0
	var d := 20.0

	func _init(stiffness: float, damping_ratio: float) -> void:
		k = stiffness
		d = 2.0 * damping_ratio * sqrt(stiffness)

	func step(target: Vector3, dt: float) -> Vector3:
		var n := maxi(1, ceili(dt / 0.004))
		var h := dt / float(n)
		for i in n:
			v += ((target - x) * k - v * d) * h
			x += v * h
		return x

	func kick(impulse: Vector3) -> void:
		v += impulse

	func reset(to := Vector3.ZERO) -> void:
		x = to
		v = Vector3.ZERO


class Spring1:
	var x := 0.0
	var v := 0.0
	var k := 100.0
	var d := 10.0

	func _init(stiffness: float, damping_ratio: float) -> void:
		k = stiffness
		d = 2.0 * damping_ratio * sqrt(stiffness)

	func step(target: float, dt: float) -> float:
		var n := maxi(1, ceili(dt / 0.004))
		var h := dt / float(n)
		for i in n:
			v += ((target - x) * k - v * d) * h
			x += v * h
		return x


# --- Arm rig -------------------------------------------------------------------------

class ArmRig:
	## One first-person arm: a Skeleton3D with Root, Forearm, Hand and three
	## bones for each finger. Moves the hand to a weapon-space target, solves
	## the elbow from a fixed shoulder and drives each finger with a spring.
	const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
	const STIFF := [240.0, 330.0, 290.0, 250.0, 210.0]

	var skel: Skeleton3D
	var root := -1
	var hand := -1
	var fore := -1
	var bones: Array = [] # per finger: [b1, b2, b3]
	var rest_q: Array = [] # per finger: [q1, q2, q3]
	var curl: Array = [] # per finger: Vector3
	var curl_v: Array = []
	var root_rest := Transform3D.IDENTITY
	var hand_rest := Transform3D.IDENTITY # skeleton space
	var fore_rest := Transform3D.IDENTITY
	var fore_len := 0.25
	var gun_from_skel := Transform3D.IDENTITY
	var hand_rest_gun := Transform3D.IDENTITY
	var hand_to_fore := Basis.IDENTITY
	var shoulder := Vector3.ZERO
	var upper_len := 0.3
	var pole := Vector3.DOWN
	var pos_spring := Spring.new(900.0, 0.8)
	var rot_cur := Quaternion.IDENTITY
	var hand_gun := Transform3D.IDENTITY # current (sprung) hand, weapon space

	func setup(group: Node3D, prefix: String) -> bool:
		if group is Skeleton3D:
			skel = group as Skeleton3D
		else:
			var found := group.find_children("*", "Skeleton3D", true, false)
			if found.is_empty():
				return false
			skel = found[0] as Skeleton3D
		root = skel.find_bone(prefix + "_Root")
		hand = skel.find_bone(prefix + "_Hand")
		fore = skel.find_bone(prefix + "_Forearm")
		if hand < 0 or fore < 0:
			return false
		for f: String in FINGERS:
			var ids: Array[int] = []
			var qs: Array[Quaternion] = []
			for j in 3:
				var b := skel.find_bone("%s_%s%d" % [prefix, f, j + 1])
				if b < 0:
					return false
				ids.append(b)
				qs.append(skel.get_bone_rest(b).basis.get_rotation_quaternion())
			bones.append(ids)
			rest_q.append(qs)
			curl.append(Vector3.ZERO)
			curl_v.append(Vector3.ZERO)
		root_rest = skel.get_bone_global_rest(root) if root >= 0 else Transform3D.IDENTITY
		hand_rest = skel.get_bone_global_rest(hand)
		fore_rest = skel.get_bone_global_rest(fore)
		fore_len = fore_rest.origin.distance_to(hand_rest.origin)
		return true

	## Call after the arm is placed on the weapon. base: the weapon transform
	## in camera space at the hip rest pose.
	func calibrate(gun: Node3D, base: Transform3D, shoulder_cam: Vector3) -> void:
		gun_from_skel = Transform3D.IDENTITY
		var it: Node = skel
		while it != null and it != gun:
			if it is Node3D:
				gun_from_skel = (it as Node3D).transform * gun_from_skel
			it = it.get_parent()
		hand_rest_gun = gun_from_skel * hand_rest
		var fore_rest_gun := gun_from_skel * fore_rest
		hand_to_fore = hand_rest_gun.basis.inverse() * fore_rest_gun.basis
		shoulder = shoulder_cam
		var e0 := base * fore_rest_gun.origin
		var w0 := base * hand_rest_gun.origin
		upper_len = maxf(shoulder.distance_to(e0), 0.05)
		var n := (w0 - shoulder).normalized()
		var p := (e0 - shoulder) - n * n.dot(e0 - shoulder)
		pole = p.normalized() if p.length() > 0.001 else Vector3.DOWN
		pos_spring.reset(hand_rest_gun.origin)
		rot_cur = hand_rest_gun.basis.get_rotation_quaternion()
		hand_gun = hand_rest_gun

	func update_fingers(targets: Array, dt: float) -> void:
		var n := maxi(1, ceili(dt / 0.004))
		var h := dt / float(n)
		for i in 5:
			var k: float = STIFF[i]
			var d := 2.0 * 0.72 * sqrt(k)
			var c: Vector3 = curl[i]
			var v: Vector3 = curl_v[i]
			var tgt: Vector3 = targets[i]
			for s in n:
				v += ((tgt - c) * k - v * d) * h
				c += v * h
			curl[i] = c
			curl_v[i] = v

	## Moves the hand towards target (weapon space). snap: 0 = full spring
	## follow, 1 = glued to the target.
	func drive(target: Transform3D, dt: float, snap: float) -> void:
		var p := pos_spring.step(target.origin, dt)
		p = p.lerp(target.origin, snap)
		if snap >= 1.0:
			pos_spring.reset(p)
		var tq := target.basis.get_rotation_quaternion()
		rot_cur = rot_cur.slerp(tq, clampf(1.0 - exp(-dt * 26.0) + snap, 0.0, 1.0)).normalized()
		hand_gun = Transform3D(Basis(rot_cur), p)

	func apply(gun_cam: Transform3D) -> void:
		var hand_cam := gun_cam * hand_gun
		var w := hand_cam.origin
		# Two-bone IK: shoulder -> elbow (upper arm) -> wrist (forearm).
		var to_w := w - shoulder
		var lu := upper_len
		var lf := fore_len
		var dist := clampf(to_w.length(), absf(lu - lf) + 0.001, lu + lf - 0.001)
		var n := to_w.normalized()
		var a := (lu * lu - lf * lf + dist * dist) / (2.0 * dist)
		var h := sqrt(maxf(lu * lu - a * a, 0.0))
		var p := pole - n * n.dot(pole)
		p = p.normalized() if p.length() > 0.001 else Vector3.DOWN
		var elbow := shoulder + n * a + p * h
		var dir := (w - elbow).normalized()
		# Forearm turns with the hand (the wrist cannot twist), then swings
		# to point from the elbow to the wrist.
		var f_ref := (hand_cam.basis * hand_to_fore).orthonormalized()
		var y_ref := f_ref.y.normalized()
		var swing := Quaternion.IDENTITY
		if y_ref.dot(dir) > -0.999:
			swing = Quaternion(y_ref, dir)
		var fore_cam := Transform3D(Basis(swing) * f_ref, w - dir * lf)
		var skel_from_cam := (gun_cam * gun_from_skel).affine_inverse()
		var inv_root := root_rest.affine_inverse()
		var hl := inv_root * (skel_from_cam * hand_cam)
		var fl := inv_root * (skel_from_cam * fore_cam)
		skel.set_bone_pose_position(hand, hl.origin)
		skel.set_bone_pose_rotation(hand, hl.basis.get_rotation_quaternion())
		skel.set_bone_pose_position(fore, fl.origin)
		skel.set_bone_pose_rotation(fore, fl.basis.get_rotation_quaternion())
		for i in 5:
			var c: Vector3 = curl[i]
			var ids: Array = bones[i]
			var qs: Array = rest_q[i]
			for j in 3:
				var q: Quaternion = qs[j]
				skel.set_bone_pose_rotation(ids[j], q * Quaternion(Vector3.RIGHT, c[j]))


# --- Weapon set-up -------------------------------------------------------------------

func _set_layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_layer(c)


func _on_weapon_changed(w: WeaponState) -> void:
	if w == null:
		return
	_changed_frame = Engine.get_process_frames()
	_lowering = false
	if w == _weapon and gun != null:
		# Same weapon: the underbarrel mode changed. Flick the selector.
		_alt_anim = 1.0
		_reload_t = -1.0
		return
	if _weapon and _weapon.reload_started.is_connected(_on_reload_started):
		_weapon.reload_started.disconnect(_on_reload_started)
		_weapon.reload_finished.disconnect(_on_reload_finished)
		_weapon.shell_loaded.disconnect(_on_shell)
		_weapon.dry_fired.disconnect(_on_dry_fire)
	_weapon = w
	w.reload_started.connect(_on_reload_started)
	w.reload_finished.connect(_on_reload_finished)
	w.shell_loaded.connect(_on_shell)
	w.dry_fired.connect(_on_dry_fire)
	if gun:
		gun.queue_free()
	gun = WeaponModels.create(w.data.id, w.attachments, w.camo)
	add_child(gun)
	if w.has("akimbo"):
		var second := WeaponModels.create(w.data.id, [], w.camo)
		second.name = "Akimbo"
		second.position = Vector3(-0.26, 0, 0)
		gun.add_child(second)
	_mass = _class_mass(w.data.weapon_class)
	_mag = gun.find_child("Mag", true, false) as Node3D
	var ads := gun.find_child("ADS", true, false) as Node3D
	_ads_marker = _rel(ads, gun).origin if ads else Vector3(0, 0.08, 0.1)
	_muzzle = gun.find_child("MuzzleTip", true, false) as Node3D
	if _muzzle == null:
		_muzzle = gun.find_child("Muzzle", true, false) as Node3D
	var lh := gun.find_child("LeftHand", true, false) as Node3D
	_lpos = _rel(lh, gun).origin if lh else Vector3(0, 0.03, -0.25)
	var ub := gun.find_child("Underbarrel", true, false) as Node3D
	_under = _rel(ub, gun).origin if ub else _lpos
	_pistol = w.data.weapon_class == "pistol" or _lpos.length() < 0.07
	_build_arms()
	_build_flash()
	_build_shell()
	_stock_parts.clear()
	_find_stock(gun)
	_set_layer(self)
	_measure_mag()
	_calibrate_hands()
	_reload_t = -1.0
	_chamber_t = -1.0
	_rack_t = -1.0
	_rack_delay = 0.0
	_pistol_mag_drop = -1.0
	_raise = 0.0
	_raise_len = maxf(w.data.swap_time * 0.5, 0.22)
	if not w.has_meta("vm_drawn"):
		# First draw of this weapon: raise it, then chamber a round.
		w.set_meta("vm_drawn", true)
		_raise_len = maxf(_raise_len, 0.4)
		if not w.reloading and w.data.fire_mode not in ["bolt", "pump", "launcher"] and not w.shell_reload:
			_rack_delay = _raise_len * 0.7 # starts when the raise is almost done


static func _class_mass(c: String) -> float:
	match c:
		"pistol":
			return 0.6
		"machine_pistol":
			return 0.7
		"smg":
			return 0.85
		"shotgun":
			return 1.05
		"sniper":
			return 1.15
		"lmg":
			return 1.4
		"launcher":
			return 1.5
	return 1.0


func _find_stock(n: Node) -> void:
	var nm := n.name.to_lower()
	if n is Node3D and (nm.begins_with("stock") or nm.begins_with("buttpad") or nm.begins_with("buffertube") or nm.begins_with("cheek") or nm.begins_with("foldstock") or nm.begins_with("wirestock")):
		_stock_parts.append(n)
	for c in n.get_children():
		_find_stock(c)


func _measure_mag() -> void:
	_has_mag_mesh = false
	_mag_bounds = AABB(Vector3(-0.012, -0.12, -0.03), Vector3(0.024, 0.12, 0.06))
	if _mag == null:
		_mag_rest = Transform3D(Basis(), Vector3(0, 0.0, -0.08))
		return
	_mag_rest = _rel(_mag, gun)
	_mag_parent_inv = _rel(_mag.get_parent(), gun).affine_inverse()
	var first := true
	for m: MeshInstance3D in _mag.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var b := _rel(m, _mag) * m.get_aabb()
		_mag_bounds = b if first else _mag_bounds.merge(b)
		first = false
	_has_mag_mesh = not first


func _set_mag(xf_gun: Transform3D) -> void:
	if _mag:
		_mag.transform = _mag_parent_inv * xf_gun


## Direction that the magazine leaves the weapon in, weapon space.
func _mag_out_dir() -> Vector3:
	var c := _mag_rest * _mag_bounds.get_center()
	if c.y > _ads_marker.y - 0.04:
		return Vector3(0.0, 0.7, 0.7).normalized() # top magazine (P90)
	if c.x < -0.025:
		return Vector3(-0.35, -1.0, 0.1).normalized() # side box (LMG)
	return (_mag_rest.basis * Vector3.DOWN).normalized()


const ARMS_FILES := ["res://assets/characters/arms_sentinel", "res://assets/characters/arms_militia"]
static var _arms_scenes: Dictionary = {}


static func _arms_scene(team: int) -> PackedScene:
	var base: String = ARMS_FILES[clampi(team, 0, ARMS_FILES.size() - 1)]
	if _arms_scenes.has(base):
		return _arms_scenes[base]
	var scene: PackedScene = null
	for ext in [".gltf", ".glb"]:
		if ResourceLoader.exists(base + ext):
			scene = load(base + ext) as PackedScene
			break
	_arms_scenes[base] = scene
	return scene


func _build_arms() -> void:
	_rig_r = null
	_rig_l = null
	arms = Node3D.new()
	arms.name = "Arms"
	gun.add_child(arms)
	var scene := _arms_scene(soldier.team)
	if scene == null:
		_build_primitive_arms()
		return
	# Modelled arms: ArmR holds the grip at the weapon origin. ArmL has its
	# origin on the LeftHand marker. Pistols use the two-hand support grip.
	var inst := scene.instantiate() as Node3D
	arms.add_child(inst)
	var right := inst.find_child("ArmR", true, false) as Node3D
	var left := inst.find_child("ArmL", true, false) as Node3D
	var left_pistol := inst.find_child("ArmLPistol", true, false) as Node3D
	if left:
		left.position = _lpos
		left.visible = not _pistol
	if left_pistol:
		left_pistol.visible = _pistol
	var active_left := left_pistol if _pistol and left_pistol else left
	if right:
		var r := ArmRig.new()
		if r.setup(right, "R"):
			_rig_r = r
	if active_left:
		var l := ArmRig.new()
		if l.setup(active_left, "P" if active_left == left_pistol else "L"):
			_rig_l = l


func _build_primitive_arms() -> void:
	var f: Dictionary = SoldierModel.FACTIONS[clampi(soldier.team, 0, 1)]
	var sleeve := CamoLibrary.fabric_material(f["fatigue"], f["fatigue2"], f["camo"])
	var glove := StandardMaterial3D.new()
	glove.albedo_color = f["gloves"]
	glove.roughness = 0.7
	_arm_piece(arms, Vector3(0.038, 0.06, 0.08), Vector3(0.0, -0.025, 0.035), glove)
	_arm_capsule(arms, 0.03, 0.3, Vector3(0.03, -0.09, 0.19), Vector3(-1.15, 0.2, 0.0), sleeve)
	_arm_piece(arms, Vector3(0.042, 0.05, 0.09), _lpos + Vector3(-0.012, -0.03, 0), glove)
	_arm_capsule(arms, 0.03, 0.34, _lpos + Vector3(-0.09, -0.1, 0.15), Vector3(-1.05, -0.55, 0.3), sleeve)


func _arm_piece(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _arm_capsule(parent: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Rest poses and key points for the hands on this weapon.
func _calibrate_hands() -> void:
	var base := Transform3D(Basis(), HIP_OFFSET)
	if _pistol:
		# Support-hand grip centre (wraps the right fist), see tools/rig_arms.py.
		_l_center = Vector3(-0.012, -0.0476, 0.0255)
	else:
		_l_center = _lpos + Vector3(0.0, 0.024, 0.02)
	if _rig_r:
		_rig_r.calibrate(gun, base, SHOULDER_R)
		_r_rest = _rig_r.hand_rest_gun
	if _rig_l:
		_rig_l.calibrate(gun, base, SHOULDER_L)
		_l_rest = _rig_l.hand_rest_gun
	# Left hand on the magazine: palm under the base plate, fingers up the side.
	var bottom := _mag_rest * Vector3(_mag_bounds.get_center().x, _mag_bounds.position.y, _mag_bounds.get_center().z)
	var top := _mag_rest * Vector3(_mag_bounds.get_center().x, _mag_bounds.end.y, _mag_bounds.get_center().z)
	var hand_at_mag: Transform3D
	if _mag_out_dir().y > 0.0:
		hand_at_mag = _over_top(_l_rest, _l_center, top + Vector3(0.012, -0.03, 0.0))
	elif _pistol:
		hand_at_mag = _l_rest.translated(bottom + Vector3(0.0, 0.035, 0.0) - _l_center)
	else:
		hand_at_mag = _l_rest.translated(bottom + Vector3(0.0, 0.03, 0.0) - _l_center)
	_l_mag_grab = _mag_rest.affine_inverse() * hand_at_mag
	# Charging handle, bolt or slide.
	if _pistol:
		_rack_point = Vector3(0.0, _ads_marker.y - 0.035, _ads_marker.z - 0.02)
	elif _weapon and _weapon.data.id in AR_FAMILY:
		_rack_point = Vector3(0.0, _ads_marker.y - 0.048, _ads_marker.z + 0.005)
	else:
		# Side charging handle: the hand goes over the receiver above the magazine.
		_rack_point = Vector3(0.0, _ads_marker.y - 0.04, _mag_rest.origin.z - 0.01)


## The rest grip turned over the top of a part: palm down, fingers down the
## right side. center: where the grip centre goes.
static func _over_top(rest: Transform3D, rest_center: Vector3, center: Vector3) -> Transform3D:
	var b := Basis(Vector3.RIGHT, PI)
	return Transform3D(b * rest.basis, center + b * (rest.origin - rest_center))


func _build_flash() -> void:
	if _muzzle == null:
		return
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	_flash.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _flash_texture()
	m.albedo_color = Color(1.0, 0.8, 0.5)
	_flash.material_override = m
	_flash.visible = false
	_muzzle.add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.72, 0.4)
	_flash_light.omni_range = 5.0
	_flash_light.light_energy = 0.0
	_flash_light.layers = 1 | LAYER
	_flash_light.light_cull_mask = 1 | LAYER
	_muzzle.add_child(_flash_light)


## A shotgun shell (or a rifle round) that the left thumb carries to the port.
func _build_shell() -> void:
	_shell = null
	if _rig_l == null or _weapon == null:
		return
	var thumb_bones: Array = _rig_l.bones[0]
	var att := BoneAttachment3D.new()
	_rig_l.skel.add_child(att)
	att.bone_name = _rig_l.skel.get_bone_name(thumb_bones[2])
	_shell = MeshInstance3D.new()
	var c := CylinderMesh.new()
	var shotgun := _weapon.data.weapon_class == "shotgun"
	c.top_radius = 0.0095 if shotgun else 0.005
	c.bottom_radius = c.top_radius
	c.height = 0.065 if shotgun else 0.055
	c.radial_segments = 12
	_shell.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.08, 0.06) if shotgun else Color(0.78, 0.58, 0.25)
	m.metallic = 0.2 if shotgun else 0.85
	m.roughness = 0.45 if shotgun else 0.3
	_shell.material_override = m
	_shell.position = Vector3(0.0, 0.012, -0.012)
	_shell.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_shell.visible = false
	att.add_child(_shell)


static var _flash_tex: ImageTexture


static func _flash_texture() -> ImageTexture:
	if _flash_tex:
		return _flash_tex
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := Vector2(x - s * 0.5 + 0.5, y - s * 0.5 + 0.5) / (s * 0.5)
			var d := v.length()
			var ang := atan2(v.y, v.x)
			var star := pow(absf(cos(ang * 2.5)), 6.0) * (1.0 - d)
			var a := clampf(pow(maxf(1.0 - d, 0.0), 2.5) + star * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex


func muzzle_world_position() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position


# --- Events --------------------------------------------------------------------------

func _on_shot(w: WeaponState) -> void:
	var r := w.recoil_mult()
	var s := clampf(w.data.recoil_vertical, 0.3, 3.0)
	var c := w.data.weapon_class
	var back := 0.55
	var climb := 0.9
	var roll := 0.5
	match c:
		"pistol":
			back = 0.4
			climb = 2.4
			roll = 0.35
		"machine_pistol", "smg":
			back = 0.45
			climb = 0.7
			roll = 0.7
		"shotgun":
			back = 0.9
			climb = 1.6
			roll = 0.6
		"sniper":
			back = 0.85
			climb = 1.4
			roll = 0.4
		"lmg":
			back = 0.4
			climb = 0.55
			roll = 0.9
		"launcher":
			back = 1.0
			climb = 0.8
			roll = 0.3
	var aim := lerpf(1.0, 0.55, soldier.ads)
	var amt := minf(s * r * aim / sqrt(_mass), 2.0)
	_rec_p.kick(Vector3(randf_range(-0.06, 0.06), randf_range(0.05, 0.12), back * 3.0) * amt)
	_rec_r.kick(Vector3(2.6 * climb, randf_range(-0.5, 0.5), randf_range(-1.0, 1.0) * roll) * amt)
	# A little of the kick goes into the slow weight spring for the follow-through.
	_sway_r.kick(Vector3(0.5 * climb, randf_range(-0.15, 0.15), randf_range(-0.1, 0.1)) * amt)
	_squeeze = 1.0
	_trigger = 1.0
	_idle_t = 0.0
	_cancel_rack()
	_fidget_t = -1.0
	if not w.has("suppressor") or w.alt_mode:
		_flash_t = 0.05
		if _flash:
			_flash.visible = true
			_flash.rotation.z = randf() * TAU
			var sz := randf_range(0.8, 1.3) * (1.6 if c in ["shotgun", "lmg", "sniper", "launcher"] else 1.0)
			_flash.scale = Vector3(sz, sz, sz)
		if _flash_light:
			_flash_light.light_energy = randf_range(2.0, 3.0)
	if w.data.fire_mode in ["bolt", "pump"] and not w.alt_mode:
		_chamber_t = 0.0
		_chamber_prev = 0.0
		_chamber_len = clampf(60.0 / maxf(w.rpm(), 1.0) * 0.85, 0.45, 1.0)


func _on_reload_started(total: float, empty: bool) -> void:
	_reload_total = maxf(total, 0.2)
	_reload_empty = empty
	_reload_t = 0.0
	_reload_prev = 0.0
	_rv = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	_cancel_rack()
	_fidget_t = -1.0
	_chamber_t = -1.0
	_idle_t = 0.0
	if _weapon and _weapon.shell_reload and not _weapon.alt_mode:
		_shell_first = true
		_shell_cycle = _reload_total + 0.25 * (_reload_total / maxf(_weapon.data.reload_time, 0.01))
		_pump_after = empty and _weapon.data.fire_mode == "pump"
	else:
		Sfx.play_2d("reload_out", -10.0, 1.1)


func _on_reload_finished() -> void:
	var was_shell := _weapon != null and _weapon.shell_reload and not _weapon.alt_mode
	_reload_t = -1.0
	_set_mag(_mag_rest)
	if _mag:
		_mag.visible = true
	if was_shell:
		Sfx.play_2d("reload_in", -8.0, 0.9)
		if _pump_after:
			_pump_after = false
			_chamber_t = 0.0
			_chamber_prev = 0.0
			_chamber_len = 0.7


func _on_shell() -> void:
	Sfx.play_2d("shell_in", -8.0, randf_range(0.95, 1.05))
	_sway_p.kick(Vector3(0.0, 0.05, -0.04))
	_reload_t = 0.0
	_reload_prev = 0.0
	_shell_first = false
	_shell_cycle = _reload_total


func _on_dry_fire() -> void:
	_trigger = 1.0
	_dry = 1.0
	_rec_r.kick(Vector3(deg_to_rad(4.0), 0.0, 0.0))


func play_melee() -> void:
	_melee_t = 0.0
	_melee_len = 0.6 if soldier.weapon() and soldier.weapon().has("tactical_knife") else 0.9
	_cancel_rack()
	_fidget_t = -1.0


func play_throw() -> void:
	_throw_t = 0.0
	_fidget_t = -1.0


func add_mouse_sway(delta_px: Vector2) -> void:
	_look_acc += delta_px


# --- Frame update --------------------------------------------------------------------

func _process(delta: float) -> void:
	if soldier == null or gun == null:
		return
	var dt := minf(delta, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	var w := soldier.weapon()
	var ads_raw := soldier.ads
	var ads := ads_raw * ads_raw * ads_raw * (ads_raw * (ads_raw * 6.0 - 15.0) + 10.0)
	var on_floor := soldier.is_on_floor()
	var local_v := soldier.global_basis.inverse() * soldier.velocity
	var speed := Vector2(local_v.x, local_v.z).length()
	_update_timers(dt, w)

	var pos := HIP_OFFSET.lerp(Vector3(0, 0, -ADS_DISTANCE) - _ads_marker, ads)
	var rot := Vector3.ZERO
	var aim_damp := lerpf(1.0, 0.22, ads)

	# --- ADS arc: the weapon rolls in and dips as it comes up to the eye.
	var arc := sin(ads_raw * PI)
	var arc_dir := 1.0 if soldier.input.ads else -0.6
	rot.z += arc * 0.07 * arc_dir
	pos.y -= arc * 0.008
	rot.x += arc * 0.02

	# --- Look sway: the weapon lags behind the view and overshoots on stops.
	_look_vel = _look_vel.lerp(_look_acc / dt, minf(dt * 30.0, 1.0))
	_look_acc = Vector2.ZERO
	var lv := _look_vel * 0.00004 / _mass
	var sway_rot_t := Vector3(_soft(lv.y, 0.07), _soft(lv.x, 0.09), _soft(-lv.x * 0.9, 0.08))
	var sway_pos_t := Vector3(_soft(-lv.x * 0.25, 0.02), _soft(lv.y * 0.2, 0.015), 0.0)
	# Pitch: the weapon rides a little lower when you look up, and the reverse.
	pos.y += -soldier.pitch * 0.006 * (1.0 - ads)
	rot.x += soldier.pitch * 0.02 * (1.0 - ads)
	# Movement inertia and strafe lean.
	var vs := _vel_s.step(local_v, dt)
	var lag := (vs - local_v) * 0.006
	sway_pos_t += Vector3(_soft(lag.x, 0.02), _soft(lag.y, 0.02), _soft(lag.z, 0.025))
	sway_rot_t.z += clampf(-local_v.x * 0.014, -0.07, 0.07)
	sway_rot_t.x += clampf(lag.z * 1.5, -0.05, 0.05)
	# In the air the weapon floats with the vertical speed.
	if not on_floor:
		sway_pos_t.y += clampf(-soldier.velocity.y * 0.004, -0.03, 0.03)
		sway_rot_t.x += clampf(soldier.velocity.y * 0.01, -0.06, 0.06)
	_sway_p.k = 170.0 / _mass
	_sway_r.k = 150.0 / _mass
	var sp := _sway_p.step(sway_pos_t, dt)
	var sr := _sway_r.step(sway_rot_t, dt)
	pos += sp * lerpf(1.0, 0.35, ads)
	rot += sr * aim_damp

	# --- Jump, landing and stance changes push the weight springs.
	if on_floor and not _was_on_floor:
		var impact := clampf(-_prev_vy / 8.0, 0.15, 1.6)
		_sway_p.kick(Vector3(0.0, -0.55, 0.12) * impact)
		_sway_r.kick(Vector3(-1.2, randf_range(-0.25, 0.25), randf_range(-0.4, 0.4)) * impact)
		_squeeze = maxf(_squeeze, 0.6)
	elif not on_floor and _was_on_floor and soldier.velocity.y > 1.0:
		_sway_p.kick(Vector3(0.0, -0.25, 0.0))
		_sway_r.kick(Vector3(-0.6, 0.0, 0.0))
	_was_on_floor = on_floor
	_prev_vy = soldier.velocity.y
	if _prev_eye >= 0.0:
		var de := soldier.eye_height - _prev_eye
		if absf(de) > 0.0001:
			_sway_p.kick(Vector3(0.0, -de * 6.0, 0.0))
			_sway_r.kick(Vector3(de * 8.0, 0.0, de * 4.0))
	_prev_eye = soldier.eye_height

	# --- Walk and sprint cycles. One cycle (TAU) is two steps.
	var step_len := 2.2 if soldier.sprinting else (1.0 if soldier.stance == Soldier.Stance.PRONE else 1.6)
	if on_floor and speed > 0.2:
		var prev_step := floori(_stride / PI)
		_stride += dt * speed / step_len * PI
		if floori(_stride / PI) != prev_step:
			var hit := clampf(speed / 5.0, 0.2, 1.5) * lerpf(1.0, 0.3, ads)
			_sway_p.kick(Vector3(0.0, -0.12, 0.0) * hit)
			_sway_r.kick(Vector3(-0.25, 0.0, randf_range(-0.15, 0.15)) * hit)
	var amp := clampf(speed / 5.0, 0.0, 1.4) * (1.0 if on_floor else 0.2)
	amp *= lerpf(1.0, 0.12, ads) / sqrt(_mass)
	if soldier.stance == Soldier.Stance.CROUCH:
		amp *= 0.65
	var ph := _stride
	var walk := 1.0 - _sprint.x
	pos += Vector3(sin(ph) * 0.009, -pow(sin(ph), 2.0) * 0.011, 0.0) * amp * walk
	rot += Vector3(cos(2.0 * ph) * 0.008, sin(ph) * 0.012, sin(ph) * 0.022) * amp * walk
	if soldier.stance == Soldier.Stance.PRONE:
		# Crawl: the weapon rolls and pushes forward with each arm reach.
		pos += Vector3(sin(ph) * 0.02, -absf(sin(ph)) * 0.02, -absf(cos(ph)) * 0.02) * amp
		rot += Vector3(-0.15, sin(ph) * 0.12, sin(ph) * 0.18) * amp
	# Sprint pose and the swinging sprint cycle.
	var sprint_w := _sprint.step(1.0 if soldier.sprinting else 0.0, dt)
	var sa := clampf(speed / 7.0, 0.3, 1.2) / sqrt(_mass)
	if _pistol:
		pos += Vector3(-0.05, -0.07, 0.07) * sprint_w
		rot += Vector3(0.8, 0.25, 0.25) * sprint_w
	else:
		pos += Vector3(-0.025, -0.015, 0.015) * sprint_w
		rot += Vector3(-0.16, 0.48, 0.26) * sprint_w
	var sprint_cycle := maxf(sprint_w, 0.0) * sa
	pos += Vector3(sin(ph) * 0.028, -pow(sin(ph), 2.0) * 0.034, cos(2.0 * ph) * 0.006) * sprint_cycle
	rot += Vector3(cos(2.0 * ph) * 0.05, sin(ph) * 0.1, sin(ph) * 0.085) * sprint_cycle

	# --- Breathing and micro motion.
	var idle_amp := lerpf(1.0, 0.35, ads) * (0.12 if hold_breath else 1.0)
	pos += Vector3(sin(_t * 0.9) * 0.0012 + sin(_t * 2.3) * 0.0004, sin(_t * 1.25) * 0.0018, sin(_t * 0.6) * 0.0008) * idle_amp
	rot += Vector3(sin(_t * 1.25 + 0.5) * 0.004, sin(_t * 0.7) * 0.003 + sin(_t * 1.9) * 0.001, sin(_t * 0.55) * 0.004) * idle_amp

	# --- Recoil springs.
	var rp := _rec_p.step(Vector3.ZERO, dt)
	var rr := _rec_r.step(Vector3.ZERO, dt)
	pos += rp * lerpf(1.0, 0.7, ads)
	rot += rr * lerpf(1.0, 0.5, ads)

	# --- Hand targets start at the grip; the actions below move them.
	var l_target := _l_rest
	var r_target := _r_rest
	var l_snap := 1.0
	var r_snap := 1.0
	var l_fingers := _fingers(F_ZERO, F_ZERO, F_ZERO)
	var r_fingers := _fingers(F_ZERO, F_ZERO, F_ZERO)
	var mag_xf := _mag_rest
	var mag_attached := false
	var mag_visible := true
	var shell_visible := false
	var trigger_off := sprint_w

	# --- Swap: lower and raise on a curved path.
	var raise_e := _out_back(_raise)
	var down := maxf(1.0 - raise_e, _ss(_lower))
	pos += Vector3(0.03, -0.24, 0.06) * down
	rot += Vector3(-0.95, 0.3, 0.55) * down
	trigger_off = maxf(trigger_off, down)
	if _alt_anim > 0.0:
		var a := _bump(1.0 - _alt_anim, 0.0, 1.0)
		rot += Vector3(0.1, -0.15, 0.4) * a
		pos += Vector3(-0.02, -0.01, 0.01) * a
		l_target = _offset(_l_rest, Vector3(0.01, -0.02, 0.04) * a, Vector3(0.0, 0.0, 0.3) * a, _l_center)
		l_snap = 0.0
		l_fingers = _blend_f(l_fingers, _fingers(F_PINCH_THUMB, F_PINCH_INDEX, F_RELAX), a)

	# --- Reloads.
	if _reload_t >= 0.0 and w and w.reloading:
		var res := _reload_pose(w, dt)
		pos += res["pos"]
		rot += res["rot"]
		l_target = res["l"]
		l_fingers = res["lf"]
		l_snap = 0.0
		mag_xf = res["mag"]
		mag_attached = res["attached"]
		mag_visible = res["mag_visible"]
		shell_visible = res["shell"]
		var thumb: float = res["r_thumb"]
		r_fingers[0] = Vector3(0.25, 0.35, 0.2) * thumb
		trigger_off = maxf(trigger_off, 0.75)
	# --- First-draw charging handle rack (also the slide on pistols).
	if _rack_t >= 0.0:
		var res := _rack_pose(_rack_t / 0.85)
		pos += res["pos"]
		rot += res["rot"]
		l_target = res["l"]
		l_fingers = res["lf"]
		l_snap = 0.0
	# --- Bolt and pump actions after each shot.
	if _chamber_t >= 0.0 and w:
		var f := _chamber_t / _chamber_len
		if w.data.fire_mode == "bolt":
			var res := _bolt_pose(f)
			pos += res["pos"]
			rot += res["rot"]
			r_target = res["r"]
			r_fingers = res["rf"]
			r_snap = 0.0
		else:
			var res := _pump_pose(f)
			pos += res["pos"]
			rot += res["rot"]
			l_target = res["l"]
			l_snap = 0.0
		trigger_off = 1.0
		_chamber_prev = f
	# --- Melee: wind up, strike and recover.
	if _melee_t >= 0.0:
		var f := _melee_t / _melee_len
		var wind := _bump(f, 0.0, 0.3)
		var strike := _seg(f, 0.12, 0.3) * (1.0 - _seg(f, 0.45, 1.0))
		pos += Vector3(0.03, -0.01, 0.04) * wind + Vector3(-0.15, -0.02, -0.11) * strike
		rot += Vector3(0.05, -0.25, -0.15) * wind + Vector3(0.12, 0.9, 0.85) * strike
		if _cross(_melee_t / _melee_len - dt / _melee_len, f, 0.2):
			_sway_r.kick(Vector3(0.0, 1.5, 1.0))
		_squeeze = maxf(_squeeze, strike)
		trigger_off = maxf(trigger_off, wind + strike)
	# --- Throw and cook: the left hand leaves the weapon.
	var cook := soldier.lethal_cook >= 0.0
	var throw_w := 0.0
	var throw_l := l_target
	var throw_f := l_fingers
	if cook or _throw_t >= 0.0:
		var f := 0.0 if cook else _throw_t / 0.75
		var hold := 1.0 if cook else (1.0 - _seg(f, 0.55, 1.0))
		throw_w = hold
		pos += Vector3(0.06, -0.12, 0.05) * hold
		rot += Vector3(-0.45, -0.3, -0.25) * hold
		var gun_cam := _compose(pos, rot)
		var hand_cam := Transform3D(gun_cam.basis * _l_rest.basis, Vector3.ZERO)
		var back_p := Vector3(-0.12, -0.13, -0.2)
		var fwd_p := Vector3(-0.02, 0.02, -0.5)
		var hp := back_p
		var hb := Basis.from_euler(Vector3(0.5, 0.5, 0.2))
		if not cook:
			var swing := _seg(f, 0.05, 0.32)
			hp = back_p.lerp(fwd_p, swing) + Vector3(0.0, 0.07, 0.0) * _bump(f, 0.05, 0.32)
			hb = Basis.from_euler(Vector3(0.5, 0.5, 0.2).lerp(Vector3(-0.4, 0.1, 0.0), swing))
		hand_cam = Transform3D(hb * hand_cam.basis, hp)
		throw_l = gun_cam.affine_inverse() * hand_cam
		throw_f = _fingers(Vector3(0.4, 0.5, 0.4), F_FIST, F_FIST)
		if not cook and f > 0.28:
			throw_f = _fingers(F_OPEN_THUMB, F_OPEN, F_OPEN)
		# The hand leaves fast and comes back on the same spring.
		l_target = _lerp_xf(l_target, throw_l, _ss(throw_w * 1.6))
		l_fingers = _blend_f(l_fingers, throw_f, _ss(throw_w * 1.6))
		l_snap = 0.0
		trigger_off = maxf(trigger_off, hold * 0.5)
	# --- Idle check: after a quiet moment, look the weapon over.
	if _fidget_t >= 0.0:
		var f := _fidget_t / 2.6
		var look := _seg(f, 0.0, 0.25) * (1.0 - _seg(f, 0.7, 1.0))
		pos += Vector3(-0.035, 0.025, 0.05) * look
		rot += Vector3(0.12, -0.35, 0.5) * look
		var regrip := _bump(f, 0.55, 0.75)
		l_target = _offset(l_target, Vector3(0.0, -0.012, 0.018) * regrip)
		l_snap = 0.0
		l_fingers = _blend_f(l_fingers, _fingers(F_OPEN_THUMB * 0.6, F_OPEN * 0.6, F_OPEN * 0.6), regrip)
		r_fingers[0] = Vector3(-0.3, -0.25, -0.15) * _bump(f, 0.3, 0.45)

	# --- Fingers: squeeze when firing, aiming and landing, plus small life.
	_squeeze = move_toward(_squeeze, 0.0, dt * 5.0)
	var tight := clampf(_squeeze + ads * 0.35, 0.0, 1.0)
	var squeeze := Vector3(0.05, 0.07, 0.05) * tight
	for i in 5:
		var life := Vector3(sin(_t * 1.3 + i * 1.7), sin(_t * 0.9 + i * 2.3), sin(_t * 1.7 + i * 0.9)) * 0.018 * lerpf(1.0, 0.3, ads)
		var lf: Vector3 = l_fingers[i]
		var rf: Vector3 = r_fingers[i]
		l_fingers[i] = lf + squeeze + life
		r_fingers[i] = rf + squeeze + life * 0.6
	# Trigger finger: pull on each shot, rest on the frame when not ready.
	var r_index: Vector3 = r_fingers[1]
	var off := _ss(clampf(trigger_off, 0.0, 1.0))
	r_index = r_index.lerp(F_TRIGGER_OFF, off) + F_TRIGGER_PULL * _trigger * (1.0 - off)
	r_fingers[1] = r_index
	_trigger = move_toward(_trigger, 0.0, dt * 9.0)
	_dry = move_toward(_dry, 0.0, dt * 4.0)

	# --- Compose and apply.
	var xf := _compose(pos, rot)
	gun.transform = xf
	_l_free = 1.0 if l_snap < 1.0 else move_toward(_l_free, 0.0, dt * 5.0)
	_r_free = 1.0 if r_snap < 1.0 else move_toward(_r_free, 0.0, dt * 5.0)
	if _rig_l:
		_rig_l.update_fingers(l_fingers, dt)
		_rig_l.drive(l_target, dt, 1.0 - _l_free)
		_rig_l.apply(xf)
	if _rig_r:
		_rig_r.update_fingers(r_fingers, dt)
		_rig_r.drive(r_target, dt, 1.0 - _r_free)
		_rig_r.apply(xf)
	if _mag:
		if mag_attached and _rig_l:
			mag_xf = _rig_l.hand_gun * _l_mag_grab.affine_inverse()
		_set_mag(mag_xf)
		_mag.visible = mag_visible
	if _shell:
		_shell.visible = shell_visible
	if _flash_t > 0.0:
		_flash_t -= dt
		if _flash_light:
			_flash_light.light_energy *= 0.7
		if _flash_t <= 0.0:
			if _flash:
				_flash.visible = false
			if _flash_light:
				_flash_light.light_energy = 0.0
	# Hide the gun when fully scoped with a sniper scope (HUD overlay takes over).
	var scoped := w != null and w.is_scoped() and ads_raw > 0.92
	gun.visible = not scoped
	for p in _stock_parts:
		p.visible = ads_raw < 0.6


func _compose(pos: Vector3, rot: Vector3) -> Transform3D:
	var b := Basis.from_euler(rot)
	return Transform3D(b, pos + PIVOT - b * PIVOT)


static func _blend_f(a: Array, b: Array, t: float) -> Array:
	var out := []
	for i in 5:
		var x: Vector3 = a[i]
		var y: Vector3 = b[i]
		out.append(x.lerp(y, clampf(t, 0.0, 1.0)))
	return out


func _update_timers(dt: float, w: WeaponState) -> void:
	# Swaps: detect the start, lower until the weapon changes, then raise.
	var st := soldier.swap_timer
	if st > 0.0 and _prev_swap_timer <= 0.0 and Engine.get_process_frames() != _changed_frame:
		_swap_total = st
		_lowering = true
		_reload_t = -1.0
		_cancel_rack()
	_prev_swap_timer = st
	if _lowering and st > 0.0:
		_lower = clampf((_swap_total - st) / maxf(_swap_total * 0.5, 0.01), 0.0, 1.0)
	else:
		_lowering = false
		_lower = move_toward(_lower, 0.0, dt * 6.0)
	_raise = minf(_raise + dt / _raise_len, 1.0)
	_alt_anim = move_toward(_alt_anim, 0.0, dt / 0.45)
	if _reload_t >= 0.0:
		_reload_t += dt
	if _chamber_t >= 0.0:
		_chamber_t += dt
		if _chamber_t > _chamber_len:
			_chamber_t = -1.0
	if _reload_t >= 0.0 and (w == null or not w.reloading):
		# The reload stopped early (a shot, a swap or a mode change).
		_reload_t = -1.0
		_set_mag(_mag_rest)
		if _mag:
			_mag.visible = true
	if _rack_delay > 0.0:
		_rack_delay -= dt
		if _rack_delay <= 0.0:
			_rack_delay = 0.0
			_rack_t = 0.0
			_rack_prev = 0.0
	elif _rack_t >= 0.0:
		_rack_prev = _rack_t / 0.85
		_rack_t += dt
		if _rack_t > 0.85 or (w and w.reloading):
			_rack_t = -1.0
	if _melee_t >= 0.0:
		_melee_t += dt
		if _melee_t > _melee_len:
			_melee_t = -1.0
	if _throw_t >= 0.0:
		_throw_t += dt
		if _throw_t > 0.75:
			_throw_t = -1.0
	if _fidget_t >= 0.0:
		_fidget_t += dt
		if _fidget_t > 2.6:
			_fidget_t = -1.0
	# Idle time: no movement, shots, aiming, actions or fast looks.
	var busy := soldier.velocity.length() > 0.3 or soldier.ads > 0.01 or soldier.sprinting or _reload_t >= 0.0 \
		or _chamber_t >= 0.0 or _melee_t >= 0.0 or _throw_t >= 0.0 or soldier.lethal_cook >= 0.0 \
		or _look_vel.length() > 400.0 or st > 0.0 or soldier.input.fire
	if busy:
		_idle_t = 0.0
		if _fidget_t >= 0.0 and _fidget_t < 2.2 and (soldier.ads > 0.01 or soldier.input.fire or soldier.sprinting):
			_fidget_t = maxf(_fidget_t, 2.2) # leave the check quickly
	else:
		_idle_t += dt
		if _idle_t > 9.0 and _fidget_t < 0.0:
			_fidget_t = 0.0
			_idle_t = -randf_range(0.0, 6.0)


# --- Action poses --------------------------------------------------------------------
# Each pose function returns weapon offsets (pos, rot) and hand targets in
# weapon space. f runs from 0 to 1 over the action.

func _reload_pose(w: WeaponState, dt: float) -> Dictionary:
	var out := {"pos": Vector3.ZERO, "rot": Vector3.ZERO, "l": _l_rest, "lf": _fingers(F_ZERO, F_ZERO, F_ZERO),
		"mag": _mag_rest, "attached": false, "mag_visible": true, "shell": false, "r_thumb": 0.0}
	if w.shell_reload and not w.alt_mode:
		return _shell_pose(out, dt)
	var f := clampf(_reload_t / _reload_total, 0.0, 1.0)
	var prev := _reload_prev
	_reload_prev = f
	if w.alt_mode or not _has_mag_mesh or w.data.weapon_class == "launcher":
		return _load_pose(out, f, prev, _under if w.alt_mode else _mag_rest.origin)
	if _pistol:
		return _pistol_reload_pose(out, f, prev)
	return _mag_reload_pose(out, f, prev)


func _mag_reload_pose(out: Dictionary, f: float, prev: float) -> Dictionary:
	# Empty reloads add a charging-handle rack after the magazine change.
	var e := 0.78 if _reload_empty else 1.0
	var g := f / e # magazine phase time
	var gp := prev / e
	var v := _rv
	# Weapon posture: cant right, muzzle up and left, towards the centre.
	var tilt := _seg(g, 0.0, 0.16) * (1.0 - _seg(g, 0.78, 1.0))
	if _reload_empty:
		tilt = _seg(g, 0.0, 0.16) * (1.0 - _seg(f, 0.58, 0.66) * 0.6) * (1.0 - _seg(f, 0.88, 1.0))
	out["rot"] = Vector3(0.12 + v.x * 0.03, 0.05 + v.y * 0.04, -0.55 + v.z * 0.05) * tilt
	out["pos"] = Vector3(-0.05, 0.04, -0.02) * tilt
	# Magazine path, weapon space.
	var dir := _mag_out_dir()
	var side := Vector3(-0.09, 0.0, 0.07) + Vector3(v.x, 0.0, v.y) * 0.015
	var m_unseat := _mag_rest.translated(dir * 0.05)
	var m_gone := Transform3D(Basis.from_euler(Vector3(0.4, 0.2, 0.6)) * _mag_rest.basis, _mag_rest.origin + dir * 0.34 + side)
	var m_ready := Transform3D(Basis.from_euler(Vector3(0.22, 0.0, 0.05)) * _mag_rest.basis, _mag_rest.origin + dir * 0.075 + Vector3(-0.008, 0.0, 0.012))
	var m_lip := Transform3D(Basis.from_euler(Vector3(0.12, 0.0, 0.0)) * _mag_rest.basis, _mag_rest.origin + dir * 0.025 + Vector3(0.0, 0.0, -0.004))
	var mag := _mag_rest
	if g < 0.22:
		mag = _mag_rest
	elif g < 0.3:
		mag = _lerp_xf(_mag_rest, m_unseat, _seg(g, 0.22, 0.3))
	elif g < 0.44:
		mag = _lerp_xf(m_unseat, m_gone, _ss((g - 0.3) / 0.14) * 0.6 + pow((g - 0.3) / 0.14, 2.0) * 0.4)
	elif g < 0.6:
		mag = _lerp_xf(m_gone, m_ready, 1.0 - pow(1.0 - (g - 0.44) / 0.16, 2.5))
	elif g < 0.66:
		mag = _lerp_xf(m_ready, m_lip, _seg(g, 0.6, 0.66))
	elif g < 0.71:
		mag = _lerp_xf(m_lip, _mag_rest, _seg(g, 0.66, 0.71))
	out["mag"] = mag
	out["attached"] = g >= 0.2 and g < 0.74
	# Left hand: leave the handguard, take the magazine, carry it, seat it,
	# slap it, then go back (or rack first on an empty reload).
	var grab := _mag_rest * _l_mag_grab
	var hand := _l_rest
	if g < 0.2:
		var k := _seg(g, 0.02, 0.18)
		hand = _lerp_xf(_l_rest, grab, k)
		hand.origin += Vector3(-0.02, -0.035, 0.03) * _bump(g, 0.02, 0.18)
		out["lf"] = _blend_f(_fingers(F_OPEN_THUMB, F_OPEN, F_OPEN), _fingers(Vector3(0.15, 0.2, 0.1), F_MAG, F_MAG), _seg(g, 0.13, 0.2))
	elif g < 0.74:
		hand = mag * _l_mag_grab
		out["lf"] = _fingers(Vector3(0.15, 0.2, 0.1), F_MAG, F_MAG)
		# Palm slap after the magazine seats.
		var slap := _bump(g, 0.705, 0.74)
		hand.origin += _mag_rest.basis * Vector3(0.0, 0.012, 0.0) * slap
		if slap > 0.0:
			out["lf"] = _fingers(F_OPEN_THUMB * 0.5, F_OPEN * 0.4, F_OPEN * 0.4)
	elif not _reload_empty:
		var k := _seg(g, 0.74, 0.93)
		hand = _lerp_xf(grab, _l_rest, k)
		hand.origin += Vector3(-0.015, -0.025, 0.02) * _bump(g, 0.74, 0.93)
		out["lf"] = _regrip(g, 0.78, 0.98)
	else:
		out["lf"] = _fingers(F_OPEN_THUMB, F_OPEN, F_OPEN)
		var rack := _rack_hand(f, 0.58, 1.0, grab)
		hand = rack["l"]
		out["lf"] = rack["lf"]
		out["rot"] += rack["rot"]
		out["pos"] += rack["pos"]
		if _cross(prev, f, 0.769):
			_rack_release()
	out["l"] = hand
	# Right thumb presses the magazine release.
	out["r_thumb"] = _bump(g, 0.16, 0.26)
	# Events.
	if _cross(gp, g, 0.23):
		Sfx.play_2d("reload_out", -6.0, randf_range(0.95, 1.05))
		_sway_p.kick(Vector3(0.0, -0.18, 0.0))
		_sway_r.kick(Vector3(-0.35, 0.0, 0.25))
	if _cross(gp, g, 0.66):
		_sway_p.kick(Vector3(0.0, 0.1, 0.0))
	if _cross(gp, g, 0.71):
		Sfx.play_2d("reload_in", -6.0, randf_range(0.95, 1.05))
		_sway_p.kick(Vector3(0.0, 0.45, -0.05))
		_sway_r.kick(Vector3(0.9, randf_range(-0.2, 0.2), -0.35))
		_squeeze = 1.0
	return out


## Left hand racks the charging handle over [a, b] of f, coming from hand_from.
func _rack_hand(f: float, a: float, b: float, hand_from: Transform3D) -> Dictionary:
	var u := clampf((f - a) / (b - a), 0.0, 1.0)
	var on := _over_top(_l_rest, _l_center, _rack_point)
	var pulled := on.translated(Vector3(0.0, 0.004, 0.065 if not _pistol else 0.04))
	var hand := hand_from
	var lf := _fingers(F_OPEN_THUMB, F_OPEN, F_OPEN)
	if u < 0.3:
		hand = _lerp_xf(hand_from, on, _seg(u, 0.0, 0.28))
		hand.origin += Vector3(-0.02, 0.05, 0.02) * _bump(u, 0.0, 0.28)
		lf = _blend_f(lf, _fingers(F_PINCH_THUMB, F_PINCH_INDEX, F_PINCH), _seg(u, 0.2, 0.3))
	elif u < 0.45:
		# Pull back hard to the stop.
		var k := (u - 0.3) / 0.15
		hand = _lerp_xf(on, pulled, k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7)
		lf = _fingers(F_PINCH_THUMB, F_PINCH_INDEX, F_PINCH)
	elif u < 0.5:
		hand = pulled
		lf = _fingers(F_OPEN_THUMB * 0.6, F_OPEN * 0.5, F_OPEN * 0.5)
	else:
		hand = _lerp_xf(pulled, _l_rest, _seg(u, 0.5, 0.92))
		hand.origin += Vector3(-0.02, 0.03, 0.02) * _bump(u, 0.5, 0.92)
		lf = _regrip(u, 0.7, 1.0)
	var t := _seg(u, 0.0, 0.25) * (1.0 - _seg(u, 0.55, 0.95))
	return {"l": hand, "lf": lf, "rot": Vector3(-0.05, -0.25, 0.3) * t, "pos": Vector3(0.0, -0.02, -0.05) * t}


func _cancel_rack() -> void:
	_rack_t = -1.0
	_rack_delay = 0.0


func _rack_release() -> void:
	Sfx.play_2d("reload_in", -5.0, 1.25)
	_sway_p.kick(Vector3(0.0, 0.08, -0.35))
	_sway_r.kick(Vector3(0.5, 0.25, -0.6))
	_squeeze = 1.0


func _rack_pose(f: float) -> Dictionary:
	var res := _rack_hand(f, 0.0, 1.0, _l_rest)
	if _cross(_rack_prev, f, 0.46):
		_rack_release()
	return {"pos": res["pos"], "rot": res["rot"], "l": res["l"], "lf": res["lf"]}


func _pistol_reload_pose(out: Dictionary, f: float, prev: float) -> Dictionary:
	var e := 0.8 if _reload_empty else 1.0
	var g := f / e
	var gp := prev / e
	var v := _rv
	var tilt := _seg(g, 0.0, 0.14) * (1.0 - _seg(g, 0.8, 1.0))
	if _reload_empty:
		tilt = _seg(g, 0.0, 0.14) * (1.0 - _seg(f, 0.82, 1.0))
	out["rot"] = Vector3(0.2 + v.x * 0.04, 0.3 + v.y * 0.05, -0.4 + v.z * 0.05) * tilt
	out["pos"] = Vector3(-0.06, 0.03, -0.01) * tilt
	# The empty magazine falls free; the support hand fetches a new one.
	var dir := _mag_out_dir()
	var mag := _mag_rest
	var shown := true
	if g >= 0.12 and g < 0.4:
		var t := (g - 0.12) * _reload_total * e
		mag = Transform3D(Basis.from_euler(Vector3(t * 2.0, 0.0, t * 1.5)) * _mag_rest.basis, _mag_rest.origin + dir * (0.02 + 4.9 * t * t) + Vector3(-0.02, 0.0, 0.01) * t)
		shown = t < 0.25
	elif g >= 0.4:
		shown = true
	var m_ready := Transform3D(Basis.from_euler(Vector3(0.15, 0.0, 0.0)) * _mag_rest.basis, _mag_rest.origin + dir * 0.06)
	var m_low := Transform3D(_mag_rest.basis, _mag_rest.origin + dir * 0.3 + Vector3(-0.08, 0.0, 0.06))
	var hand := _l_rest
	if g < 0.4:
		var k := _seg(g, 0.08, 0.38)
		hand = _lerp_xf(_l_rest, m_low * _l_mag_grab, k)
		out["lf"] = _fingers(F_OPEN_THUMB, F_OPEN, F_OPEN)
		if g < 0.12:
			shown = true
			mag = _mag_rest
	elif g < 0.74:
		var mg := m_low
		if g < 0.58:
			mg = _lerp_xf(m_low, m_ready, 1.0 - pow(1.0 - (g - 0.4) / 0.18, 2.5))
		elif g < 0.66:
			mg = _lerp_xf(m_ready, _mag_rest, _seg(g, 0.58, 0.66))
		else:
			mg = _mag_rest
		mag = mg
		out["attached"] = g < 0.68
		hand = mg * _l_mag_grab
		hand.origin += Vector3(0.0, 0.012, 0.0) * _bump(g, 0.66, 0.74)
		out["lf"] = _fingers(Vector3(0.15, 0.2, 0.1), F_MAG, F_MAG)
	elif not _reload_empty:
		hand = _lerp_xf(_mag_rest * _l_mag_grab, _l_rest, _seg(g, 0.74, 0.94))
		out["lf"] = _regrip(g, 0.8, 1.0)
	else:
		var rack := _rack_hand(f, 0.79, 1.0, _mag_rest * _l_mag_grab)
		hand = rack["l"]
		out["lf"] = rack["lf"]
		out["rot"] += rack["rot"]
		if _cross(prev, f, 0.885):
			_rack_release()
	out["l"] = hand
	out["mag"] = mag
	out["mag_visible"] = shown
	out["r_thumb"] = _bump(g, 0.06, 0.16)
	if _cross(gp, g, 0.12):
		Sfx.play_2d("reload_out", -6.0, 1.15)
		_sway_r.kick(Vector3(0.3, 0.0, 0.2))
	if _cross(gp, g, 0.66):
		Sfx.play_2d("reload_in", -6.0, 1.1)
		_sway_p.kick(Vector3(0.0, 0.35, 0.0))
		_sway_r.kick(Vector3(0.7, 0.0, -0.2))
		_squeeze = 1.0
	return out


## Reloads without a visible magazine (revolver, break action, launchers,
## internal magazines, underbarrel): the hand fetches and pushes in a load.
func _load_pose(out: Dictionary, f: float, prev: float, port: Vector3) -> Dictionary:
	var v := _rv
	var tilt := _seg(f, 0.0, 0.15) * (1.0 - _seg(f, 0.8, 1.0))
	out["rot"] = Vector3(0.35 + v.x * 0.04, -0.2 + v.y * 0.05, 0.45 + v.z * 0.05) * tilt
	out["pos"] = Vector3(-0.02, -0.01, 0.02) * tilt
	var at_port := _l_rest.translated(port + Vector3(0.0, -0.02, 0.0) - _l_center)
	var low := _l_rest.translated(Vector3(-0.1, -0.3, 0.12))
	var hand := _l_rest
	if f < 0.35:
		hand = _lerp_xf(_l_rest, low, _seg(f, 0.05, 0.33))
		out["lf"] = _fingers(F_OPEN_THUMB, F_OPEN, F_OPEN)
	elif f < 0.62:
		hand = _lerp_xf(low, at_port, 1.0 - pow(1.0 - (f - 0.35) / 0.27, 2.5))
		out["lf"] = _fingers(Vector3(0.4, 0.5, 0.4), F_FIST, F_FIST)
	elif f < 0.76:
		hand = at_port.translated(Vector3(0.0, 0.025, -0.01) * _seg(f, 0.62, 0.72))
		out["lf"] = _fingers(Vector3(0.4, 0.5, 0.4), F_FIST, F_FIST)
	else:
		hand = _lerp_xf(at_port, _l_rest, _seg(f, 0.76, 0.94))
		out["lf"] = _regrip(f, 0.8, 1.0)
	out["l"] = hand
	if _cross(prev, f, 0.71):
		Sfx.play_2d("reload_in", -6.0, randf_range(0.9, 1.0))
		_sway_p.kick(Vector3(0.0, 0.3, -0.1))
		_sway_r.kick(Vector3(0.6, 0.0, 0.0))
	return out


## One shell per cycle: fetch from the belt, push into the port with the thumb.
func _shell_pose(out: Dictionary, _dt: float) -> Dictionary:
	var f := clampf(_reload_t / _shell_cycle, 0.0, 1.0)
	if _shell_first:
		# The first cycle includes the lift into the loading position.
		f = clampf((_reload_t - (_shell_cycle - _reload_total)) / _reload_total, 0.0, 1.0)
	var lift := _ss(_reload_t / 0.25) if _shell_first else 1.0
	out["rot"] = Vector3(0.18, -0.15, -0.55) * lift
	out["pos"] = Vector3(-0.03, -0.02, 0.02) * lift
	var port := Vector3(0.0, _mag_rest.origin.y - 0.035, _mag_rest.origin.z + 0.08)
	var at_port := _l_rest.translated(port - _l_center + Vector3(-0.005, -0.012, 0.0))
	var pushed := at_port.translated(Vector3(0.0, 0.02, -0.035))
	var belt := _l_rest.translated(Vector3(-0.07, -0.2, 0.12))
	var hand := _l_rest
	var shell := false
	if _shell_first and _reload_t < 0.25:
		hand = _lerp_xf(_l_rest, belt, _ss(_reload_t / 0.25) * 0.6)
		out["lf"] = _fingers(F_OPEN_THUMB, F_OPEN, F_OPEN)
	elif f < 0.3:
		hand = _lerp_xf(pushed, belt, _seg(f, 0.0, 0.3))
		out["lf"] = _fingers(F_OPEN_THUMB * 0.5, F_RELAX, F_RELAX)
	elif f < 0.72:
		hand = _lerp_xf(belt, at_port, 1.0 - pow(1.0 - (f - 0.3) / 0.42, 2.2))
		out["lf"] = _fingers(Vector3(0.35, 0.3, 0.2), F_PINCH_INDEX, F_PINCH)
		shell = f > 0.36
	else:
		hand = _lerp_xf(at_port, pushed, _seg(f, 0.72, 0.98))
		out["lf"] = _fingers(Vector3(0.1, -0.1, -0.2), F_PINCH_INDEX, F_PINCH)
		shell = f < 0.92
	out["l"] = hand
	out["shell"] = shell
	return out


func _bolt_pose(f: float) -> Dictionary:
	# Right hand: off the grip, lift the bolt, pull, push, lock down, back.
	var knob := Vector3(0.058, 0.066, 0.04)
	var at_knob := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -0.5)) * _r_rest.basis, _r_rest.origin + (knob - _r_center) + Vector3(0.0, -0.02, 0.0))
	var lifted := at_knob.translated(Vector3(-0.012, 0.022, 0.0))
	var back := lifted.translated(Vector3(0.0, 0.0, 0.075))
	var hand := _r_rest
	var fingers := _fingers(F_PINCH_THUMB, F_PINCH_INDEX, F_PINCH)
	if f < 0.2:
		hand = _lerp_xf(_r_rest, at_knob, _seg(f, 0.0, 0.2))
		fingers = _blend_f(_fingers(F_OPEN_THUMB, F_OPEN, F_OPEN), fingers, _seg(f, 0.12, 0.2))
	elif f < 0.28:
		hand = _lerp_xf(at_knob, lifted, _seg(f, 0.2, 0.28))
	elif f < 0.42:
		hand = _lerp_xf(lifted, back, _seg(f, 0.28, 0.42))
	elif f < 0.58:
		hand = _lerp_xf(back, lifted, _seg(f, 0.46, 0.58))
	elif f < 0.66:
		hand = _lerp_xf(lifted, at_knob, _seg(f, 0.58, 0.66))
	else:
		hand = _lerp_xf(at_knob, _r_rest, _seg(f, 0.68, 0.9))
		fingers = _regrip(f, 0.75, 0.95)
	var t := _seg(f, 0.0, 0.2) * (1.0 - _seg(f, 0.7, 1.0))
	if _cross(_chamber_prev, f, 0.38):
		Sfx.play_2d("reload_out", -7.0, 1.3)
		_sway_p.kick(Vector3(0.0, 0.0, 0.15))
	if _cross(_chamber_prev, f, 0.56):
		Sfx.play_2d("reload_in", -6.0, 1.35)
		_sway_p.kick(Vector3(0.0, 0.05, -0.2))
		_sway_r.kick(Vector3(0.3, -0.2, 0.3))
	return {"pos": Vector3(0.0, -0.015, 0.01) * t, "rot": Vector3(-0.05, 0.1, 0.22) * t, "r": hand, "rf": fingers}


func _pump_pose(f: float) -> Dictionary:
	# Left hand drives the fore-end back to the stop and forward again.
	var back := _l_rest.translated(Vector3(0.0, -0.004, 0.07))
	var hand := _l_rest
	if f < 0.4:
		hand = _lerp_xf(_l_rest, back, _seg(f, 0.08, 0.32))
	else:
		hand = _lerp_xf(back, _l_rest, _seg(f, 0.4, 0.62))
	if _cross(_chamber_prev, f, 0.3):
		Sfx.play_2d("reload_out", -6.0, 1.4)
		_sway_p.kick(Vector3(0.0, -0.08, 0.3))
		_sway_r.kick(Vector3(-0.4, 0.0, 0.3))
	if _cross(_chamber_prev, f, 0.58):
		Sfx.play_2d("reload_in", -6.0, 1.3)
		_sway_p.kick(Vector3(0.0, 0.05, -0.3))
		_sway_r.kick(Vector3(0.4, 0.0, -0.2))
	var t := _bump(f, 0.05, 0.7)
	return {"pos": Vector3(0.0, -0.01, 0.01) * t, "rot": Vector3(-0.06, 0.05, 0.12) * t, "l": hand}


## Fingers open as the hand arrives, then close on the grip one by one
## (index first, pinky last).
func _regrip(f: float, a: float, b: float) -> Array:
	var out := []
	var span := b - a
	for i in 5:
		var delay := (0.0 if i == 0 else float(i - 1) * 0.08) * span
		var k := _seg(f, a + delay, a + delay + span * 0.6)
		var open: Vector3 = F_OPEN_THUMB if i == 0 else F_OPEN
		out.append(open.lerp(F_ZERO, k))
	return out

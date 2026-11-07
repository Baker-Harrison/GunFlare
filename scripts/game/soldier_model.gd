class_name SoldierModel
extends Node3D
## Third-person body: a jointed rig animated procedurally (walk, sprint,
## crouch, prone, aim pitch, recoil), with per-zone hitboxes, and a physics
## ragdoll on death. The visible body is the faction's skinned character
## (tools/blender/build_characters.py). A SkinFollower copies the joints onto
## its bones. Without that file, built-in primitives are used.

const FACTIONS := [
	{"name": "Task Force Sentinel", "fatigue": Color(0.36, 0.38, 0.27), "fatigue2": Color(0.55, 0.5, 0.36),
		"vest": Color(0.27, 0.27, 0.2), "helmet": Color(0.33, 0.35, 0.26), "skin": Color(0.78, 0.6, 0.48),
		"boots": Color(0.24, 0.19, 0.13), "gloves": Color(0.2, 0.2, 0.17), "camo": 0},
	{"name": "Black Sun Militia", "fatigue": Color(0.2, 0.21, 0.23), "fatigue2": Color(0.33, 0.32, 0.31),
		"vest": Color(0.12, 0.12, 0.13), "helmet": Color(0.14, 0.15, 0.15), "skin": Color(0.66, 0.5, 0.4),
		"boots": Color(0.08, 0.08, 0.08), "gloves": Color(0.07, 0.07, 0.07), "camo": 1},
]

var soldier: Soldier
var faction := 0

var pelvis: Node3D
var torso: Node3D
var chest: Node3D
var head_node: Node3D
var hips: Array[Node3D] = []
var knees: Array[Node3D] = []
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []
var gun_mount: Node3D
var gun_model: Node3D
var _meshes: Array[MeshInstance3D] = []
var _hitboxes: Array[Area3D] = []
var _ragdoll_bodies: Array[RigidBody3D] = []
var _first_person := false
var _phase := 0.0
var _fire_kick := 0.0
var _melee_t := 0.0
var _jump_t := 0.0
var _lean := 0.0
var _crouch := 0.0
var _prone := 0.0
var _dead := false
var _gun_weapon_id := ""


func _ready() -> void:
	faction = clampi(soldier.team if soldier else 0, 0, FACTIONS.size() - 1)
	_build_rig()
	if soldier:
		soldier.weapon_changed.connect(_on_weapon_changed)


func set_first_person(on: bool) -> void:
	_first_person = on
	for m in _meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if gun_model:
		_set_shadow_only(gun_model, on)


func set_faction(f: int) -> void:
	if f == faction or pelvis == null:
		faction = f
		return
	faction = f
	for c in get_children():
		c.queue_free()
	_meshes.clear()
	_hitboxes.clear()
	hips.clear()
	knees.clear()
	shoulders.clear()
	elbows.clear()
	gun_model = null
	_gun_weapon_id = ""
	_build_rig()
	set_first_person(_first_person)


# --- Rig construction --------------------------------------------------------

func _mat(c: Color, rough := 0.85, camo := false) -> Material:
	if camo:
		return CamoLibrary.fabric_material(c, FACTIONS[faction]["fatigue2"], FACTIONS[faction]["camo"])
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	_meshes.append(mi)
	return mi


func _joint(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	return j


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _hitbox(parent: Node3D, zone: String, shape: Shape3D, pos: Vector3) -> void:
	var a := Area3D.new()
	a.collision_layer = Layers.HITBOX
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	a.set_meta("soldier", soldier)
	a.set_meta("zone", zone)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	a.position = pos
	a.add_child(cs)
	parent.add_child(a)
	_hitboxes.append(a)


func _build_rig() -> void:
	var f: Dictionary = FACTIONS[faction]
	var fatigue := _mat(f["fatigue"], 0.9, true)
	var vest := _mat(f["vest"], 0.8)
	var helmet := _mat(f["helmet"], 0.6)
	var skin := _mat(f["skin"], 0.6)
	var boots := _mat(f["boots"], 0.7)
	var gloves := _mat(f["gloves"], 0.75)
	var dark := _mat(Color(0.08, 0.08, 0.08), 0.5)

	pelvis = _joint(self, "Pelvis", Vector3(0, 0.95, 0))
	_part(pelvis, _box(Vector3(0.36, 0.2, 0.22)), fatigue, Vector3(0, 0, 0))
	_part(pelvis, _box(Vector3(0.38, 0.06, 0.24)), dark, Vector3(0, 0.08, 0)) # belt

	torso = _joint(pelvis, "Torso", Vector3(0, 0.08, 0))
	_part(torso, _capsule(0.2, 0.62), fatigue, Vector3(0, 0.3, 0), Vector3(0, 0, 0)).scale = Vector3(1.05, 1.0, 0.68)
	_part(torso, _box(Vector3(0.42, 0.42, 0.3)), vest, Vector3(0, 0.34, 0)) # plate carrier
	for i in 3: # mag pouches
		_part(torso, _box(Vector3(0.09, 0.13, 0.06)), vest, Vector3(-0.11 + i * 0.11, 0.26, -0.18))
	_part(torso, _box(Vector3(0.3, 0.3, 0.12)), vest, Vector3(0, 0.36, 0.2)) # back pack
	_part(torso, _box(Vector3(0.04, 0.2, 0.03)), dark, Vector3(0.12, 0.42, -0.165)) # radio
	_hitbox(torso, "chest", _box_shape(Vector3(0.46, 0.62, 0.34)), Vector3(0, 0.32, 0))
	_hitbox(pelvis, "chest", _box_shape(Vector3(0.38, 0.24, 0.26)), Vector3(0, 0, 0))

	head_node = _joint(torso, "Head", Vector3(0, 0.7, 0))
	_part(head_node, _capsule(0.055, 0.12), skin, Vector3(0, -0.06, 0)) # neck
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.11
	head_mesh.height = 0.25
	_part(head_node, head_mesh, skin, Vector3(0, 0.07, 0))
	var helm := SphereMesh.new()
	helm.radius = 0.135
	helm.height = 0.2
	helm.is_hemisphere = true
	_part(head_node, helm, helmet, Vector3(0, 0.1, 0.005))
	_part(head_node, _box(Vector3(0.28, 0.025, 0.29)), helmet, Vector3(0, 0.1, 0)) # rim
	_part(head_node, _box(Vector3(0.17, 0.05, 0.03)), dark, Vector3(0, 0.07, -0.105)) # goggles strap / eyes
	_part(head_node, _box(Vector3(0.05, 0.05, 0.05)), dark, Vector3(0, 0.19, -0.11)) # NVG mount
	var hs := SphereShape3D.new()
	hs.radius = 0.15
	_hitbox(head_node, "head", hs, Vector3(0, 0.07, 0))

	chest = _joint(torso, "Chest", Vector3(0, 0.52, 0))
	for side in [-1, 1]:
		var sh := _joint(chest, "Shoulder", Vector3(0.23 * side, 0.02, 0))
		_part(sh, _sphere(0.075), vest, Vector3.ZERO) # shoulder socket cap
		_part(sh, _capsule(0.065, 0.32), fatigue, Vector3(0, -0.14, 0))
		_part(sh, _box(Vector3(0.13, 0.1, 0.14)), vest, Vector3(0, -0.02, 0)) # shoulder pad
		var el := _joint(sh, "Elbow", Vector3(0, -0.29, 0))
		_part(el, _sphere(0.06), fatigue, Vector3.ZERO) # elbow socket cap
		_part(el, _capsule(0.055, 0.3), fatigue, Vector3(0, -0.13, 0))
		_part(el, _box(Vector3(0.08, 0.1, 0.11)), gloves, Vector3(0, -0.3, 0))
		_hitbox(sh, "limb", _box_shape(Vector3(0.14, 0.34, 0.14)), Vector3(0, -0.14, 0))
		shoulders.append(sh)
		elbows.append(el)
	gun_mount = _joint(chest, "GunMount", Vector3(0.06, -0.12, -0.38))

	for side in [-1, 1]:
		var hip := _joint(pelvis, "Hip", Vector3(0.11 * side, -0.06, 0))
		_part(hip, _sphere(0.095), dark, Vector3.ZERO) # hip socket cap
		_part(hip, _capsule(0.085, 0.48), fatigue, Vector3(0, -0.22, 0))
		_part(hip, _box(Vector3(0.1, 0.14, 0.08)), vest, Vector3(0.07 * side, -0.18, -0.03)) # thigh pocket
		var knee := _joint(hip, "Knee", Vector3(0, -0.44, 0))
		_part(knee, _sphere(0.075), vest, Vector3.ZERO) # knee socket cap
		_part(knee, _capsule(0.07, 0.46), fatigue, Vector3(0, -0.21, 0))
		_part(knee, _box(Vector3(0.1, 0.09, 0.1)), vest, Vector3(0, 0.0, -0.06)) # knee pad
		_part(knee, _box(Vector3(0.11, 0.12, 0.27)), boots, Vector3(0, -0.44, -0.04))
		_hitbox(hip, "limb", _box_shape(Vector3(0.18, 0.46, 0.18)), Vector3(0, -0.22, 0))
		_hitbox(knee, "limb", _box_shape(Vector3(0.16, 0.48, 0.2)), Vector3(0, -0.24, 0))
		hips.append(hip)
		knees.append(knee)
	_apply_character_model(fatigue)


const CHARACTER_FILES := ["res://assets/characters/soldier_sentinel", "res://assets/characters/soldier_militia"]
static var _char_scenes: Dictionary = {}
var _body: Node3D
var _follower: SkinFollower


static func _character_scene(f: int) -> PackedScene:
	var base: String = CHARACTER_FILES[clampi(f, 0, CHARACTER_FILES.size() - 1)]
	if _char_scenes.has(base):
		return _char_scenes[base]
	var scene: PackedScene = null
	for ext in [".gltf", ".glb"]:
		if ResourceLoader.exists(base + ext):
			scene = load(base + ext) as PackedScene
			break
	_char_scenes[base] = scene
	return scene


## Replace the primitive meshes with the faction's skinned character.
func _apply_character_model(_fatigue: Material) -> void:
	var scene := _character_scene(faction)
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	var found := inst.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		inst.free()
		return
	for mi in _meshes:
		mi.queue_free()
	_meshes.clear()
	inst.name = "Body"
	add_child(inst)
	_body = inst
	var skel := found[0] as Skeleton3D
	var map := {
		"Pelvis": pelvis, "Torso": torso, "Chest": chest, "Head": head_node,
		"ShoulderL": shoulders[0], "ElbowL": elbows[0], "ShoulderR": shoulders[1], "ElbowR": elbows[1],
		"HipL": hips[0], "KneeL": knees[0], "HipR": hips[1], "KneeR": knees[1],
	}
	_follower = SkinFollower.new()
	_follower.name = "SkinFollower"
	skel.add_child(_follower)
	_follower.setup(skel, map, self)
	_collect_meshes(inst)


func _collect_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes(c)


func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func _set_shadow_only(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_set_shadow_only(c, on)


func _on_weapon_changed(w: WeaponState) -> void:
	if w == null or gun_mount == null:
		return
	if w.data.id == _gun_weapon_id:
		return
	_gun_weapon_id = w.data.id
	if gun_model:
		gun_model.queue_free()
	gun_model = WeaponModels.create(w.data.id, w.attachments, w.camo)
	gun_mount.add_child(gun_model)
	_set_shadow_only(gun_model, _first_person)


func head_global_position() -> Vector3:
	return head_node.global_position + Vector3.UP * 0.07 if head_node else global_position + Vector3.UP * 1.65


# --- Animation ---------------------------------------------------------------

func reset_pose() -> void:
	if _dead:
		_clear_ragdoll()
	_dead = false
	visible = true
	for h in _hitboxes:
		h.set_deferred("monitorable", true)
		for c in h.get_children():
			c.set_deferred("disabled", false)


func on_fire() -> void:
	_fire_kick = 1.0


func on_melee() -> void:
	_melee_t = 1.0


func on_jump() -> void:
	_jump_t = 1.0


func _process(delta: float) -> void:
	if _dead or soldier == null or pelvis == null:
		return
	var local_v := soldier.global_basis.inverse() * soldier.velocity
	var speed := Vector2(local_v.x, local_v.z).length()
	var on_floor := soldier.is_on_floor()
	_crouch = move_toward(_crouch, 1.0 if soldier.stance == Soldier.Stance.CROUCH else 0.0, delta * 5.0)
	_prone = move_toward(_prone, 1.0 if soldier.stance == Soldier.Stance.PRONE else 0.0, delta * 3.5)
	_fire_kick = move_toward(_fire_kick, 0.0, delta * 12.0)
	_melee_t = move_toward(_melee_t, 0.0, delta * 3.0)
	_jump_t = move_toward(_jump_t, 0.0, delta * 2.0)
	_lean = lerpf(_lean, clampf(-local_v.x * 0.03, -0.12, 0.12), delta * 6.0)

	var stride := 2.4 if soldier.sprinting else 1.6
	if speed > 0.15:
		_phase += (speed * delta / stride) * TAU * 0.5
	else:
		_phase = move_toward(_phase, roundf(_phase / PI) * PI, delta * 9.0)
	var amt := clampf(speed / (stride * 1.6), 0.0, 1.0) * (1.0 - _prone)
	var swing := sin(_phase) * (0.68 if soldier.sprinting else 0.48) * amt
	var dir_sign := -1.0 if local_v.z > 0.2 else 1.0 # walking backwards

	# Pelvis height / body orientation per stance.
	var bob := absf(cos(_phase)) * 0.035 * amt
	var pelvis_y := lerpf(0.95, 0.6, _crouch)
	pelvis_y = lerpf(pelvis_y, 0.2, _prone) + bob
	if not on_floor:
		pelvis_y += 0.0
	pelvis.position = Vector3(0, pelvis_y, lerpf(0.0, 0.55, _prone))
	pelvis.rotation = Vector3(lerpf(0.0, -PI * 0.5, _prone), 0.0, _lean * (1.0 - _prone))

	var sprint_lean := 0.22 if soldier.sprinting else 0.0
	var aim_pitch := soldier.pitch
	var roll_lean := clampf(-local_v.x * 0.018, -0.08, 0.08) * (1.0 - _prone)
	torso.rotation = Vector3(-lerpf(sprint_lean + 0.05 * amt, 0.0, _prone) + _crouch * 0.15 - aim_pitch * 0.35 * (1.0 - _prone), 0.0, roll_lean)
	chest.rotation = Vector3(aim_pitch * lerpf(0.50, 0.0, _prone) + _fire_kick * 0.08 + (PI * 0.5 * _prone), 0.0, roll_lean * 0.5)
	head_node.rotation = Vector3(aim_pitch * 0.20 * (1.0 - _prone) + _prone * PI * 0.42, 0.0, 0.0)

	# Legs
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var leg := swing * s * dir_sign
		var hip_x := leg
		var knee_x := -maxf(0.0, -sin(_phase + (0.0 if i == 0 else PI))) * 0.9 * amt
		# Crouch: thighs forward, shins back.
		hip_x = lerpf(hip_x, 1.25 + leg * 0.3, _crouch)
		knee_x = lerpf(knee_x, -1.9, _crouch)
		if not on_floor:
			hip_x = 0.5 if i == 0 else -0.1
			knee_x = -0.8 if i == 0 else -0.3
		hip_x = lerpf(hip_x, sin(_phase) * 0.15 * s, _prone)
		knee_x = lerpf(knee_x, -0.15, _prone)
		hips[i].rotation = Vector3(hip_x, 0.0, s * -0.04 * _crouch)
		knees[i].rotation = Vector3(knee_x, 0.0, 0.0)

	# Arms hold the weapon: right on the grip, left on the handguard.
	var sprint_arm := 1.0 if soldier.sprinting else 0.0
	var melee_swing := sin(_melee_t * PI) * 1.2
	var right_up := Vector3(1.0 - sprint_arm * 0.5, 0.0, -0.3)
	var right_el := Vector3(1.0, 0.0, 0.0)
	var left_up := Vector3(1.3 - sprint_arm * 0.4 + melee_swing * 0.5, 0.0, 0.55)
	var left_el := Vector3(0.35, 0.0, 0.0)
	if shoulders.size() == 2:
		shoulders[1].rotation = right_up
		elbows[1].rotation = right_el
		shoulders[0].rotation = left_up
		elbows[0].rotation = left_el
	if gun_mount:
		gun_mount.position = Vector3(0.06, -0.12 - sprint_arm * 0.08, -0.38 + _fire_kick * 0.04)
		gun_mount.rotation = Vector3(-sprint_arm * 0.55, sprint_arm * 0.6, sprint_arm * 0.3)


# --- Death / ragdoll ---------------------------------------------------------

func die(impulse: Vector3, explosive: bool) -> void:
	_dead = true
	for h in _hitboxes:
		h.set_deferred("monitorable", false)
		for c in h.get_children():
			c.set_deferred("disabled", true)
	_build_ragdoll(impulse + Vector3.UP * (4.0 if explosive else 0.5))


func _build_ragdoll(impulse: Vector3) -> void:
	# Each limb segment becomes a rigid body; joints hold them together.
	var groups := [pelvis, torso, head_node] + shoulders + elbows + hips + knees
	var world := get_tree().current_scene
	if world == null:
		return
	var holder := Node3D.new()
	holder.name = "Ragdoll"
	world.add_child(holder)
	var body_of := {}
	for j: Node3D in groups:
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = Layers.WORLD
		rb.mass = 6.0 if j == torso or j == pelvis else 2.0
		rb.linear_damp = 0.4
		rb.angular_damp = 2.5
		holder.add_child(rb)
		rb.global_transform = j.global_transform
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.14, 0.36, 0.14) if j != torso else Vector3(0.38, 0.55, 0.26)
		if j == pelvis:
			sh.size = Vector3(0.34, 0.2, 0.22)
		elif j == head_node:
			sh.size = Vector3(0.22, 0.24, 0.22)
		cs.shape = sh
		cs.position = Vector3(0, -0.18, 0) if j in hips or j in knees or j in shoulders or j in elbows else (Vector3(0, 0.3, 0) if j == torso else Vector3.ZERO)
		rb.add_child(cs)
		# Move this joint's meshes onto the body, keeping world placement.
		for c in j.get_children():
			if c is MeshInstance3D or c.has_meta("part"):
				var gt: Transform3D = c.global_transform
				j.remove_child(c)
				rb.add_child(c)
				c.global_transform = gt
		body_of[j] = rb
		_ragdoll_bodies.append(rb)
		rb.apply_central_impulse(impulse * rb.mass * randf_range(0.6, 1.0))
	if _body and is_instance_valid(_body) and _follower:
		var bt := _body.global_transform
		remove_child(_body)
		holder.add_child(_body)
		_body.global_transform = bt
		_follower.retarget(body_of)
		_body = null
		_follower = null
	if gun_model and is_instance_valid(gun_model):
		var gt := gun_model.global_transform
		gun_model.get_parent().remove_child(gun_model)
		body_of[torso].add_child(gun_model)
		gun_model.global_transform = gt
		gun_model = null
		_gun_weapon_id = ""
	for j: Node3D in groups:
		var parent_joint := j.get_parent() as Node3D
		if j == pelvis or not body_of.has(parent_joint):
			continue
		var pin := ConeTwistJoint3D.new()
		holder.add_child(pin)
		pin.global_transform = j.global_transform
		pin.node_a = pin.get_path_to(body_of[parent_joint])
		pin.node_b = pin.get_path_to(body_of[j])
		pin.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(50.0))
		pin.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(25.0))
	visible = false
	var t := get_tree().create_timer(9.0)
	t.timeout.connect(func() -> void:
		if is_instance_valid(holder):
			holder.queue_free())
	_ragdoll_holder = holder
	# The live rig must be rebuilt for the next spawn.
	_rebuild_pending = true


var _ragdoll_holder: Node3D
var _rebuild_pending := false


func _clear_ragdoll() -> void:
	_ragdoll_bodies.clear()
	_ragdoll_holder = null
	if _rebuild_pending:
		_rebuild_pending = false
		for c in get_children():
			c.queue_free()
		_meshes.clear()
		_hitboxes.clear()
		hips.clear()
		knees.clear()
		shoulders.clear()
		elbows.clear()
		gun_model = null
		_gun_weapon_id = ""
		_build_rig()
		set_first_person(_first_person)
		if soldier and soldier.weapon():
			_on_weapon_changed(soldier.weapon())

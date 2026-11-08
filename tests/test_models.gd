extends Node
## Checks the modelled assets that tools/blender makes:
## - every weapon in ContentDB has a model with its markers and baked textures,
## - every attachment model loads,
## - each soldier has a skeleton with the 12 rig bones and a skinned mesh,
## - each set of first-person arms has ArmR, ArmL and ArmLPistol, each with a
##   hand skeleton (tools/rig_arms.py) and a skinned mesh.
## Run: godot --headless --path . res://tests/test_models.tscn

const BONES := ["Pelvis", "Torso", "Chest", "Head", "ShoulderL", "ElbowL", "ShoulderR", "ElbowR", "HipL", "KneeL", "HipR", "KneeR"]
const MARKERS := ["Muzzle", "Mag", "ADS", "LeftHand", "Optic", "Underbarrel"]
const ARM_BONES := ["Root", "Forearm", "Hand", "Thumb1", "Thumb2", "Thumb3", "Index1", "Index2", "Index3",
	"Middle1", "Middle2", "Middle3", "Ring1", "Ring2", "Ring3", "Pinky1", "Pinky2", "Pinky3"]
const ATTACHMENTS := ["reflex", "holo", "marksman_scope", "thermal", "suppressor", "underbarrel_gl", "underbarrel_shotgun", "grip", "pulse_tracker"]

var _failed := 0


func _ready() -> void:
	var ids: Array[String] = []
	for item in ContentDB.items_of_kind("weapon"):
		var model: String = (item as WeaponData).model
		if not model in ids:
			ids.append(model)
	_expect(ids.size() > 30, "ContentDB lists the weapons")
	for id in ids:
		_check_weapon(id)
	for att in ATTACHMENTS:
		var p := WeaponModels.model_path("attachments", att)
		_expect(p != "" and load(p) is PackedScene, "attachment model %s" % att)
	for f in ["sentinel", "militia"]:
		_check_soldier("res://assets/characters/soldier_%s.gltf" % f)
		_check_arms("res://assets/characters/arms_%s.gltf" % f)
	print("model checks: %d failed" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		printerr("MODEL CHECK FAILED: ", what)
		_failed += 1


func _check_weapon(id: String) -> void:
	var p := WeaponModels.model_path("weapons", id)
	_expect(p.ends_with(".gltf"), "weapon %s has a glTF model" % id)
	if p == "":
		return
	var inst := (load(p) as PackedScene).instantiate()
	for m in MARKERS:
		_expect(inst.find_child(m, true, false) != null, "weapon %s has marker %s" % [id, m])
	var textured := false
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var bm := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if bm and bm.albedo_texture and bm.normal_texture and bm.normal_enabled:
				textured = true
	_expect(textured, "weapon %s has baked albedo and normal textures" % id)
	inst.free()


func _check_soldier(path: String) -> void:
	_expect(ResourceLoader.exists(path), "soldier file %s" % path)
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate()
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	_expect(skels.size() == 1, "%s has one skeleton" % path)
	if skels.size() == 1:
		var sk := skels[0] as Skeleton3D
		for b in BONES:
			_expect(sk.find_bone(b) >= 0, "%s has bone %s" % [path, b])
		var skinned := false
		for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
			if mi.skin != null:
				skinned = true
		_expect(skinned, "%s has a skinned mesh" % path)
	inst.free()


func _check_arms(path: String) -> void:
	_expect(ResourceLoader.exists(path), "arms file %s" % path)
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate()
	var prefixes := {"ArmR": "R", "ArmL": "L", "ArmLPistol": "P"}
	for n: String in prefixes:
		var group := inst.find_child(n, true, false) as Node3D
		_expect(group != null, "%s has %s" % [path, n])
		if group == null:
			continue
		# tools/rig_arms.py adds the hand skeleton that the viewmodel drives.
		var prefix: String = prefixes[n]
		var skels := group.find_children("*", "Skeleton3D", true, false)
		_expect(skels.size() == 1, "%s %s has one skeleton" % [path, n])
		if skels.size() == 1:
			var sk := skels[0] as Skeleton3D
			for b in ARM_BONES:
				_expect(sk.find_bone("%s_%s" % [prefix, b]) >= 0, "%s %s has bone %s_%s" % [path, n, prefix, b])
		var skinned := false
		for mi: MeshInstance3D in group.find_children("*", "MeshInstance3D", true, false):
			if mi.skin != null:
				skinned = true
		_expect(skinned, "%s %s has a skinned mesh" % [path, n])
		var rig := Viewmodel.ArmRig.new()
		_expect(rig.setup(group, prefix), "%s %s works with the viewmodel arm rig" % [path, n])
	inst.free()

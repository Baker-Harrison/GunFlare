class_name SkinFollower
extends Node
## Drives a skinned character from plain Node3D joints. Each frame, every
## bone takes the global transform of its joint (or of the joint's ragdoll
## body after death), with the fixed rest offset between joint and bone.

var skeleton: Skeleton3D
var _bones := PackedInt32Array()
var _targets: Array[Node3D] = []
var _offsets: Array[Transform3D] = []


## map: bone name -> joint. The joints must be in their rest pose, and both
## the skeleton and the joints must be descendants of root.
func setup(skel: Skeleton3D, map: Dictionary, root: Node3D) -> void:
	skeleton = skel
	process_priority = 100
	var skel_rel := _relative(skel, root)
	var order: Array = []
	for bone_name: String in map:
		var b := skel.find_bone(bone_name)
		if b < 0 or map[bone_name] == null:
			continue
		order.append([b, map[bone_name]])
	order.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0])
	for e: Array in order:
		var b: int = e[0]
		var joint: Node3D = e[1]
		var bone_rest := skel_rel * skel.get_bone_global_rest(b)
		_bones.append(b)
		_targets.append(joint)
		_offsets.append(_relative(joint, root).affine_inverse() * bone_rest)


## Points each bone at a new node, e.g. the ragdoll body of its joint.
func retarget(replace: Dictionary) -> void:
	for i in _targets.size():
		if replace.has(_targets[i]):
			_targets[i] = replace[_targets[i]]


func _process(_delta: float) -> void:
	update_pose()


func update_pose() -> void:
	if skeleton == null or not skeleton.is_inside_tree():
		return
	var inv := skeleton.global_transform.affine_inverse()
	for i in _bones.size():
		var t := _targets[i]
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			continue
		skeleton.set_bone_global_pose(_bones[i], inv * t.global_transform * _offsets[i])


static func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

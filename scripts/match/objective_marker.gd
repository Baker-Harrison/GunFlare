class_name ObjectiveMarker
extends Node3D
## A capturable flag or zone: pole, cloth, glowing ring and a floating label.

var label := "A"
var radius := 4.5
var _flag: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _flag_mat: StandardMaterial3D
var _label3d: Label3D
var _t := 0.0

const NEUTRAL := Color(0.85, 0.85, 0.85)
const TEAM_COLORS := [Color(0.3, 0.7, 1.0), Color(1.0, 0.3, 0.25)]


func _ready() -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.035
	pm.bottom_radius = 0.045
	pm.height = 4.0
	pole.mesh = pm
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.55, 0.55)
	metal.metallic = 0.8
	metal.roughness = 0.35
	pole.material_override = metal
	pole.position = Vector3(0, 2.0, 0)
	add_child(pole)
	_flag = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.2, 0.75, 0.02)
	_flag.mesh = fm
	_flag_mat = StandardMaterial3D.new()
	_flag_mat.albedo_color = NEUTRAL
	_flag_mat.roughness = 0.9
	_flag.material_override = _flag_mat
	_flag.position = Vector3(0.62, 3.55, 0)
	add_child(_flag)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.08
	tm.outer_radius = radius
	tm.rings = 64
	_ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = NEUTRAL
	_ring_mat.emission_enabled = true
	_ring_mat.emission = NEUTRAL
	_ring_mat.emission_energy_multiplier = 1.5
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 0.06, 0)
	_ring.scale = Vector3(1, 0.2, 1)
	add_child(_ring)
	_label3d = Label3D.new()
	_label3d.text = label
	_label3d.font_size = 160
	_label3d.outline_size = 24
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.no_depth_test = true
	_label3d.fixed_size = true
	_label3d.pixel_size = 0.0004
	_label3d.position = Vector3(0, 5.0, 0)
	add_child(_label3d)


func set_owner_team(team: int) -> void:
	var c: Color = NEUTRAL if team < 0 else TEAM_COLORS[team]
	if _flag_mat:
		_flag_mat.albedo_color = c
		_ring_mat.albedo_color = c
		_ring_mat.emission = c
		_label3d.modulate = c


func set_progress(progress: float, capturing: int) -> void:
	if _ring_mat == null:
		return
	if capturing >= 0 or capturing == -2:
		_t += get_process_delta_time() * 6.0
		_ring_mat.emission_energy_multiplier = 1.5 + sin(_t) * 1.0
	else:
		_ring_mat.emission_energy_multiplier = 1.5
	_flag.position.y = 1.2 + absf(progress) * 2.35


func _process(delta: float) -> void:
	if _flag:
		_flag.rotation.y = sin(Time.get_ticks_msec() / 400.0) * 0.08

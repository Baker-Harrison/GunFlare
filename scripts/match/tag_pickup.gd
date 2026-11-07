class_name TagPickup
extends Node3D
## A spinning, glowing dog-tag pickup.

var victim_team := 0
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.18, 0.28, 0.03)
	_mesh.mesh = b
	var m := StandardMaterial3D.new()
	var c := Color(0.3, 0.7, 1.0) if victim_team == 0 else Color(1.0, 0.35, 0.25)
	m.albedo_color = c
	m.metallic = 0.8
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.5
	_mesh.material_override = m
	add_child(_mesh)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.2
	l.omni_range = 2.5
	add_child(l)


func _process(delta: float) -> void:
	_mesh.rotation.y += delta * 3.0
	_mesh.position.y = sin(Time.get_ticks_msec() / 300.0) * 0.08

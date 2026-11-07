class_name AmmoPickup
extends Node3D
## Scrounger ammo bag. Walk over it (with Scrounger) to refill ammo and equipment.

var _mesh: MeshInstance3D
var _life := 25.0


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 0.15, 0.2)
	_mesh.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.32, 0.2)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.5, 0.2)
	m.emission_energy_multiplier = 0.6
	_mesh.material_override = m
	add_child(_mesh)


func _process(delta: float) -> void:
	_life -= delta
	_mesh.rotation.y += delta * 1.5
	if _life <= 0.0:
		queue_free()
		return
	for s: Soldier in get_tree().get_nodes_in_group("soldiers"):
		if s.alive and s.has_perk("scrounger") and s.global_position.distance_to(global_position) < 1.3:
			for w in s.weapons:
				w.refill(1)
			var lethal: String = s.loadout.get("lethal", "")
			if lethal in ["shard_grenade", "sticky_charge", "hatchet"]:
				s.lethal_count = mini(s.lethal_count + 1, 2)
			if s.is_player:
				Sfx.play_2d("ammo_pickup", -4.0)
				if s.match_ref:
					s.match_ref.hud_popup("SCROUNGED", Color(0.7, 1.0, 0.6))
			queue_free()
			return

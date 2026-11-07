extends MapBase
## Pinecrest — a forest radar outpost on a river. Cabins and a radar
## station on the west bank, a logging camp to the east, two bridges.


func _init() -> void:
	super._init()
	display_name = "Pinecrest"
	size = Vector2(140, 130)


func build() -> void:
	begin("temperate")
	ground("grass", 40.0, false)
	# River running north-south through the middle, with banks.
	box(Vector3(0, -2.2, 0), Vector3(12, 0.4, 170), "ice", 0.0, false)
	# Rock banks, with gaps where the footpaths come down to the water.
	for s in [-1, 1]:
		var gap_z := 30.0 if s < 0 else -32.0
		box(Vector3(s * 6.5, -2.0, (-85.0 + gap_z - 2.5) * 0.5), Vector3(1.0, 2.0, gap_z - 2.5 + 85.0), "rock", 0.0, false)
		box(Vector3(s * 6.5, -2.0, (gap_z + 2.5 + 85.0) * 0.5), Vector3(1.0, 2.0, 85.0 - gap_z - 2.5), "rock", 0.0, false)
	# Ground halves (with a cut for the river).
	box(Vector3(-38.5, -1.0, 0), Vector3(65, 1.0, 170), "grass", 0.0, false)
	box(Vector3(38.5, -1.0, 0), Vector3(65, 1.0, 170), "grass", 0.0, false)
	# Ramps down to the river edge for crossing on foot.
	ramp(Vector3(-10, 0, 30), Vector3(-6.0, -2.0, 30), 3.0, "dirt")
	ramp(Vector3(10, 0, -32), Vector3(6.0, -2.0, -32), 3.0, "dirt")
	# Bridges
	_bridge(Vector3(0, 0, -6), 6.0)
	_bridge(Vector3(0, 0, 40), 4.0)
	# Dirt tracks
	box(Vector3(-30, -0.01, -6), Vector3(50, 0.03, 5), "dirt", 0.0, false)
	box(Vector3(32, -0.01, -6), Vector3(54, 0.03, 5), "dirt", 0.0, false)

	# West bank: radar station + cabins
	building(Rect2(-46, -26, 16, 12), 2, 3.2, "concrete", {
		"doors": [{"side": "s", "at": 0.3}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.5}, {"side": "s", "at": 0.7},
			{"side": "s", "at": 0.3, "floor": 1}, {"side": "s", "at": 0.7, "floor": 1}, {"side": "e", "at": 0.5, "floor": 1}, {"side": "n", "at": 0.5, "floor": 1}],
		"roof_access": true})
	_radar(Vector3(-38, 6.4, -20))
	for r in [Rect2(-30, 10, 9, 7), Rect2(-48, 14, 8, 8), Rect2(-24, 28, 8, 7)]:
		building(r, 1, 3.0, "wood", {"doors": [{"side": "e", "at": 0.5}, {"side": "w", "at": 0.5}],
			"windows": [{"side": "n", "at": 0.5}, {"side": "s", "at": 0.5}], "roof_mat": "roof", "floor_mat": "wood_dark"})
	prop("guard_tower", Vector3(-20, 0, -40))
	prop("guard_tower", Vector3(-58, 0, 40))
	# East bank: logging camp
	_sawmill(Rect2(24, -30, 20, 14))
	for r in [Rect2(36, 8, 9, 7), Rect2(22, 22, 8, 8), Rect2(46, 26, 9, 8)]:
		building(r, 1, 3.0, "wood_dark", {"doors": [{"side": "w", "at": 0.5}, {"side": "e", "at": 0.4}],
			"windows": [{"side": "n", "at": 0.5}, {"side": "s", "at": 0.5}], "roof_mat": "roof", "floor_mat": "wood"})
	for i in 6:
		var p := Vector3(30 + i * 3.0, 0, 0 + (i % 2) * 1.0)
		_cyl_body(p, 0.4, 0.8, "wood_dark") # log piles
	prop("truck", Vector3(40, 0, -6), PI * 0.5)
	prop("tent", Vector3(-12, 0, -24), 0.3)
	prop("tent", Vector3(14, 0, 14), -0.2)
	prop("guard_tower", Vector3(58, 0, -44))
	for p in [Vector3(-14, 0, 4), Vector3(16, 0, -14), Vector3(-34, 0, -2), Vector3(30, 0, 18), Vector3(-10, 0, 46), Vector3(12, 0, 52)]:
		prop(["sandbags", "crate_stack", "barrels"][_rng.randi() % 3], p, _rng.randf_range(0, TAU))

	# Forest: dense pines around the edges, scattered within.
	for i in 140:
		var x := _rng.randf_range(-68, 68)
		var z := _rng.randf_range(-62, 62)
		if absf(x) < 9.0:
			continue
		var edge := absf(x) > 52 or absf(z) > 48
		if not edge and _rng.randf() < 0.65:
			continue
		if _near_structure(Vector2(x, z)):
			continue
		prop("pine" if _rng.randf() < 0.8 else "tree", Vector3(x, 0, z), _rng.randf() * TAU)
	for i in 30:
		var p := Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-55, 55))
		if absf(p.x) > 10.0 and not _near_structure(Vector2(p.x, p.z)):
			prop("bush" if _rng.randf() < 0.6 else "rock", p, _rng.randf() * TAU)

	spawn_row(0, Vector3(-62, 0, -40), Vector3(-62, 0, 30), 8, Vector3.ZERO)
	spawn_row(0, Vector3(-55, 0, -10), Vector3(-55, 0, 10), 3, Vector3.ZERO)
	spawn_row(1, Vector3(62, 0, -30), Vector3(62, 0, 40), 8, Vector3.ZERO)
	spawn_row(1, Vector3(55, 0, -10), Vector3(55, 0, 10), 3, Vector3.ZERO)
	for p in [Vector3(-38, 0, -20), Vector3(-26, 0, 13), Vector3(-44, 0, 18), Vector3(34, 0, -23), Vector3(40, 0, 11), Vector3(26, 0, 26),
			Vector3(-15, 0, -6), Vector3(15, 0, -6), Vector3(-14, 0, 40), Vector3(14, 0, 40), Vector3(0, 0, -50), Vector3(50, 0, 30)]:
		spawn(-1, p)
	flag("A", Vector3(-36, 0, 4))
	flag("B", Vector3(0, 0, -6))
	flag("C", Vector3(36, 0, -12))
	hq_points = [Vector3(-38, 0, -20), Vector3(34, 0, -23), Vector3(-26, 0, 13), Vector3(40, 0, 11), Vector3(0, 0, 40)]
	for p in [Vector3(-38, 0, -20), Vector3(-38, 3.2, -20), Vector3(-26, 0, 13), Vector3(34, 0, -23), Vector3(40, 0, 11),
			Vector3(0, 0, -6), Vector3(0, 0, 40), Vector3(-20, 0, -30), Vector3(20, 0, 30), Vector3(-44, 0, 18)]:
		hotspot(p)


var _structures: Array[Rect2] = [Rect2(-50, -30, 24, 20), Rect2(-34, 6, 18, 30), Rect2(-52, 10, 14, 16), Rect2(20, -34, 28, 22),
	Rect2(18, 4, 40, 34), Rect2(-18, -30, 10, 12), Rect2(8, 8, 14, 14), Rect2(-8, -12, 16, 12), Rect2(-8, 34, 16, 12),
	Rect2(26, -8, 20, 6), Rect2(-24, -46, 8, 10), Rect2(-62, 34, 8, 12), Rect2(52, -50, 10, 12), Rect2(-60, -45, 6, 90), Rect2(54, -45, 6, 90)]


func _near_structure(p: Vector2) -> bool:
	for r in _structures:
		if r.grow(2.0).has_point(p):
			return true
	return false


func _bridge(c: Vector3, width: float) -> void:
	box(c + Vector3(0, -0.35, 0), Vector3(16.0, 0.35, width), "wood", 0.0, false)
	for s in [-1, 1]:
		box(c + Vector3(0, 0, s * (width * 0.5 - 0.1)), Vector3(16.0, 1.0, 0.15), "wood_dark", 0.0, false, true)
		for x in [-5.0, 0.0, 5.0]:
			_cyl_body(c + Vector3(x, -2.2, s * (width * 0.5 - 0.3)), 0.2, 2.0, "wood_dark")


func _radar(p: Vector3) -> void:
	_cyl_body(p, 0.4, 3.0, "metal")
	var dish := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.2
	cm.bottom_radius = 0.5
	cm.height = 1.4
	dish.mesh = cm
	dish.material_override = Materials.get_mat("metal")
	dish.position = p + Vector3(0, 4.2, 0)
	dish.rotation = Vector3(0.6, 0.0, 0.0)
	geometry.add_child(dish)


func _sawmill(r: Rect2) -> void:
	# Open-sided roofed shed on posts with a saw bench.
	for x in [r.position.x, r.get_center().x, r.end.x]:
		for z in [r.position.y, r.end.y]:
			box(Vector3(x, 0, z), Vector3(0.4, 5.0, 0.4), "wood_dark", 0.0, false)
	box(Vector3(r.get_center().x, 5.0, r.get_center().y), Vector3(r.size.x + 1.0, 0.25, r.size.y + 1.0), "roof", 0.0, false)
	wall(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), 0.0, 5.0, 0.3, "wood", [{"at": 6.0, "width": 1.4, "top": 2.3}])
	box(Vector3(r.get_center().x, 0, r.get_center().y), Vector3(8.0, 1.0, 1.5), "metal")
	box(Vector3(r.get_center().x - 5, 0, r.get_center().y + 3), Vector3(3.0, 1.2, 2.0), "wood", 0.0, true, true)
	box(Vector3(r.get_center().x, -0.02, r.get_center().y), Vector3(r.size.x, 0.05, r.size.y), "dirt", 0.0, false)
	minimap_rects.append(r)

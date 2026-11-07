extends MapBase
## Coldharbor — a frozen container port. Container lanes in the middle, two
## warehouses, a dock office with roof access and a crane over the quay.


func _init() -> void:
	super._init()
	display_name = "Coldharbor"
	size = Vector2(130, 110)


func build() -> void:
	begin("snow")
	ground("snow")
	# Quay (concrete) and the frozen sea to the north.
	box(Vector3(0, -0.02, 5), Vector3(130, 0.05, 90), "concrete", 0.0, false)
	box(Vector3(0, -1.6, -50), Vector3(170, 0.4, 30), "ice", 0.0, false)
	box(Vector3(0, -1.5, -40.2), Vector3(130, 1.5, 0.6), "concrete_dark", 0.0, false) # quay edge
	for x in range(-60, 61, 8):
		_cyl_body(Vector3(x, 0, -39.0), 0.25, 0.6, "metal") # bollards
	box(Vector3(0, -0.01, 0), Vector3(120, 0.04, 6), "asphalt", 0.0, false)
	box(Vector3(0, -0.01, 30), Vector3(120, 0.04, 6), "asphalt", 0.0, false)

	# Container yard: stacked lanes with gaps to run through.
	var rows := [-22.0, -14.0, 14.0, 22.0]
	for z in rows:
		var x := -40.0
		while x < 40.0:
			if _rng.randf() < 0.82:
				prop("container", Vector3(x, 0, z), PI * 0.5)
				if _rng.randf() < 0.4:
					prop("container", Vector3(x, 2.6, z), PI * 0.5 + _rng.randf_range(-0.05, 0.05))
			x += 7.0 + _rng.randf_range(0, 2.5)
	# Scattered containers in the centre for cover.
	for p in [Vector3(-8, 0, -4), Vector3(9, 0, 5), Vector3(-20, 0, 6), Vector3(22, 0, -6)]:
		prop("container", p, _rng.randf_range(-0.3, 0.3))
	# Crane over the quay
	prop("crane", Vector3(-18, 0, -34))
	prop("crane", Vector3(26, 0, -34))
	box(Vector3(-18, 0, -34), Vector3(2.0, 0.5, 2.0), "concrete_dark", 0.0, false)

	# West warehouse
	_warehouse(Rect2(-60, -8, 16, 22), 7.0, "sheet_metal")
	# East warehouse
	_warehouse(Rect2(44, -12, 16, 24), 7.0, "container_blue")
	# Dock office (2 floors + roof)
	building(Rect2(-6, 36, 16, 10), 2, 3.2, "brick_grey", {
		"doors": [{"side": "n", "at": 0.3}, {"side": "w", "at": 0.5}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.7}, {"side": "s", "at": 0.3}, {"side": "s", "at": 0.7},
			{"side": "n", "at": 0.3, "floor": 1}, {"side": "n", "at": 0.7, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1},
			{"side": "w", "at": 0.5, "floor": 1}, {"side": "e", "at": 0.5, "floor": 1}],
		"roof_access": true, "floor_mat": "tile"})
	# Customs shed
	building(Rect2(-40, 34, 10, 9), 1, 3.4, "plaster_white", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "s", "at": 0.5}, {"side": "w", "at": 0.5}]})
	building(Rect2(28, 34, 11, 9), 1, 3.4, "brick", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "s", "at": 0.5}, {"side": "e", "at": 0.5}]})
	prop("guard_tower", Vector3(52, 0, 38))
	prop("guard_tower", Vector3(-52, 0, -30))
	# Cover clutter
	for p in [Vector3(-30, 0, -2), Vector3(32, 0, 2), Vector3(0, 0, 20), Vector3(0, 0, -30), Vector3(-15, 0, 28), Vector3(15, 0, -28)]:
		prop(["crate_stack", "barrels", "pallets", "barrier", "sandbags"][_rng.randi() % 5], p, _rng.randf_range(0, TAU))
	prop("truck", Vector3(-28, 0, 30), PI * 0.5)
	prop("truck", Vector3(18, 0, -1.5), PI * 0.5 + 0.1)
	prop("car", Vector3(40, 0, 30), PI * 0.5)
	prop("car_wreck", Vector3(-48, 0, 26), 0.3)
	for p in [Vector3(-36, 0, -30), Vector3(36, 0, 18), Vector3(-10, 0, 10), Vector3(10, 0, -10)]:
		prop("lamp", p, _rng.randf_range(0, TAU))
	for p in [Vector3(-62, 0, 44), Vector3(62, 0, -44), Vector3(-55, 0, 48), Vector3(58, 0, 47)]:
		prop("pine", p)

	spawn_row(0, Vector3(-62, 0, -30), Vector3(-62, 0, 30), 6, Vector3.ZERO)
	spawn_row(0, Vector3(-55, 0, 20), Vector3(-55, 0, 40), 4, Vector3.ZERO)
	spawn_row(1, Vector3(62, 0, -30), Vector3(62, 0, 30), 6, Vector3.ZERO)
	spawn_row(1, Vector3(55, 0, 20), Vector3(55, 0, 40), 4, Vector3.ZERO)
	for p in [Vector3(-52, 0, 3), Vector3(52, 0, 0), Vector3(0, 0, 0), Vector3(-25, 0, 18), Vector3(25, 0, -18), Vector3(0, 0, 41),
			Vector3(-35, 0, 38), Vector3(33, 0, 38), Vector3(-30, 0, -32), Vector3(30, 0, -32), Vector3(0, 0, -36), Vector3(-10, 0, 26)]:
		spawn(-1, p)
	flag("A", Vector3(-52, 0, 3))
	flag("B", Vector3(0, 0, 0))
	flag("C", Vector3(52, 0, 0))
	hq_points = [Vector3(-52, 0, 3), Vector3(2, 0, 41), Vector3(52, 0, 0), Vector3(0, 0, -30), Vector3(-35, 0, 38)]
	for p in [Vector3(0, 0, 41), Vector3(0, 3.2, 41), Vector3(-35, 0, 38), Vector3(33, 0, 38), Vector3(0, 0, -18), Vector3(0, 0, 18),
			Vector3(-30, 0, 0), Vector3(30, 0, 0), Vector3(-18, 0, -32), Vector3(26, 0, -32)]:
		hotspot(p)


func _warehouse(r: Rect2, h: float, mat: String) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	wall(Vector2(x0, z0), Vector2(x1, z0), 0.0, h, 0.3, mat, [{"at": r.size.x * 0.5, "width": 4.0, "top": 4.5}])
	wall(Vector2(x0, z1), Vector2(x1, z1), 0.0, h, 0.3, mat, [{"at": r.size.x * 0.4, "width": 1.4, "top": 2.3}])
	wall(Vector2(x0, z0), Vector2(x0, z1), 0.0, h, 0.3, mat, [{"at": r.size.y * 0.5, "width": 1.4, "top": 2.3}])
	wall(Vector2(x1, z0), Vector2(x1, z1), 0.0, h, 0.3, mat, [{"at": r.size.y * 0.3, "width": 4.0, "top": 4.5}, {"at": r.size.y * 0.75, "width": 2.0, "bottom": 1.4, "top": 2.6}])
	box(Vector3(r.get_center().x, h, r.get_center().y), Vector3(r.size.x + 0.5, 0.3, r.size.y + 0.5), "sheet_metal", 0.0, false)
	box(Vector3(r.get_center().x, -0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y), "concrete", 0.0, false)
	# Mezzanine with stairs
	box(Vector3(x0 + 3.0, 3.0, r.get_center().y), Vector3(5.0, 0.2, r.size.y - 2.0), "metal", 0.0, false)
	stairs(Vector3(x0 + 6.4, 0, z1 - 1.5), Vector2(0, -1), 1.4, 3.0, "metal")
	prop("crate_stack", Vector3(r.get_center().x + 2.0, 0, r.get_center().y - 3.0), 0.4)
	prop("container", Vector3(r.get_center().x + 3.0, 0, r.get_center().y + 4.0))
	prop("pallets", Vector3(x1 - 2.0, 0, z0 + 2.0))
	var l := OmniLight3D.new()
	l.position = Vector3(r.get_center().x, h - 1.0, r.get_center().y)
	l.light_color = Color(0.9, 0.95, 1.0)
	l.light_energy = 1.4
	l.omni_range = 18.0
	geometry.add_child(l)

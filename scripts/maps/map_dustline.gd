extends MapBase
## Dustline — a desert market town. A central bazaar at the crossroads, a
## three-storey hotel overlooking it, alleys, a garage and a warehouse.


func _init() -> void:
	super._init()
	display_name = "Dustline"
	size = Vector2(120, 120)


func build() -> void:
	begin("desert")
	ground("sand")
	# Streets
	box(Vector3(0, -0.02, 0), Vector3(120, 0.04, 9), "asphalt", 0.0, false)
	box(Vector3(0, -0.02, 0), Vector3(9, 0.04, 120), "asphalt", 0.0, false)
	box(Vector3(0, -0.01, 0), Vector3(26, 0.05, 26), "tile", 0.0, false) # market square paving
	# Kerbs
	for s in [-1, 1]:
		deco(Vector3(0, 0, s * 4.6), Vector3(120, 0.15, 0.25), "concrete")
		deco(Vector3(s * 4.6, 0, 0), Vector3(0.25, 0.15, 120), "concrete")

	# --- North-west block ---
	building(Rect2(-42, -42, 16, 14), 2, 3.2, "plaster", {
		"doors": [{"side": "s", "at": 0.3}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "s", "at": 0.75}, {"side": "n", "at": 0.3}, {"side": "n", "at": 0.7}, {"side": "w", "at": 0.5},
			{"side": "s", "at": 0.3, "floor": 1}, {"side": "s", "at": 0.7, "floor": 1}, {"side": "e", "at": 0.5, "floor": 1}, {"side": "w", "at": 0.5, "floor": 1}],
		"roof_access": true})
	building(Rect2(-22, -40, 10, 11), 1, 3.4, "plaster_white", {
		"doors": [{"side": "s", "at": 0.5}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "e", "at": 0.5}, {"side": "n", "at": 0.5}]})
	building(Rect2(-40, -22, 12, 12), 2, 3.2, "plaster_terracotta", {
		"doors": [{"side": "s", "at": 0.6}, {"side": "e", "at": 0.3}],
		"windows": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.5}, {"side": "e", "at": 0.7, "floor": 1}, {"side": "s", "at": 0.3, "floor": 1}, {"side": "n", "at": 0.5, "floor": 1}],
		"stairs": "w"})
	# Courtyard wall
	wall(Vector2(-26, -26), Vector2(-14, -26), 0.0, 1.3, 0.3, "plaster", [{"at": 6.0, "width": 2.0, "bottom": 0.0, "top": 1.3}])

	# --- North-east block: the hotel ---
	building(Rect2(14, -44, 18, 16), 3, 3.3, "plaster_white", {
		"doors": [{"side": "s", "at": 0.5, "width": 2.4}, {"side": "w", "at": 0.6}],
		"windows": [{"side": "s", "at": 0.2}, {"side": "s", "at": 0.8}, {"side": "w", "at": 0.3}, {"side": "n", "at": 0.5},
			{"side": "s", "at": 0.25, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1}, {"side": "s", "at": 0.75, "floor": 1},
			{"side": "w", "at": 0.5, "floor": 1}, {"side": "n", "at": 0.5, "floor": 1},
			{"side": "s", "at": 0.25, "floor": 2}, {"side": "s", "at": 0.5, "floor": 2}, {"side": "s", "at": 0.75, "floor": 2},
			{"side": "w", "at": 0.5, "floor": 2}, {"side": "e", "at": 0.5, "floor": 2}],
		"roof_access": true, "floor_mat": "tile"})
	building(Rect2(36, -38, 9, 14), 1, 3.6, "plaster", {
		"doors": [{"side": "w", "at": 0.5}, {"side": "s", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.5}, {"side": "e", "at": 0.4}]})
	building(Rect2(16, -21, 11, 9), 1, 3.5, "plaster_blue", {
		"doors": [{"side": "s", "at": 0.5, "width": 3.5}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "e", "at": 0.5}, {"side": "n", "at": 0.5}]})
	prop("water_tower", Vector3(38, 0, -16))

	# --- South-west block ---
	building(Rect2(-42, 12, 14, 12), 2, 3.2, "plaster", {
		"doors": [{"side": "n", "at": 0.6}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "w", "at": 0.5}, {"side": "s", "at": 0.5}, {"side": "n", "at": 0.3, "floor": 1}, {"side": "n", "at": 0.7, "floor": 1},
			{"side": "e", "at": 0.5, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1}],
		"roof_access": true})
	building(Rect2(-22, 14, 10, 15), 1, 3.4, "plaster_terracotta", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.7}, {"side": "e", "at": 0.3}],
		"windows": [{"side": "s", "at": 0.5}, {"side": "e", "at": 0.7}]})
	# Open garage
	_garage(Rect2(-46, 30, 12, 11))

	# --- South-east block ---
	building(Rect2(14, 14, 14, 12), 2, 3.2, "plaster_white", {
		"doors": [{"side": "n", "at": 0.4}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "e", "at": 0.5}, {"side": "s", "at": 0.5}, {"side": "n", "at": 0.8},
			{"side": "n", "at": 0.3, "floor": 1}, {"side": "n", "at": 0.7, "floor": 1}, {"side": "w", "at": 0.5, "floor": 1}, {"side": "e", "at": 0.5, "floor": 1}],
		"stairs": "e", "roof_access": true})
	building(Rect2(33, 12, 11, 16), 1, 3.6, "plaster", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.6}],
		"windows": [{"side": "e", "at": 0.5}, {"side": "s", "at": 0.5}]})
	_warehouse(Rect2(14, 32, 22, 13))

	# --- Market square ---
	for p in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 8), Vector3(8, 0, 8), Vector3(-9, 0, 0.0), Vector3(9, 0, 0)]:
		prop("stall", p, _rng.randf_range(-0.2, 0.2) + (PI * 0.5 if absf(p.x) > absf(p.z) else 0.0))
	# Dry fountain
	for i in 8:
		var a := TAU * i / 8.0
		box(Vector3(cos(a) * 2.6, 0, sin(a) * 2.6), Vector3(2.1, 0.7, 0.4), "concrete", -a + PI * 0.5, false)
	box(Vector3(0, 0, 0), Vector3(0.7, 1.6, 0.7), "concrete")
	prop("crate_stack", Vector3(-11, 0, -3))
	prop("crate_stack", Vector3(11, 0, 4), 1.0)
	prop("barrels", Vector3(5, 0, 11))
	prop("pallets", Vector3(-4, 0, -11))

	# --- Street cover ---
	prop("car_wreck", Vector3(-20, 0, 2.2), PI * 0.5 + 0.1)
	prop("car", Vector3(24, 0, -2.0), PI * 0.5 - 0.05)
	prop("car", Vector3(-2.2, 0, -22), 0.05)
	prop("car_wreck", Vector3(2.0, 0, 26), -0.3)
	prop("car", Vector3(-34, 0, -2.5), PI * 0.5)
	prop("car_wreck", Vector3(40, 0, 2.0), PI * 0.5 + 0.4)
	prop("barrier", Vector3(-14, 0, -3.5), 0.0)
	prop("barrier", Vector3(14, 0, 3.5), 0.0)
	prop("barrier", Vector3(3.5, 0, -15), PI * 0.5)
	prop("barrier", Vector3(-3.5, 0, 15), PI * 0.5)
	prop("sandbags", Vector3(-28, 0, 6), 0.0)
	prop("sandbags", Vector3(29, 0, -6), 0.0)
	prop("sandbags", Vector3(6, 0, -32), PI * 0.5)
	prop("sandbags", Vector3(-6, 0, 33), PI * 0.5)
	prop("dumpster", Vector3(-24, 0, -10), 0.2)
	prop("dumpster", Vector3(12, 0, -24), PI * 0.5)
	prop("dumpster", Vector3(30, 0, 9.5), 0.0)
	prop("crate", Vector3(-26, 0, 9))
	prop("crate_small", Vector3(-25, 0, 10.3), 0.4)
	prop("barrels", Vector3(30, 0, -10), 0.6)
	prop("tires", Vector3(-30, 0, 28))
	prop("pallets", Vector3(10, 0, 30), 0.3)
	prop("crate_stack", Vector3(-12, 0, 36), 0.6)
	prop("crate_stack", Vector3(46, 0, 30), 0.2)
	prop("crate_stack", Vector3(-48, 0, -10), 0.9)
	prop("rock", Vector3(-50, 0, 20), 0.3)
	prop("rock", Vector3(50, 0, -28), 1.2)
	prop("rock", Vector3(-6, 0, -50), 2.0)
	prop("rock", Vector3(6, 0, 50), 0.4)
	for p in [Vector3(-12, 0, -14), Vector3(12, 0, 14), Vector3(-30, 0, 46), Vector3(44, 0, -46), Vector3(-46, 0, -48)]:
		prop("tree", p)
	for p in [Vector3(-6.5, 0, -30), Vector3(6.5, 0, 30), Vector3(-30, 0, -6.5), Vector3(30, 0, 6.5)]:
		prop("lamp", p)
	# Low walls along the edges for spawn cover.
	wall(Vector2(-54, -30), Vector2(-54, -8), 0.0, 1.2, 0.4, "plaster")
	wall(Vector2(-54, 8), Vector2(-54, 30), 0.0, 1.2, 0.4, "plaster")
	wall(Vector2(54, -30), Vector2(54, -8), 0.0, 1.2, 0.4, "plaster")
	wall(Vector2(54, 8), Vector2(54, 30), 0.0, 1.2, 0.4, "plaster")

	# --- Spawns / objectives ---
	spawn_row(0, Vector3(-57, 0, -26), Vector3(-57, 0, 26), 8, Vector3(0, 0, 0))
	spawn_row(0, Vector3(-50, 0, -14), Vector3(-50, 0, 14), 4, Vector3(0, 0, 0))
	spawn_row(1, Vector3(57, 0, -26), Vector3(57, 0, 26), 8, Vector3(0, 0, 0))
	spawn_row(1, Vector3(50, 0, -14), Vector3(50, 0, 14), 4, Vector3(0, 0, 0))
	for p in [Vector3(-34, 0, -34), Vector3(-17, 0, -34), Vector3(-34, 0, -16), Vector3(22, 0, -36), Vector3(40, 0, -30),
			Vector3(21, 0, -16), Vector3(-35, 0, 18), Vector3(-17, 0, 22), Vector3(-40, 0, 36), Vector3(21, 0, 20),
			Vector3(38, 0, 20), Vector3(25, 0, 38), Vector3(0, 0, -40), Vector3(0, 0, 40), Vector3(-45, 0, 0), Vector3(45, 0, 0)]:
		spawn(-1, p)
	flag("A", Vector3(-38, 0, 0))
	flag("B", Vector3(0, 0, -10.5))
	flag("C", Vector3(38, 0, 0))
	hq_points = [Vector3(-34, 0, -16), Vector3(23, 0, -36), Vector3(25, 0, 38), Vector3(-35, 0, 18), Vector3(0, 0, 0)]
	for p in [Vector3(-34, 0, -35), Vector3(-34, 3.3, -35), Vector3(-17, 0, -34), Vector3(-34, 0, -16), Vector3(23, 0, -36),
			Vector3(23, 3.3, -36), Vector3(23, 6.6, -36), Vector3(21, 0, -16), Vector3(-35, 0, 18), Vector3(-17, 0, 22),
			Vector3(-40, 0, 36), Vector3(21, 0, 20), Vector3(25, 0, 38), Vector3(0, 0, 0), Vector3(0, 0, 20), Vector3(0, 0, -20),
			Vector3(-25, 0, 0), Vector3(25, 0, 0)]:
		hotspot(p)


func _garage(r: Rect2) -> void:
	# Three walls and a roof; open to the north.
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	wall(Vector2(x0, z0), Vector2(x0, z1), 0.0, 4.0, 0.3, "brick_grey", [{"at": 5.0, "width": 1.4, "bottom": 0.0, "top": 2.3}])
	wall(Vector2(x1, z0), Vector2(x1, z1), 0.0, 4.0, 0.3, "brick_grey", [{"at": 3.0, "width": 1.3, "bottom": 1.1, "top": 2.2}])
	wall(Vector2(x0, z1), Vector2(x1, z1), 0.0, 4.0, 0.3, "brick_grey")
	box(Vector3(r.get_center().x, 4.0, r.get_center().y), Vector3(r.size.x + 0.6, 0.25, r.size.y + 0.3), "sheet_metal", 0.0, false)
	box(Vector3(r.get_center().x, -0.04, r.get_center().y), Vector3(r.size.x, 0.08, r.size.y), "concrete_dark", 0.0, false)
	prop("car_wreck", Vector3(r.get_center().x - 2.0, 0, r.get_center().y + 1.0), 0.2)
	prop("shelf", Vector3(x1 - 0.6, 0, z1 - 3.0), PI * 0.5)
	prop("tires", Vector3(x0 + 1.2, 0, z1 - 1.2))
	prop("barrels", Vector3(x1 - 2.0, 0, z1 - 1.0))


func _warehouse(r: Rect2) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var h := 6.0
	wall(Vector2(x0, z0), Vector2(x1, z0), 0.0, h, 0.3, "sheet_metal", [{"at": 5.0, "width": 4.0, "bottom": 0.0, "top": 4.0}, {"at": 16.0, "width": 1.4, "bottom": 0.0, "top": 2.3}])
	wall(Vector2(x0, z1), Vector2(x1, z1), 0.0, h, 0.3, "sheet_metal", [{"at": 11.0, "width": 4.0, "bottom": 0.0, "top": 4.0}])
	wall(Vector2(x0, z0), Vector2(x0, z1), 0.0, h, 0.3, "sheet_metal", [{"at": 6.5, "width": 1.4, "bottom": 0.0, "top": 2.3}])
	wall(Vector2(x1, z0), Vector2(x1, z1), 0.0, h, 0.3, "sheet_metal", [{"at": 6.5, "width": 2.0, "bottom": 1.5, "top": 2.8}])
	box(Vector3(r.get_center().x, h, r.get_center().y), Vector3(r.size.x + 0.5, 0.3, r.size.y + 0.5), "sheet_metal", 0.0, false)
	box(Vector3(r.get_center().x, -0.04, r.get_center().y), Vector3(r.size.x, 0.08, r.size.y), "concrete", 0.0, false)
	# Catwalk along the north wall, reached by stairs.
	box(Vector3(r.get_center().x + 2.0, 2.9, z0 + 1.0), Vector3(r.size.x - 6.0, 0.15, 1.8), "metal", 0.0, false)
	stairs(Vector3(x0 + 3.2, 0, z0 + 6.8), Vector2(0, -1), 1.4, 3.0, "metal")
	prop("container", Vector3(x0 + 6.0, 0, z1 - 4.0), PI * 0.5)
	prop("crate_stack", Vector3(x1 - 4.0, 0, z1 - 3.0))
	prop("crate_stack", Vector3(r.get_center().x, 0, r.get_center().y + 1.0), 0.7)
	prop("pallets", Vector3(x1 - 3.0, 0, z0 + 4.0))
	var l := OmniLight3D.new()
	l.position = Vector3(r.get_center().x, h - 1.0, r.get_center().y)
	l.light_color = Color(1.0, 0.9, 0.75)
	l.light_energy = 1.5
	l.omni_range = 16.0
	geometry.add_child(l)

extends MapBase
## Villa Marisol — a hillside Mediterranean estate at sunset: the main villa
## around a courtyard, a pool terrace, guest house, garage and gardens.


func _init() -> void:
	super._init()
	display_name = "Villa Marisol"
	size = Vector2(110, 110)


func build() -> void:
	begin("dusk")
	ground("grass")
	box(Vector3(0, -0.02, 0), Vector3(40, 0.05, 34), "tile", 0.0, false) # courtyard paving
	box(Vector3(0, -0.02, 34), Vector3(8, 0.04, 40), "dirt", 0.0, false) # drive

	# Main villa: U-shape of three 2-storey wings around the courtyard.
	var wings := [Rect2(-22, -26, 44, 10), Rect2(-22, -16, 10, 26), Rect2(12, -16, 10, 26)]
	building(wings[0], 2, 3.4, "plaster_white", {
		"doors": [{"side": "s", "at": 0.5, "width": 2.4}, {"side": "s", "at": 0.15}, {"side": "s", "at": 0.85}, {"side": "n", "at": 0.5}],
		"windows": [{"side": "s", "at": 0.3}, {"side": "s", "at": 0.7}, {"side": "n", "at": 0.2}, {"side": "n", "at": 0.8},
			{"side": "s", "at": 0.15, "floor": 1}, {"side": "s", "at": 0.35, "floor": 1}, {"side": "s", "at": 0.65, "floor": 1}, {"side": "s", "at": 0.85, "floor": 1},
			{"side": "n", "at": 0.3, "floor": 1}, {"side": "n", "at": 0.7, "floor": 1}, {"side": "w", "at": 0.5, "floor": 1}, {"side": "e", "at": 0.5, "floor": 1}],
		"roof_access": true, "floor_mat": "tile", "roof_mat": "plaster_terracotta"})
	building(wings[1], 2, 3.4, "plaster_white", {
		"doors": [{"side": "e", "at": 0.5}, {"side": "w", "at": 0.3}, {"side": "s", "at": 0.5}, {"side": "n", "at": 0.66}],
		"windows": [{"side": "e", "at": 0.2}, {"side": "e", "at": 0.8}, {"side": "w", "at": 0.7},
			{"side": "e", "at": 0.3, "floor": 1}, {"side": "e", "at": 0.7, "floor": 1}, {"side": "w", "at": 0.5, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1}],
		"floor_mat": "tile", "roof_mat": "roof", "stairs": "w"})
	building(wings[2], 2, 3.4, "plaster_white", {
		"doors": [{"side": "w", "at": 0.5}, {"side": "e", "at": 0.6}, {"side": "s", "at": 0.5}, {"side": "n", "at": 0.34}],
		"windows": [{"side": "w", "at": 0.2}, {"side": "w", "at": 0.8}, {"side": "e", "at": 0.3},
			{"side": "w", "at": 0.3, "floor": 1}, {"side": "w", "at": 0.7, "floor": 1}, {"side": "e", "at": 0.5, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1}],
		"floor_mat": "tile", "roof_mat": "roof"})
	# Courtyard fountain and planters
	for i in 8:
		var a := TAU * i / 8.0
		box(Vector3(cos(a) * 2.2, 0, sin(a) * 2.2 - 4.0), Vector3(1.8, 0.6, 0.35), "plaster_white", -a + PI * 0.5, false)
	box(Vector3(0, 0, -4), Vector3(0.6, 1.8, 0.6), "plaster_white")
	for p in [Vector3(-7, 0, 6), Vector3(7, 0, 6), Vector3(-7, 0, -12), Vector3(7, 0, -12)]:
		box(p, Vector3(2.0, 0.6, 2.0), "brick", 0.0, false)
		prop("bush", p + Vector3(0, 0.6, 0))

	# Pool terrace to the north (sunken pool behind the main wing).
	box(Vector3(0, -0.02, -38), Vector3(40, 0.05, 16), "tile", 0.0, false)
	# Raised infinity pool with a tiled rim.
	box(Vector3(0, 0, -38), Vector3(16, 0.35, 6), "ice", 0.0, false)
	for side in [-1, 1]:
		box(Vector3(side * 8.1, 0, -38), Vector3(0.3, 0.6, 6.4), "tile", 0.0, false)
		box(Vector3(0, 0, -38 + side * 3.15), Vector3(16.5, 0.6, 0.3), "tile", 0.0, false)
	for p in [Vector3(-14, 0, -36), Vector3(14, 0, -40), Vector3(-12, 0, -42), Vector3(12, 0, -34)]:
		prop("table", p, _rng.randf_range(0, TAU))
	building(Rect2(-40, -46, 12, 10), 1, 3.2, "plaster", {"doors": [{"side": "e", "at": 0.5}, {"side": "s", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.5}], "roof_mat": "plaster_terracotta"}) # pool house

	# Guest house (east), garage (west), gardener's shed.
	building(Rect2(30, -10, 14, 12), 2, 3.2, "plaster_terracotta", {
		"doors": [{"side": "w", "at": 0.5}, {"side": "s", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.5}, {"side": "e", "at": 0.5}, {"side": "w", "at": 0.5, "floor": 1}, {"side": "n", "at": 0.5, "floor": 1},
			{"side": "s", "at": 0.5, "floor": 1}],
		"roof_access": true})
	building(Rect2(-44, -6, 14, 10), 1, 3.6, "plaster_white", {
		"doors": [{"side": "e", "at": 0.5, "width": 3.4}, {"side": "s", "at": 0.5}],
		"windows": [{"side": "w", "at": 0.5}, {"side": "n", "at": 0.5}]})
	prop("car", Vector3(-37, 0, -1), PI * 0.5)
	prop("car", Vector3(-26, 0, 22), 0.1)
	building(Rect2(24, 26, 8, 8), 1, 3.0, "wood", {"doors": [{"side": "w", "at": 0.5}], "windows": [{"side": "s", "at": 0.5}]})

	# Garden walls with gates and hedges
	wall(Vector2(-50, 14), Vector2(-4.5, 14), 0.0, 1.6, 0.4, "plaster_white", [{"at": 20.0, "width": 2.0, "top": 1.6}])
	wall(Vector2(4.5, 14), Vector2(50, 14), 0.0, 1.6, 0.4, "plaster_white", [{"at": 22.0, "width": 2.0, "top": 1.6}])
	for i in 18:
		var x := -48.0 + i * 5.6
		if absf(x) < 6.0:
			continue
		prop("bush", Vector3(x, 0, 18 + _rng.randf_range(-1, 1)))
	for p in [Vector3(-30, 0, 32), Vector3(30, 0, 40), Vector3(-18, 0, 44), Vector3(18, 0, 22), Vector3(-46, 0, 40), Vector3(44, 0, 10),
			Vector3(-26, 0, -36), Vector3(28, 0, -40), Vector3(44, 0, -30), Vector3(-48, 0, -26)]:
		prop("tree", p, _rng.randf() * TAU)
	for p in [Vector3(-10, 0, 26), Vector3(10, 0, 32), Vector3(36, 0, 12), Vector3(-36, 0, 12), Vector3(0, 0, -50)]:
		prop(["crate_stack", "barrels", "sandbags", "rock"][_rng.randi() % 4], p, _rng.randf_range(0, TAU))
	for p in [Vector3(-4.5, 0, 20), Vector3(4.5, 0, 20), Vector3(-4.5, 0, 40), Vector3(4.5, 0, 40)]:
		prop("lamp", p, 0.0 if p.x < 0 else PI)

	spawn_row(0, Vector3(-52, 0, 20), Vector3(-10, 0, 50), 7, Vector3.ZERO)
	spawn_row(0, Vector3(-52, 0, -40), Vector3(-52, 0, 10), 5, Vector3.ZERO)
	spawn_row(1, Vector3(52, 0, 20), Vector3(10, 0, 50), 7, Vector3.ZERO)
	spawn_row(1, Vector3(52, 0, -40), Vector3(52, 0, 10), 5, Vector3.ZERO)
	for p in [Vector3(0, 0, -21), Vector3(-17, 0, -3), Vector3(17, 0, -3), Vector3(37, 0, -4), Vector3(-37, 0, -1), Vector3(-34, 0, -41),
			Vector3(0, 0, -44), Vector3(0, 0, 4), Vector3(-20, 0, 30), Vector3(20, 0, 30), Vector3(28, 0, 30), Vector3(0, 0, 46)]:
		spawn(-1, p)
	flag("A", Vector3(-30, 0, 24))
	flag("B", Vector3(0, 0, -4))
	flag("C", Vector3(30, 0, 24))
	hq_points = [Vector3(0, 0, -21), Vector3(37, 0, -4), Vector3(-37, 0, -1), Vector3(0, 0, -40), Vector3(0, 0, 4)]
	for p in [Vector3(0, 0, -21), Vector3(0, 3.4, -21), Vector3(-17, 0, -3), Vector3(17, 3.4, -3), Vector3(37, 0, -4), Vector3(-37, 0, -1),
			Vector3(0, 0, -40), Vector3(0, 0, 4), Vector3(-25, 0, 30), Vector3(25, 0, 30)]:
		hotspot(p)

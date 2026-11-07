extends MapBase
## Hangar 9 — a desert airfield. Two hangars (one holding a transport
## plane), a four-storey control tower and the apron in between.


func _init() -> void:
	super._init()
	display_name = "Hangar 9"
	size = Vector2(140, 120)


func build() -> void:
	begin("dusk")
	ground("sand")
	box(Vector3(0, -0.02, -40), Vector3(150, 0.04, 22), "asphalt", 0.0, false) # runway
	for x in range(-60, 61, 12):
		deco(Vector3(x, 0.0, -40), Vector3(6.0, 0.03, 0.6), "plaster_white")
	box(Vector3(0, -0.02, 0), Vector3(110, 0.04, 40), "concrete", 0.0, false) # apron
	box(Vector3(0, -0.02, 34), Vector3(12, 0.04, 40), "asphalt", 0.0, false)

	_hangar(Rect2(-56, -10, 30, 26), true)
	_hangar(Rect2(26, -10, 30, 26), false)
	# Control tower: 3 floors + observation deck (roof access).
	building(Rect2(-8, 22, 12, 12), 3, 3.3, "concrete", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.25, "floor": 1}, {"side": "n", "at": 0.75, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1},
			{"side": "n", "at": 0.5, "floor": 2, "width": 6.0, "bottom": 0.9, "top": 2.6}, {"side": "e", "at": 0.5, "floor": 2, "width": 6.0, "bottom": 0.9, "top": 2.6},
			{"side": "w", "at": 0.5, "floor": 2, "width": 6.0, "bottom": 0.9, "top": 2.6}, {"side": "s", "at": 0.5, "floor": 2, "width": 6.0, "bottom": 0.9, "top": 2.6},
			{"side": "e", "at": 0.5}],
		"roof_access": true, "floor_mat": "tile"})
	box(Vector3(-2, 9.9, 28), Vector3(1.0, 4.0, 1.0), "metal") # mast
	# Barracks and fuel depot
	building(Rect2(18, 26, 20, 9), 1, 3.3, "plaster", {
		"doors": [{"side": "n", "at": 0.2}, {"side": "n", "at": 0.8}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.5}, {"side": "s", "at": 0.25}, {"side": "s", "at": 0.75}, {"side": "e", "at": 0.5}]})
	building(Rect2(-40, 28, 14, 10), 1, 3.6, "sheet_metal", {
		"doors": [{"side": "n", "at": 0.5, "width": 3.0}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "w", "at": 0.5}, {"side": "s", "at": 0.5}]})
	for p in [Vector3(48, 0, 30), Vector3(56, 0, 22)]:
		prop("tank_small", p)
	prop("truck", Vector3(-10, 0, 4), 0.4)
	prop("truck", Vector3(12, 0, -4), -0.3)
	prop("plane", Vector3(4, 0, -40), PI * 0.5 + 0.08)
	for p in [Vector3(-20, 0, 10), Vector3(20, 0, 12), Vector3(0, 0, -14), Vector3(-18, 0, -18), Vector3(22, 0, -18), Vector3(0, 0, 16),
			Vector3(-30, 0, -28), Vector3(34, 0, -28)]:
		prop(["crate_stack", "barrels", "pallets", "barrier", "sandbags", "container"][_rng.randi() % 6], p, _rng.randf_range(0, TAU))
	prop("guard_tower", Vector3(-62, 0, 44))
	prop("guard_tower", Vector3(62, 0, 44))
	for p in [Vector3(-14, 0, 18), Vector3(14, 0, 18), Vector3(-30, 0, 20), Vector3(30, 0, 20)]:
		prop("lamp", p, _rng.randf() * TAU)
	for p in [Vector3(-64, 0, 54), Vector3(64, 0, 54), Vector3(-50, 0, 54)]:
		prop("rock", p, _rng.randf() * TAU)
	wall(Vector2(-68, 52), Vector2(68, 52), 0.0, 2.2, 0.2, "sheet_metal")

	spawn_row(0, Vector3(-66, 0, -30), Vector3(-66, 0, 40), 8, Vector3.ZERO)
	spawn_row(0, Vector3(-60, 0, 22), Vector3(-50, 0, 44), 4, Vector3.ZERO)
	spawn_row(1, Vector3(66, 0, -30), Vector3(66, 0, 40), 8, Vector3.ZERO)
	spawn_row(1, Vector3(60, 0, 22), Vector3(50, 0, 44), 4, Vector3.ZERO)
	for p in [Vector3(-41, 0, 3), Vector3(41, 0, 3), Vector3(-2, 0, 28), Vector3(28, 0, 30), Vector3(-33, 0, 33), Vector3(0, 0, 0),
			Vector3(-30, 0, -40), Vector3(30, 0, -40), Vector3(0, 0, -30), Vector3(50, 0, 10), Vector3(-50, 0, 30), Vector3(12, 0, 12)]:
		spawn(-1, p)
	flag("A", Vector3(-41, 0, 3))
	flag("B", Vector3(0, 0, 4))
	flag("C", Vector3(41, 0, 3))
	hq_points = [Vector3(-2, 0, 28), Vector3(28, 0, 30), Vector3(-33, 0, 33), Vector3(-41, 0, 3), Vector3(41, 0, 3)]
	for p in [Vector3(-41, 0, 3), Vector3(41, 0, 3), Vector3(-2, 0, 28), Vector3(-2, 6.6, 28), Vector3(28, 0, 30), Vector3(-33, 0, 33),
			Vector3(0, 0, -30), Vector3(0, 0, 4), Vector3(-20, 0, -20), Vector3(20, 0, -20)]:
		hotspot(p)


func _hangar(r: Rect2, with_plane: bool) -> void:
	var h := 10.0
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	# Huge door facing the runway (north), personnel doors elsewhere.
	wall(Vector2(x0, z0), Vector2(x1, z0), 0.0, h, 0.35, "sheet_metal", [{"at": r.size.x * 0.5, "width": 18.0, "top": 7.5}])
	wall(Vector2(x0, z1), Vector2(x1, z1), 0.0, h, 0.35, "sheet_metal", [{"at": 5.0, "width": 1.4, "top": 2.3}, {"at": r.size.x - 5.0, "width": 1.4, "top": 2.3}])
	wall(Vector2(x0, z0), Vector2(x0, z1), 0.0, h, 0.35, "sheet_metal", [{"at": r.size.y * 0.6, "width": 1.4, "top": 2.3}])
	wall(Vector2(x1, z0), Vector2(x1, z1), 0.0, h, 0.35, "sheet_metal", [{"at": r.size.y * 0.6, "width": 1.4, "top": 2.3}])
	box(Vector3(r.get_center().x, h, r.get_center().y), Vector3(r.size.x + 0.6, 0.4, r.size.y + 0.6), "sheet_metal", 0.0, false)
	box(Vector3(r.get_center().x, -0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y), "concrete_dark", 0.0, false)
	# Gantry walkway along the back wall
	box(Vector3(r.get_center().x, 4.0, z1 - 1.2), Vector3(r.size.x - 2.0, 0.2, 2.0), "metal", 0.0, false)
	box(Vector3(r.get_center().x, 4.2, z1 - 2.25), Vector3(r.size.x - 6.0, 1.0, 0.08), "sheet_metal", 0.0, false, true)
	stairs(Vector3(x0 + 2.0, 0, z1 - 7.0), Vector2(0, 1), 1.4, 4.0, "metal")
	if with_plane:
		prop("plane", Vector3(r.get_center().x, 0, r.get_center().y - 1.0), PI * 0.5)
	else:
		for p in [Vector3(-6, 0, -4), Vector3(6, 0, 2), Vector3(0, 0, 6), Vector3(-8, 0, 7)]:
			prop(["container", "crate_stack", "truck"][_rng.randi() % 3], Vector3(r.get_center().x, 0, r.get_center().y) + p, _rng.randf_range(-0.4, 0.4))
	for i in 3:
		var l := OmniLight3D.new()
		l.position = Vector3(x0 + r.size.x * (i + 0.5) / 3.0, h - 1.0, r.get_center().y)
		l.light_color = Color(1.0, 0.92, 0.8)
		l.light_energy = 1.6
		l.omni_range = 16.0
		l.shadow_enabled = i == 1 and Settings.get_value("quality") >= 2
		geometry.add_child(l)

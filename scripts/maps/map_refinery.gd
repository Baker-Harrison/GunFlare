extends MapBase
## Refinery — night-time industrial complex lit by floodlights. Storage
## tanks, pipe racks, a control building and an elevated catwalk loop.


func _init() -> void:
	super._init()
	display_name = "Refinery"
	size = Vector2(130, 120)


func build() -> void:
	begin("night")
	ground("dirt")
	box(Vector3(0, -0.02, 0), Vector3(130, 0.04, 8), "asphalt", 0.0, false)
	box(Vector3(-20, -0.02, 0), Vector3(8, 0.04, 120), "asphalt", 0.0, false)
	box(Vector3(25, -0.02, 0), Vector3(8, 0.04, 120), "asphalt", 0.0, false)
	box(Vector3(0, -0.01, -30), Vector3(60, 0.05, 30), "concrete", 0.0, false)

	# Tank farm (north-west) with bund walls.
	for p in [Vector3(-48, 0, -40), Vector3(-34, 0, -44), Vector3(-48, 0, -24)]:
		prop("tank_large", p)
		_flood(p + Vector3(6, 0, 6))
	wall(Vector2(-58, -52), Vector2(-26, -52), 0.0, 1.3, 0.5, "concrete")
	wall(Vector2(-26, -52), Vector2(-26, -14), 0.0, 1.3, 0.5, "concrete", [{"at": 20.0, "width": 3.0, "top": 1.3}])
	wall(Vector2(-58, -14), Vector2(-30, -14), 0.0, 1.3, 0.5, "concrete")
	# Pipe racks running east-west.
	prop("pipe_rack", Vector3(0, 0, -16), PI * 0.5)
	prop("pipe_rack", Vector3(-4, 0, 18), PI * 0.5)
	prop("pipe_rack", Vector3(40, 0, 20), 0.0)
	# Control building (2 floors, roof access)
	building(Rect2(-4, -44, 20, 12), 2, 3.3, "concrete", {
		"doors": [{"side": "s", "at": 0.25}, {"side": "s", "at": 0.75}, {"side": "e", "at": 0.5}, {"side": "w", "at": 0.5}],
		"windows": [{"side": "s", "at": 0.5, "width": 3.0}, {"side": "n", "at": 0.3}, {"side": "n", "at": 0.7},
			{"side": "s", "at": 0.25, "floor": 1}, {"side": "s", "at": 0.5, "floor": 1, "width": 3.0}, {"side": "s", "at": 0.75, "floor": 1},
			{"side": "e", "at": 0.5, "floor": 1}, {"side": "w", "at": 0.5, "floor": 1}],
		"roof_access": true, "floor_mat": "tile"})
	# Cracking tower: a tall platform with stairs.
	_tower(Vector3(32, 0, -30))
	# Workshop (south-east)
	_shed(Rect2(30, 30, 20, 14))
	# Loading area south-west
	for p in [Vector3(-44, 0, 22), Vector3(-36, 0, 28), Vector3(-48, 0, 36)]:
		prop("container", p, _rng.randf_range(-0.4, 0.4))
	prop("truck", Vector3(-28, 0, 40), 0.1)
	prop("truck", Vector3(8, 0, 32), PI * 0.5)
	building(Rect2(-12, 36, 12, 10), 1, 3.4, "brick_grey", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "w", "at": 0.6}],
		"windows": [{"side": "e", "at": 0.5}, {"side": "s", "at": 0.5}]})
	# Small tanks and clutter
	for p in [Vector3(12, 0, -8), Vector3(16, 0, 8), Vector3(-10, 0, 8), Vector3(44, 0, -4)]:
		prop("tank_small", p)
	for p in [Vector3(-14, 0, -6), Vector3(6, 0, 6), Vector3(20, 0, -14), Vector3(-30, 0, 10), Vector3(50, 0, 10), Vector3(-50, 0, 6)]:
		prop(["barrels", "crate_stack", "pallets", "barrier", "sandbags"][_rng.randi() % 5], p, _rng.randf_range(0, TAU))
	for p in [Vector3(-8, 0, -10), Vector3(36, 0, 6), Vector3(-36, 0, 6), Vector3(10, 0, 42), Vector3(-40, 0, 44), Vector3(50, 0, -40)]:
		_flood(p)
	prop("guard_tower", Vector3(56, 0, 50))
	prop("guard_tower", Vector3(-56, 0, 50))

	spawn_row(0, Vector3(-62, 0, -6), Vector3(-62, 0, 50), 8, Vector3.ZERO)
	spawn_row(0, Vector3(-55, 0, 0), Vector3(-55, 0, 12), 3, Vector3.ZERO)
	spawn_row(1, Vector3(62, 0, -50), Vector3(62, 0, 40), 8, Vector3.ZERO)
	spawn_row(1, Vector3(55, 0, -12), Vector3(55, 0, 0), 3, Vector3.ZERO)
	for p in [Vector3(-40, 0, -32), Vector3(6, 0, -38), Vector3(32, 0, -40), Vector3(40, 0, 36), Vector3(-6, 0, 41), Vector3(-40, 0, 32),
			Vector3(0, 0, 0), Vector3(-20, 0, -20), Vector3(25, 0, 20), Vector3(50, 0, 0), Vector3(-50, 0, 0), Vector3(10, 0, 20)]:
		spawn(-1, p)
	flag("A", Vector3(-42, 0, 4))
	flag("B", Vector3(4, 0, -26))
	flag("C", Vector3(44, 0, 6))
	hq_points = [Vector3(6, 0, -38), Vector3(40, 0, 36), Vector3(-6, 0, 41), Vector3(-40, 0, -32), Vector3(32, 0, -30)]
	for p in [Vector3(6, 0, -38), Vector3(6, 3.3, -38), Vector3(32, 0, -30), Vector3(32, 6.0, -30), Vector3(40, 0, 37),
			Vector3(-6, 0, 41), Vector3(-40, 0, -30), Vector3(0, 0, 0), Vector3(-20, 0, 20), Vector3(25, 0, -10)]:
		hotspot(p)


func _flood(p: Vector3) -> void:
	_cyl_body(p, 0.12, 7.0, "metal")
	deco(p + Vector3(0, 7.0, 0), Vector3(1.2, 0.4, 0.6), "metal")
	var l := SpotLight3D.new()
	l.position = p + Vector3(0, 7.0, 0)
	l.rotation = Vector3(-PI * 0.42, _rng.randf() * TAU, 0)
	l.light_color = Color(1.0, 0.85, 0.6)
	l.light_energy = 6.0
	l.spot_range = 35.0
	l.spot_angle = 55.0
	l.shadow_enabled = Settings.get_value("quality") >= 2
	geometry.add_child(l)
	var o := OmniLight3D.new()
	o.position = p + Vector3(0, 6.0, 0)
	o.light_color = Color(1.0, 0.8, 0.55)
	o.light_energy = 0.8
	o.omni_range = 14.0
	geometry.add_child(o)


func _tower(p: Vector3) -> void:
	for c in [Vector3(-4, 0, -4), Vector3(4, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4)]:
		box(p + c, Vector3(0.5, 12.0, 0.5), "metal_rust")
	# Level 1 (3 m): full deck, entered from the east stairs.
	box(p + Vector3(0, 3.0, 0), Vector3(9.0, 0.2, 9.0), "metal", 0.0, false)
	_rail(p + Vector3(0, 3.0, 4.4), Vector3(9.0, 1.0, 0.08))
	_rail(p + Vector3(0, 3.0, -4.4), Vector3(9.0, 1.0, 0.08))
	_rail(p + Vector3(-4.4, 3.0, 0), Vector3(0.08, 1.0, 9.0))
	_rail(p + Vector3(4.4, 3.0, 2.45), Vector3(0.08, 1.0, 3.9))
	stairs(p + Vector3(6.0, 0, 4.0), Vector2(0, -1), 1.2, 3.0, "metal")
	box(p + Vector3(5.2, 2.8, -1.4), Vector3(2.2, 0.2, 2.0), "metal", 0.0, false)
	# Level 2 (6 m): east half, reached by stairs climbing east across level 1.
	box(p + Vector3(2.25, 6.0, 0), Vector3(4.5, 0.2, 9.0), "metal", 0.0, false)
	_rail(p + Vector3(2.25, 6.0, 4.4), Vector3(4.5, 1.0, 0.08))
	_rail(p + Vector3(2.25, 6.0, -4.4), Vector3(4.5, 1.0, 0.08))
	_rail(p + Vector3(4.4, 6.0, 0), Vector3(0.08, 1.0, 9.0))
	stairs(p + Vector3(-4.2, 3.0, 2.6), Vector2(1, 0), 1.2, 3.0, "metal")
	_cyl_body(p + Vector3(-2.0, 3.0, -2.0), 1.2, 13.0, "metal")
	var l := OmniLight3D.new()
	l.position = p + Vector3(-2.0, 16.5, -2.0)
	l.light_color = Color(1.0, 0.2, 0.1)
	l.light_energy = 2.0
	l.omni_range = 8.0
	geometry.add_child(l)


func _rail(c: Vector3, sz: Vector3) -> void:
	box(c, sz, "sheet_metal", 0.0, false, true)


func _shed(r: Rect2) -> void:
	var h := 5.5
	wall(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), 0.0, h, 0.3, "sheet_metal", [{"at": 6.0, "width": 4.0, "top": 4.0}, {"at": 15.0, "width": 1.4, "top": 2.3}])
	wall(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), 0.0, h, 0.3, "sheet_metal", [{"at": 10.0, "width": 1.4, "top": 2.3}])
	wall(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), 0.0, h, 0.3, "sheet_metal", [{"at": 7.0, "width": 1.4, "top": 2.3}])
	wall(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), 0.0, h, 0.3, "sheet_metal", [{"at": 7.0, "width": 2.0, "bottom": 1.3, "top": 2.5}])
	box(Vector3(r.get_center().x, h, r.get_center().y), Vector3(r.size.x + 0.4, 0.25, r.size.y + 0.4), "sheet_metal", 0.0, false)
	box(Vector3(r.get_center().x, -0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y), "concrete", 0.0, false)
	prop("crate_stack", Vector3(r.get_center().x - 3, 0, r.get_center().y + 2), 0.3)
	prop("truck", Vector3(r.get_center().x + 3, 0, r.get_center().y), PI * 0.5)
	var l := OmniLight3D.new()
	l.position = Vector3(r.get_center().x, h - 0.8, r.get_center().y)
	l.light_color = Color(0.95, 0.95, 1.0)
	l.light_energy = 1.5
	l.omni_range = 16.0
	geometry.add_child(l)

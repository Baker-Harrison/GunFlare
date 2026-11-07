extends MapBase
## Ashgrove — a shelled European town under grey skies. Brick terraces,
## narrow streets, rubble barricades, a town hall with a clock tower and a
## square with a monument.


func _init() -> void:
	super._init()
	display_name = "Ashgrove"
	size = Vector2(110, 115)


func build() -> void:
	begin("overcast")
	ground("dirt")
	# Cobbled streets
	box(Vector3(0, -0.02, 0), Vector3(110, 0.04, 8), "brick_grey", 0.0, false)
	box(Vector3(-18, -0.02, 0), Vector3(7, 0.04, 115), "brick_grey", 0.0, false)
	box(Vector3(20, -0.02, 0), Vector3(7, 0.04, 115), "brick_grey", 0.0, false)
	box(Vector3(0, -0.01, -22), Vector3(26, 0.05, 20), "tile", 0.0, false) # town square

	# Town hall (north of the square) with a clock tower.
	building(Rect2(-12, -48, 24, 14), 2, 3.8, "brick", {
		"doors": [{"side": "s", "at": 0.5, "width": 2.6}, {"side": "w", "at": 0.5}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "s", "at": 0.2}, {"side": "s", "at": 0.8}, {"side": "n", "at": 0.3}, {"side": "n", "at": 0.7},
			{"side": "s", "at": 0.15, "floor": 1}, {"side": "s", "at": 0.38, "floor": 1}, {"side": "s", "at": 0.62, "floor": 1}, {"side": "s", "at": 0.85, "floor": 1},
			{"side": "e", "at": 0.5, "floor": 1}, {"side": "w", "at": 0.5, "floor": 1}, {"side": "n", "at": 0.5, "floor": 1}],
		"roof_access": true, "floor_mat": "wood_dark"})
	box(Vector3(0, 7.6, -44), Vector3(5, 9.0, 5), "brick")
	box(Vector3(0, 16.6, -44), Vector3(5.6, 0.4, 5.6), "concrete_dark")
	box(Vector3(0, 17.0, -44), Vector3(3.5, 2.5, 3.5), "roof")
	deco(Vector3(0, 13.0, -41.45), Vector3(2.2, 2.2, 0.1), "plaster_white") # clock face
	# Monument in the square
	box(Vector3(0, 0, -22), Vector3(3.5, 1.2, 3.5), "concrete")
	box(Vector3(0, 1.2, -22), Vector3(1.2, 3.5, 1.2), "concrete_dark")

	# Terraces along the streets, some shelled open.
	var terraces := [
		[Rect2(-52, -46, 26, 10), 3, "brick", false], [Rect2(26, -46, 24, 10), 3, "brick_grey", true],
		[Rect2(-52, -26, 12, 18), 2, "plaster", true], [Rect2(26, -28, 12, 20), 2, "brick", false],
		[Rect2(-52, 8, 12, 16), 2, "brick_grey", false], [Rect2(-38, 8, 14, 12), 2, "plaster", false],
		[Rect2(26, 8, 12, 14), 2, "plaster_white", true], [Rect2(40, 8, 12, 16), 3, "brick", false],
		[Rect2(-12, 8, 24, 12), 2, "brick", true], [Rect2(-52, 32, 22, 12), 2, "brick", false],
		[Rect2(-12, 30, 22, 14), 1, "plaster", false], [Rect2(26, 32, 24, 12), 2, "brick_grey", false],
	]
	for t in terraces:
		var r: Rect2 = t[0]
		var floors: int = t[1]
		var mat: String = t[2]
		var damaged: bool = t[3]
		var wins: Array = []
		for side in ["n", "s", "e", "w"]:
			for f in floors:
				for a in [0.25, 0.75]:
					wins.append({"side": side, "at": a, "floor": f})
		building(r, floors, 3.2, mat, {
			"doors": [{"side": "n", "at": 0.5}, {"side": "s", "at": 0.5}, {"side": "e", "at": 0.5}],
			"windows": wins, "roof_access": floors >= 2 and _rng.randf() < 0.5, "floor_mat": "wood_dark"})
		if damaged:
			_shell_damage(r, floors * 3.2)
	# Barricades and rubble
	for p in [Vector3(-8, 0, 0), Vector3(8, 0, 1), Vector3(-18, 0, -14), Vector3(20, 0, 16), Vector3(-18, 0, 26), Vector3(20, 0, -18)]:
		_rubble(p)
	for p in [Vector3(-2, 0, 4), Vector3(4, 0, -4), Vector3(-18, 0, 4), Vector3(20, 0, -4)]:
		prop("sandbags", p, _rng.randf_range(-0.3, 0.3))
	prop("car_wreck", Vector3(-30, 0, 2), PI * 0.5 + 0.2)
	prop("car_wreck", Vector3(32, 0, -2), PI * 0.5 - 0.3)
	prop("truck", Vector3(-18, 0, -30), 0.1)
	prop("car", Vector3(20, 0, 30), PI)
	prop("bus", Vector3(44, 0, 1), PI * 0.5 + 0.1)
	for p in [Vector3(-10, 0, -14), Vector3(10, 0, -14), Vector3(-10, 0, -30), Vector3(10, 0, -30)]:
		prop("tree", p, _rng.randf() * TAU)
	for p in [Vector3(-22, 0, -8), Vector3(16, 0, 8), Vector3(-22, 0, 20), Vector3(16, 0, -26)]:
		prop("lamp", p, 0.0 if p.x < 0 else PI)
	for p in [Vector3(-34, 0, -4), Vector3(36, 0, 4), Vector3(4, 0, 24), Vector3(-4, 0, -36)]:
		prop(["crate_stack", "barrels", "dumpster", "barrier"][_rng.randi() % 4], p, _rng.randf_range(0, TAU))

	spawn_row(0, Vector3(-55, 0, -24), Vector3(-55, 0, 28), 8, Vector3.ZERO)
	spawn_row(0, Vector3(-40, 0, -4), Vector3(-28, 0, 4), 4, Vector3.ZERO)
	spawn_row(1, Vector3(55, 0, -24), Vector3(55, 0, 28), 8, Vector3.ZERO)
	spawn_row(1, Vector3(40, 0, -4), Vector3(28, 0, 4), 4, Vector3.ZERO)
	for p in [Vector3(0, 0, -40), Vector3(-39, 0, -41), Vector3(38, 0, -41), Vector3(-46, 0, -17), Vector3(32, 0, -18), Vector3(-46, 0, 16),
			Vector3(32, 0, 15), Vector3(0, 0, 14), Vector3(-41, 0, 38), Vector3(38, 0, 38), Vector3(0, 0, 37), Vector3(0, 0, -10)]:
		spawn(-1, p)
	flag("A", Vector3(-36, 0, 0))
	flag("B", Vector3(0, 0, -18))
	flag("C", Vector3(36, 0, 0))
	hq_points = [Vector3(0, 0, -40), Vector3(-46, 0, -17), Vector3(32, 0, 15), Vector3(0, 0, 14), Vector3(0, 0, 37)]
	for p in [Vector3(0, 0, -40), Vector3(0, 3.8, -40), Vector3(-39, 0, -41), Vector3(38, 0, -41), Vector3(-46, 0, -17), Vector3(32, 0, -18),
			Vector3(0, 0, 14), Vector3(-41, 0, 38), Vector3(38, 0, 38), Vector3(0, 0, -22), Vector3(-18, 0, 0), Vector3(20, 0, 0)]:
		hotspot(p)


## Knock a ragged hole in a building's wall and pile the rubble outside.
func _shell_damage(r: Rect2, h: float) -> void:
	var c := Vector3(r.get_center().x, 0, r.end.y)
	for i in 5:
		var p := c + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(0.5, 3.0))
		var sz := Vector3(_rng.randf_range(0.6, 1.6), _rng.randf_range(0.3, 0.9), _rng.randf_range(0.6, 1.6))
		var b := box(p, sz, "brick", _rng.randf_range(0, TAU), false)
		b.rotation.x = _rng.randf_range(-0.3, 0.3)
	# Scorch on the roof edge
	deco(Vector3(c.x, h - 0.4, c.z - 0.05), Vector3(4.0, 0.8, 0.2), "concrete_dark")


func _rubble(p: Vector3) -> void:
	for i in 7:
		var q := p + Vector3(_rng.randf_range(-2.2, 2.2), 0, _rng.randf_range(-1.2, 1.2))
		var sz := Vector3(_rng.randf_range(0.5, 1.4), _rng.randf_range(0.3, 1.1), _rng.randf_range(0.5, 1.2))
		var b := box(q, sz, ["brick", "concrete", "brick_grey"][i % 3], _rng.randf_range(0, TAU), i == 0)
		b.rotation.z = _rng.randf_range(-0.25, 0.25)
	box(p + Vector3(0, 0, 0), Vector3(3.5, 0.5, 1.6), "dirt", 0.0, false)

extends MapBase
## Overpass — a city block split by an elevated highway. Fight under the
## deck, up the on-ramps, through the gas station and apartment blocks.

const DECK_Y := 7.0


func _init() -> void:
	super._init()
	display_name = "Overpass"
	size = Vector2(120, 120)


func build() -> void:
	begin("overcast")
	ground("dirt")
	box(Vector3(0, -0.02, 0), Vector3(120, 0.04, 16), "asphalt", 0.0, false)
	box(Vector3(0, -0.02, 0), Vector3(10, 0.04, 120), "asphalt", 0.0, false)
	for s in [-1, 1]:
		deco(Vector3(0, 0, s * 8.2), Vector3(120, 0.18, 0.4), "concrete")
		box(Vector3(0, -0.01, s * 13.0), Vector3(120, 0.12, 9.6), "concrete", 0.0, false) # sidewalks

	# Elevated highway along X, centred on z = 0.
	box(Vector3(0, DECK_Y - 0.6, 0), Vector3(84, 0.6, 12), "concrete_dark", 0.0, false)
	for x in range(-36, 37, 12):
		box(Vector3(x, 0, -3.5), Vector3(1.4, DECK_Y - 0.6, 1.4), "concrete")
		box(Vector3(x, 0, 3.5), Vector3(1.4, DECK_Y - 0.6, 1.4), "concrete")
	for s in [-1, 1]:
		box(Vector3(0, DECK_Y, s * 5.8), Vector3(84, 1.0, 0.4), "concrete", 0.0, false) # parapets
	# On-ramps down to street level at both ends.
	ramp(Vector3(-42, DECK_Y - 0.3, 0), Vector3(-58, 0.0, 0), 11.0, "asphalt")
	ramp(Vector3(42, DECK_Y - 0.3, 0), Vector3(58, 0.0, 0), 11.0, "asphalt")
	# Maintenance stairs up to the deck mid-way.
	stairs(Vector3(2.5, 0, 12.5), Vector2(0, -1), 1.6, DECK_Y - 0.3, "metal")
	box(Vector3(2.5, DECK_Y - 0.5, 6.4), Vector3(1.8, 0.2, 1.6), "metal", 0.0, false)
	# Traffic jam on the deck
	prop("bus", Vector3(-20, DECK_Y - 0.3, -2.5), PI * 0.5 + 0.08)
	prop("car_wreck", Vector3(-6, DECK_Y - 0.3, 2.4), PI * 0.5 - 0.3)
	prop("truck", Vector3(14, DECK_Y - 0.3, -2.0), PI * 0.5)
	prop("car", Vector3(28, DECK_Y - 0.3, 2.5), PI * 0.5 + 0.2)
	prop("barrier", Vector3(34, DECK_Y - 0.3, -1.0), 0.6)
	prop("barrier", Vector3(-32, DECK_Y - 0.3, 1.0), -0.4)

	# North: apartment blocks
	building(Rect2(-50, -48, 20, 12), 3, 3.1, "brick", {
		"doors": [{"side": "s", "at": 0.3}, {"side": "s", "at": 0.8}, {"side": "e", "at": 0.5}],
		"windows": _row_windows(["s", "n"], [0.15, 0.5, 0.85], [0, 1, 2]) + [{"side": "w", "at": 0.5, "floor": 1}, {"side": "e", "at": 0.5, "floor": 2}],
		"roof_access": true})
	building(Rect2(-22, -46, 16, 10), 2, 3.1, "plaster", {
		"doors": [{"side": "s", "at": 0.5}, {"side": "w", "at": 0.5}],
		"windows": _row_windows(["s", "n"], [0.25, 0.75], [0, 1]) + [{"side": "e", "at": 0.5, "floor": 1}]})
	building(Rect2(18, -50, 22, 14), 3, 3.1, "brick_grey", {
		"doors": [{"side": "s", "at": 0.25}, {"side": "w", "at": 0.5}, {"side": "e", "at": 0.6}],
		"windows": _row_windows(["s", "n"], [0.15, 0.4, 0.65, 0.9], [0, 1, 2]),
		"roof_access": true, "stairs": "w"})
	# South: gas station and stores
	_gas_station(Vector3(-28, 0, 32))
	building(Rect2(2, 22, 14, 12), 1, 3.6, "plaster_white", {
		"doors": [{"side": "n", "at": 0.35, "width": 3.0}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "n", "at": 0.8, "width": 2.5, "bottom": 0.6}, {"side": "w", "at": 0.5}, {"side": "s", "at": 0.5}]})
	building(Rect2(24, 22, 18, 16), 2, 3.3, "brick", {
		"doors": [{"side": "n", "at": 0.3}, {"side": "w", "at": 0.6}],
		"windows": _row_windows(["n", "s"], [0.2, 0.6, 0.85], [0, 1]) + [{"side": "e", "at": 0.5, "floor": 1}],
		"roof_access": true})
	building(Rect2(-12, 40, 12, 12), 1, 3.4, "concrete", {
		"doors": [{"side": "n", "at": 0.5}, {"side": "e", "at": 0.5}],
		"windows": [{"side": "w", "at": 0.5}, {"side": "s", "at": 0.5}]})

	# Street clutter
	prop("car", Vector3(-40, 0, -6), PI * 0.5)
	prop("car_wreck", Vector3(-10, 0, 5), PI * 0.5 + 0.5)
	prop("car", Vector3(20, 0, 6), -PI * 0.5)
	prop("bus", Vector3(40, 0, -5.5), PI * 0.5)
	prop("car", Vector3(5, 0, -28), 0.1)
	prop("car_wreck", Vector3(-4, 0, 30), -0.2)
	for p in [Vector3(-30, 0, -12), Vector3(10, 0, -12), Vector3(-15, 0, 12), Vector3(35, 0, 12), Vector3(-50, 0, 12), Vector3(50, 0, -12)]:
		prop(["dumpster", "barrier", "sandbags", "crate_stack", "tires", "barrels"][_rng.randi() % 6], p, _rng.randf_range(0, TAU))
	for x in range(-48, 49, 16):
		prop("lamp", Vector3(x, 0, -9.0), PI)
		prop("lamp", Vector3(x + 8, 0, 9.0), 0.0)
	for p in [Vector3(-55, 0, -25), Vector3(55, 0, 25), Vector3(0, 0, -55), Vector3(45, 0, 50), Vector3(-50, 0, 50)]:
		prop("tree", p)

	spawn_row(0, Vector3(-57, 0, -40), Vector3(-57, 0, 40), 8, Vector3.ZERO)
	spawn_row(0, Vector3(-48, 0, -22), Vector3(-48, 0, 22), 4, Vector3.ZERO)
	spawn_row(1, Vector3(57, 0, -40), Vector3(57, 0, 40), 8, Vector3.ZERO)
	spawn_row(1, Vector3(48, 0, -22), Vector3(48, 0, 22), 4, Vector3.ZERO)
	for p in [Vector3(-40, 0, -30), Vector3(-14, 0, -32), Vector3(29, 0, -32), Vector3(-28, 0, 26), Vector3(9, 0, 28), Vector3(33, 0, 30),
			Vector3(-6, 0, 46), Vector3(0, DECK_Y - 0.3, 0), Vector3(-30, 0, 0), Vector3(30, 0, 0), Vector3(0, 0, -18), Vector3(0, 0, 18)]:
		spawn(-1, p)
	flag("A", Vector3(-38, 0, 10))
	flag("B", Vector3(0, DECK_Y - 0.3, 0))
	flag("C", Vector3(38, 0, -10))
	hq_points = [Vector3(-40, 0, -30), Vector3(29, 0, -32), Vector3(-28, 0, 26), Vector3(33, 0, 30), Vector3(0, 0, 0)]
	for p in [Vector3(-40, 0, -42), Vector3(-40, 3.1, -42), Vector3(-14, 0, -41), Vector3(29, 0, -43), Vector3(29, 6.2, -43),
			Vector3(-28, 0, 32), Vector3(9, 0, 28), Vector3(33, 0, 30), Vector3(-6, 0, 46), Vector3(0, 0, 0), Vector3(-20, DECK_Y - 0.3, 0),
			Vector3(20, DECK_Y - 0.3, 0)]:
		hotspot(p)


func _row_windows(sides: Array, ats: Array, floors: Array) -> Array:
	var out: Array = []
	for s in sides:
		for a in ats:
			for f in floors:
				out.append({"side": s, "at": a, "floor": f})
	return out


func _gas_station(c: Vector3) -> void:
	# Canopy on pillars over pumps, and a kiosk.
	for dx in [-6.0, 6.0]:
		for dz in [-3.5, 3.5]:
			box(c + Vector3(dx, 0, dz), Vector3(0.5, 4.5, 0.5), "concrete")
	box(c + Vector3(0, 4.5, 0), Vector3(15.0, 0.5, 9.0), "plaster_white", 0.0, false)
	deco(c + Vector3(0, 4.4, 0), Vector3(15.2, 0.2, 9.2), "fabric_red")
	for dx in [-3.0, 3.0]:
		box(c + Vector3(dx, 0, 0), Vector3(0.8, 1.6, 1.2), "fabric_red")
		box(c + Vector3(dx, 0, 0), Vector3(2.0, 0.25, 2.4), "concrete", 0.0, false)
	building(Rect2(c.x - 5, c.z + 8, 10, 7), 1, 3.3, "plaster_white", {
		"doors": [{"side": "n", "at": 0.5, "width": 2.0}],
		"windows": [{"side": "n", "at": 0.2, "width": 2.0, "bottom": 0.7}, {"side": "n", "at": 0.8, "width": 2.0, "bottom": 0.7}, {"side": "e", "at": 0.5}]})
	prop("car", c + Vector3(-3, 0, 2.5), 0.0)
	prop("shelf", Vector3(c.x - 2, 0, c.z + 13), 0.0)
	prop("shelf", Vector3(c.x + 2, 0, c.z + 13), 0.0)

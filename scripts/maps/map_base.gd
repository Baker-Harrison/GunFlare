class_name MapBase
extends Node3D
## Base for code-built maps. Provides building blocks (boxes, walls with
## openings, buildings, stairs, props), spawn/objective markers, lighting
## presets and runtime navmesh baking.

var display_name := "Map"
var size := Vector2(120, 120) # metres, centred on origin
var environment_node: WorldEnvironment
var sun: DirectionalLight3D
var nav_region: NavigationRegion3D
var geometry: Node3D
var minimap_rects: Array[Rect2] = []
var flags: Dictionary = {} # "A" -> Vector3
var hq_points: Array = []
var _spawns := {0: [], 1: [], -1: []} # team -> Array[Transform3D]; -1 = FFA
var _hotspots: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1337


## Override: build everything.
func build() -> void:
	pass


func center() -> Vector3:
	return Vector3.ZERO


func random_hotspot() -> Vector3:
	if _hotspots.is_empty():
		return Vector3(randf_range(-size.x * 0.4, size.x * 0.4), 0, randf_range(-size.y * 0.4, size.y * 0.4))
	return _hotspots[randi() % _hotspots.size()] + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))


func spawn_points(team: int, initial: bool) -> Array:
	if team < 0:
		var all: Array = _spawns[-1].duplicate()
		if all.is_empty():
			all = _spawns[0] + _spawns[1]
		return all
	var own: Array = _spawns.get(team % 2, [])
	if initial:
		return own
	# Mid-match: any spawn can be used; the scorer keeps you away from enemies.
	return _spawns[0] + _spawns[1] + _spawns[-1]


# --- Setup -------------------------------------------------------------------

func begin(env_preset: String) -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	add_child(nav_region)
	geometry = Node3D.new()
	geometry.name = "Geometry"
	nav_region.add_child(geometry)
	setup_environment(env_preset)


func setup_environment(preset: String) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.0
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	var quality: int = Settings.get_value("quality")
	match preset:
		"desert":
			sky_mat.sky_top_color = Color(0.3, 0.5, 0.78)
			sky_mat.sky_horizon_color = Color(0.82, 0.78, 0.7)
			sky_mat.ground_horizon_color = Color(0.7, 0.62, 0.5)
			sky_mat.ground_bottom_color = Color(0.4, 0.35, 0.28)
			sky_mat.sun_angle_max = 20.0
			sun.rotation_degrees = Vector3(-52, -35, 0)
			sun.light_color = Color(1.0, 0.93, 0.8)
			sun.light_energy = 1.55
			env.ambient_light_energy = 0.9
			env.fog_light_color = Color(0.82, 0.76, 0.65)
			env.fog_density = 0.0035
			env.adjustment_saturation = 0.95
		"overcast":
			sky_mat.sky_top_color = Color(0.48, 0.52, 0.56)
			sky_mat.sky_horizon_color = Color(0.68, 0.7, 0.72)
			sky_mat.ground_horizon_color = Color(0.55, 0.56, 0.56)
			sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.3)
			sky_mat.sky_cover_modulate = Color(0.8, 0.8, 0.8)
			sun.rotation_degrees = Vector3(-60, 120, 0)
			sun.light_color = Color(0.88, 0.9, 0.95)
			sun.light_energy = 0.75
			env.ambient_light_energy = 1.25
			env.fog_light_color = Color(0.62, 0.65, 0.68)
			env.fog_density = 0.006
			env.adjustment_saturation = 0.82
		"snow":
			sky_mat.sky_top_color = Color(0.5, 0.6, 0.72)
			sky_mat.sky_horizon_color = Color(0.84, 0.88, 0.92)
			sky_mat.ground_horizon_color = Color(0.85, 0.88, 0.92)
			sky_mat.ground_bottom_color = Color(0.6, 0.64, 0.7)
			sun.rotation_degrees = Vector3(-24, 60, 0)
			sun.light_color = Color(1.0, 0.92, 0.85)
			sun.light_energy = 1.1
			env.ambient_light_energy = 1.1
			env.fog_light_color = Color(0.82, 0.86, 0.92)
			env.fog_density = 0.009
			env.adjustment_saturation = 0.85
		"dusk":
			sky_mat.sky_top_color = Color(0.18, 0.24, 0.42)
			sky_mat.sky_horizon_color = Color(0.95, 0.55, 0.32)
			sky_mat.ground_horizon_color = Color(0.5, 0.35, 0.28)
			sky_mat.ground_bottom_color = Color(0.15, 0.13, 0.12)
			sun.rotation_degrees = Vector3(-11, -80, 0)
			sun.light_color = Color(1.0, 0.62, 0.38)
			sun.light_energy = 1.3
			env.ambient_light_energy = 0.6
			env.fog_light_color = Color(0.7, 0.45, 0.35)
			env.fog_density = 0.005
		"night":
			sky_mat.sky_top_color = Color(0.02, 0.03, 0.06)
			sky_mat.sky_horizon_color = Color(0.08, 0.1, 0.16)
			sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.08)
			sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.03)
			sky_mat.sun_angle_max = 2.0
			sun.rotation_degrees = Vector3(-40, 30, 0)
			sun.light_color = Color(0.55, 0.65, 0.9)
			sun.light_energy = 0.32
			env.ambient_light_energy = 0.45
			env.fog_light_color = Color(0.1, 0.12, 0.18)
			env.fog_density = 0.01
		_:
			sun.rotation_degrees = Vector3(-50, 30, 0)
	sky_mat.sun_curve = 0.1
	if quality >= 2:
		env.ssil_enabled = true
		env.ssil_intensity = 0.8
		env.ssr_enabled = preset in ["snow", "night", "overcast"]
	if quality >= 3:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.008
		env.volumetric_fog_albedo = env.fog_light_color
	if quality == 0:
		env.ssao_enabled = false
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 80.0
	environment_node = WorldEnvironment.new()
	environment_node.environment = env
	add_child(environment_node)
	add_child(sun)


# --- Geometry helpers ----------------------------------------------------------

## A solid box. `pos` is the centre of its base. Returns the StaticBody3D.
func box(pos: Vector3, sz: Vector3, mat_id: String, rot_y := 0.0, minimap := true, penetrable := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = pos + Vector3(0, sz.y * 0.5, 0)
	body.rotation.y = rot_y
	body.set_meta("surface", Materials.surface(mat_id))
	if penetrable or Materials.surface(mat_id) in ["wood", "plaster", "sheet_metal"]:
		body.set_meta("penetrable", true)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = Materials.get_mat(mat_id)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	cs.shape = shape
	body.add_child(cs)
	geometry.add_child(body)
	if minimap and sz.y > 1.0:
		_minimap_box(pos, sz, rot_y)
	return body


func _minimap_box(pos: Vector3, sz: Vector3, rot_y: float) -> void:
	if absf(rot_y) < 0.01 or absf(absf(rot_y) - PI) < 0.01:
		minimap_rects.append(Rect2(pos.x - sz.x * 0.5, pos.z - sz.z * 0.5, sz.x, sz.z))
	elif absf(absf(rot_y) - PI * 0.5) < 0.01:
		minimap_rects.append(Rect2(pos.x - sz.z * 0.5, pos.z - sz.x * 0.5, sz.z, sz.x))


## Visual-only mesh box (no collision), e.g. trims, window frames.
func deco(pos: Vector3, sz: Vector3, mat_id: String, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = Materials.get_mat(mat_id)
	mi.position = pos + Vector3(0, sz.y * 0.5, 0)
	mi.rotation.y = rot_y
	geometry.add_child(mi)
	return mi


## Straight wall from a to b (XZ) with openings: [{at: metres from a, width, bottom, top}].
func wall(a: Vector2, b: Vector2, base_y: float, height: float, thick: float, mat_id: String, openings: Array = []) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.01:
		return
	var n := dir / length
	var rot := -atan2(n.y, n.x)
	var sorted := openings.duplicate()
	sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["at"] < y["at"])
	var cursor := 0.0
	var seg := func(from_t: float, to_t: float, y0: float, y1: float) -> void:
		if to_t - from_t < 0.02 or y1 - y0 < 0.02:
			return
		var mid := a + n * ((from_t + to_t) * 0.5)
		box(Vector3(mid.x, base_y + y0, mid.y), Vector3(to_t - from_t, y1 - y0, thick), mat_id, rot, y0 < 0.5)
	for o: Dictionary in sorted:
		var w: float = o.get("width", 1.2)
		var start: float = clampf(float(o["at"]) - w * 0.5, 0.0, length)
		var end: float = clampf(float(o["at"]) + w * 0.5, 0.0, length)
		var bottom: float = o.get("bottom", 0.0)
		var top: float = minf(o.get("top", 2.2), height)
		seg.call(cursor, start, 0.0, height)
		seg.call(start, end, 0.0, bottom)
		seg.call(start, end, top, height)
		# Frame
		if bottom > 0.1:
			var mid2 := a + n * ((start + end) * 0.5)
			deco(Vector3(mid2.x, base_y + bottom - 0.05, mid2.y), Vector3(end - start + 0.1, 0.06, thick + 0.12), "concrete_dark", rot)
		cursor = end
	seg.call(cursor, length, 0.0, height)


## Rectangular building with walls, floors, flat roof, doors and windows and
## optional interior stairs. rect is on XZ. doors/windows: {side: n|s|e|w, at: 0..1, floor: int}
func building(rect: Rect2, floors: int, floor_h: float, wall_mat: String, opts: Dictionary = {}) -> void:
	var t: float = opts.get("thick", 0.3)
	var base_y: float = opts.get("base_y", 0.0)
	var doors: Array = opts.get("doors", [])
	var windows: Array = opts.get("windows", [])
	var floor_mat: String = opts.get("floor_mat", "concrete")
	var roof_access: bool = opts.get("roof_access", false)
	var stairs_side: String = opts.get("stairs", "e" if floors > 1 or roof_access else "")
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var sides := {
		"n": [Vector2(x0, z0), Vector2(x1, z0)],
		"s": [Vector2(x1, z1), Vector2(x0, z1)],
		"w": [Vector2(x0, z1), Vector2(x0, z0)],
		"e": [Vector2(x1, z0), Vector2(x1, z1)],
	}
	for f in floors:
		var y := base_y + f * floor_h
		for side: String in sides:
			var a: Vector2 = sides[side][0]
			var b: Vector2 = sides[side][1]
			var length := a.distance_to(b)
			var ops: Array = []
			for d: Dictionary in doors:
				if d["side"] == side and int(d.get("floor", 0)) == f:
					ops.append({"at": float(d["at"]) * length, "width": d.get("width", 1.4), "bottom": 0.0, "top": 2.3})
			for w: Dictionary in windows:
				if w["side"] == side and int(w.get("floor", f)) == f:
					ops.append({"at": float(w["at"]) * length, "width": w.get("width", 1.3), "bottom": w.get("bottom", 1.0), "top": w.get("top", 2.1)})
			# Inset walls so corners overlap cleanly.
			var dir := (b - a).normalized()
			var normal := Vector2(-dir.y, dir.x)
			var aa := a + normal * t * 0.5 - dir * (t * 0.5)
			var bb := b + normal * t * 0.5 + dir * (t * 0.5)
			wall(aa, bb, y, floor_h, t, wall_mat, ops)
		# Floor slab for upper floors, with a hole over the stairs below.
		if f > 0:
			_slab(rect, y - 0.25, 0.25, floor_mat, _stair_rect(rect, floor_h, stairs_side, f - 1) if stairs_side != "" else Rect2())
	# Ground floor
	box(Vector3(rect.get_center().x, base_y - 0.05, rect.get_center().y), Vector3(rect.size.x, 0.1, rect.size.y), floor_mat, 0.0, false)
	# Roof
	var roof_y := base_y + floors * floor_h
	if roof_access:
		_slab(rect, roof_y - 0.25, 0.25, opts.get("roof_mat", "roof"), _stair_rect(rect, floor_h, stairs_side, floors - 1))
		for side: String in sides:
			var a2: Vector2 = sides[side][0]
			var b2: Vector2 = sides[side][1]
			var dir2 := (b2 - a2).normalized()
			var nn := Vector2(-dir2.y, dir2.x)
			wall(a2 + nn * 0.15 - dir2 * 0.15, b2 + nn * 0.15 + dir2 * 0.15, roof_y, 1.0, 0.3, wall_mat)
	else:
		box(Vector3(rect.get_center().x, roof_y - 0.25, rect.get_center().y), Vector3(rect.size.x + 0.4, 0.35, rect.size.y + 0.4), opts.get("roof_mat", "roof"), 0.0, false)
	if stairs_side != "":
		var levels := floors - 1 + (1 if roof_access else 0)
		for f in levels:
			_interior_stairs(rect, base_y + f * floor_h, floor_h, stairs_side, f)
	for f in range(1, floors):
		var ty := base_y + f * floor_h - 0.15
		deco(Vector3(rect.get_center().x, ty, rect.get_center().y), Vector3(rect.size.x + 0.16, 0.18, rect.size.y + 0.16), "concrete_dark")


const STAIR_W := 1.4
const STAIR_RUN := 0.28


## Footprint of the stair flight for a level. Flights alternate between two
## strips along the stair wall so they never overlap.
func _stair_rect(rect: Rect2, rise: float, side: String, level: int) -> Rect2:
	var steps := int(ceil(rise / 0.2))
	var length := steps * STAIR_RUN
	var strip := level % 2
	var x := rect.end.x - 0.3 - STAIR_W * (strip + 1) if side == "e" else rect.position.x + 0.3 + STAIR_W * strip
	var z := rect.end.y - 0.4 - length if side == "e" else rect.position.y + 0.4
	return Rect2(x, z, STAIR_W, length + 0.1)


func _slab(rect: Rect2, y: float, thick: float, mat_id: String, hole: Rect2) -> void:
	if hole.size == Vector2.ZERO:
		box(Vector3(rect.get_center().x, y, rect.get_center().y), Vector3(rect.size.x, thick, rect.size.y), mat_id, 0.0, false)
		return
	var pieces: Array[Rect2] = [
		Rect2(rect.position.x, rect.position.y, hole.position.x - rect.position.x, rect.size.y),
		Rect2(hole.end.x, rect.position.y, rect.end.x - hole.end.x, rect.size.y),
		Rect2(hole.position.x, rect.position.y, hole.size.x, hole.position.y - rect.position.y),
		Rect2(hole.position.x, hole.end.y, hole.size.x, rect.end.y - hole.end.y),
	]
	for p in pieces:
		if p.size.x > 0.05 and p.size.y > 0.05:
			box(Vector3(p.get_center().x, y, p.get_center().y), Vector3(p.size.x, thick, p.size.y), mat_id, 0.0, false)


func _interior_stairs(rect: Rect2, y0: float, rise: float, side: String, level: int) -> void:
	var steps := int(ceil(rise / 0.2))
	var step_h := rise / steps
	var r := _stair_rect(rect, rise, side, level)
	var x := r.get_center().x
	for i in steps:
		var h := step_h * (i + 1)
		# "e" flights climb north from the south end, "w" flights climb south.
		var z := r.end.y - 0.1 - i * STAIR_RUN - STAIR_RUN * 0.5 if side == "e" else r.position.y + i * STAIR_RUN + STAIR_RUN * 0.5
		box(Vector3(x, y0, z), Vector3(STAIR_W - 0.05, h, STAIR_RUN + 0.02), "concrete_dark", 0.0, false)

## Exterior stairs climbing `rise` metres going in direction `dir` (unit XZ) from `start`.
func stairs(start: Vector3, dir: Vector2, width: float, rise: float, mat_id := "concrete") -> void:
	var steps := int(ceil(rise / 0.2))
	var step_h := rise / steps
	var run := 0.3
	var rot := -atan2(dir.y, dir.x) + PI * 0.5
	for i in steps:
		var p := start + Vector3(dir.x, 0, dir.y) * (i * run + run * 0.5)
		box(p, Vector3(width, step_h * (i + 1), run + 0.02), mat_id, rot, false)


func ramp(from: Vector3, to: Vector3, width: float, mat_id := "concrete") -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var d := to - from
	var flat := Vector2(d.x, d.z).length()
	var len := d.length()
	var mid := (from + to) * 0.5
	body.position = mid
	body.rotation = Vector3(atan2(d.y, flat), atan2(-d.x, -d.z), 0)
	body.set_meta("surface", Materials.surface(mat_id))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.2, len)
	mi.mesh = bm
	mi.material_override = Materials.get_mat(mat_id)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	body.add_child(cs)
	geometry.add_child(body)


func ground(mat_id: String, extra := 40.0) -> void:
	box(Vector3(0, -1.0, 0), Vector3(size.x + extra * 2, 1.0, size.y + extra * 2), mat_id, 0.0, false)
	# Invisible boundary
	for side in 4:
		var b := StaticBody3D.new()
		b.collision_layer = Layers.WORLD
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var horizontal := side < 2
		sh.size = Vector3(size.x + 2, 60, 1) if horizontal else Vector3(1, 60, size.y + 2)
		cs.shape = sh
		b.add_child(cs)
		var off := (size.y * 0.5 + 0.5) if horizontal else (size.x * 0.5 + 0.5)
		b.position = Vector3(0, 30, off * (1 if side % 2 == 0 else -1)) if horizontal else Vector3(off * (1 if side % 2 == 0 else -1), 30, 0)
		add_child(b)


# --- Props -------------------------------------------------------------------

func prop(kind: String, pos: Vector3, rot_y := 0.0) -> void:
	var path := "res://assets/props/%s.glb" % kind
	if ResourceLoader.exists(path):
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		inst.position = pos
		inst.rotation.y = rot_y
		geometry.add_child(inst)
		_add_prop_collision(kind, pos, rot_y)
		return
	match kind:
		"crate":
			box(pos, Vector3(1.2, 1.2, 1.2), "wood", rot_y, false, true)
		"crate_small":
			box(pos, Vector3(0.8, 0.8, 0.8), "wood", rot_y, false, true)
		"crate_stack":
			box(pos, Vector3(1.2, 1.2, 1.2), "wood", rot_y, false, true)
			box(pos + Vector3(0.6, 0, 0.9).rotated(Vector3.UP, rot_y), Vector3(1.2, 1.2, 1.2), "wood", rot_y + 0.3, false, true)
			box(pos + Vector3(0.2, 1.2, 0.3).rotated(Vector3.UP, rot_y), Vector3(1.1, 1.1, 1.1), "wood", rot_y + 0.1, false, true)
		"barrel":
			_cyl_body(pos, 0.3, 0.9, "metal_rust")
		"barrels":
			for i in 3:
				_cyl_body(pos + Vector3(i * 0.65 - 0.65, 0, (i % 2) * 0.4).rotated(Vector3.UP, rot_y), 0.3, 0.9, "metal_rust" if i != 1 else "container_blue")
		"sandbags":
			for i in 3:
				box(pos + Vector3(0, i * 0.3, 0), Vector3(2.4 - i * 0.15, 0.3, 0.6), "fabric_tan", rot_y, i == 0)
		"barrier":
			box(pos, Vector3(2.0, 0.9, 0.5), "concrete", rot_y)
			box(pos, Vector3(2.0, 0.25, 0.8), "concrete", rot_y, false)
		"car":
			_car(pos, rot_y, ["container_red", "container_blue", "plaster_white", "concrete_dark", "yellow_paint"][_rng.randi() % 5])
		"car_wreck":
			_car(pos, rot_y, "metal_rust", true)
		"container":
			_container(pos, rot_y, ["container_red", "container_blue", "container_green", "container_yellow"][_rng.randi() % 4])
		"dumpster":
			box(pos, Vector3(2.0, 1.3, 1.2), "container_green", rot_y)
		"pallets":
			for i in 4:
				box(pos + Vector3(0, i * 0.15, 0), Vector3(1.2, 0.14, 1.0), "wood", rot_y + i * 0.05, false, true)
		"tires":
			for i in 3:
				_cyl_body(pos + Vector3(0, i * 0.25, 0), 0.4, 0.25, "black_rubber")
		"tree":
			_cyl_body(pos, 0.22, 3.5, "wood_dark")
			var leaves := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 2.0
			sm.height = 3.6
			leaves.mesh = sm
			leaves.material_override = Materials.get_mat("foliage")
			leaves.position = pos + Vector3(0, 4.2, 0)
			geometry.add_child(leaves)
		"pine":
			_cyl_body(pos, 0.2, 2.0, "wood_dark")
			for i in 3:
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 2.0 - i * 0.5
				cm.height = 2.4
				cone.mesh = cm
				cone.material_override = Materials.get_mat("foliage")
				cone.position = pos + Vector3(0, 2.2 + i * 1.4, 0)
				geometry.add_child(cone)
		"lamp":
			_cyl_body(pos, 0.08, 5.0, "metal")
			deco(pos + Vector3(0, 5.0, 0), Vector3(0.4, 0.15, 0.4), "metal")
			var l := OmniLight3D.new()
			l.position = pos + Vector3(0, 4.8, 0)
			l.light_color = Color(1.0, 0.85, 0.6)
			l.light_energy = 2.0
			l.omni_range = 12.0
			l.shadow_enabled = Settings.get_value("quality") >= 2
			geometry.add_child(l)
		"rock":
			var r := box(pos, Vector3(2.5, 1.4, 2.0), "rock", rot_y)
			r.rotation.x = 0.1
		"fence":
			for i in 5:
				deco(pos + Vector3(i * 1.0 - 2.0, 0, 0).rotated(Vector3.UP, rot_y), Vector3(0.08, 1.8, 0.08), "metal", rot_y)
			var f := box(pos + Vector3(0, 0, 0), Vector3(4.2, 1.8, 0.04), "sheet_metal", rot_y, false, true)
			f.get_child(0).material_override = _fence_mat()
		"table":
			box(pos, Vector3(1.6, 0.75, 0.9), "wood", rot_y, false, true)
		"shelf":
			box(pos, Vector3(2.0, 2.0, 0.5), "metal", rot_y, false, true)
		"stall":
			for c in [Vector3(-1.2, 0, -1), Vector3(1.2, 0, -1), Vector3(-1.2, 0, 1), Vector3(1.2, 0, 1)]:
				_cyl_body(pos + c.rotated(Vector3.UP, rot_y), 0.05, 2.4, "wood")
			deco(pos + Vector3(0, 2.4, 0), Vector3(2.8, 0.06, 2.4), ["fabric_red", "fabric_blue", "fabric_tan"][_rng.randi() % 3], rot_y)
			box(pos + Vector3(0, 0, -0.6).rotated(Vector3.UP, rot_y), Vector3(2.4, 0.9, 0.8), "wood", rot_y, false, true)
		"water_tower":
			for c in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
				_cyl_body(pos + c, 0.15, 8.0, "metal_rust")
			_cyl_body(pos + Vector3(0, 8.0, 0), 2.4, 3.5, "metal_rust")
		"tank_small":
			_cyl_body(pos, 2.0, 4.0, "metal")
		"pipe":
			var p := box(pos, Vector3(0.6, 0.6, 12.0), "metal_rust", rot_y)
		_:
			box(pos, Vector3(1, 1, 1), "concrete", rot_y)


static var _fence: StandardMaterial3D


func _fence_mat() -> StandardMaterial3D:
	if _fence:
		return _fence
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var on := (x + y) % 16 < 2 or (x - y + 64) % 16 < 2
			img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 1.0) if on else Color(0, 0, 0, 0))
	_fence = StandardMaterial3D.new()
	_fence.albedo_texture = ImageTexture.create_from_image(img)
	_fence.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_fence.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fence.uv1_triplanar = true
	_fence.uv1_world_triplanar = true
	_fence.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_fence.metallic = 0.6
	return _fence


func _add_prop_collision(kind: String, pos: Vector3, rot_y: float) -> void:
	var sizes := {"crate": Vector3(1.2, 1.2, 1.2), "car": Vector3(1.9, 1.5, 4.4), "car_wreck": Vector3(1.9, 1.3, 4.4),
		"container": Vector3(2.45, 2.6, 6.1), "barrier": Vector3(2.0, 0.9, 0.6), "dumpster": Vector3(2.0, 1.3, 1.2)}
	var sz: Vector3 = sizes.get(kind, Vector3(1, 1, 1))
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.position = pos + Vector3(0, sz.y * 0.5, 0)
	body.rotation.y = rot_y
	body.set_meta("surface", "metal" if kind in ["car", "car_wreck", "container", "dumpster"] else "wood")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = sz
	cs.shape = sh
	body.add_child(cs)
	geometry.add_child(body)
	if sz.y > 1.0:
		_minimap_box(pos, sz, rot_y)


func _cyl_body(pos: Vector3, r: float, h: float, mat_id: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.position = pos + Vector3(0, h * 0.5, 0)
	body.set_meta("surface", Materials.surface(mat_id))
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = Materials.get_mat(mat_id)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	geometry.add_child(body)


func _car(pos: Vector3, rot_y: float, paint: String, wrecked := false) -> void:
	var lower := box(pos + Vector3(0, 0.3, 0), Vector3(1.85, 0.75, 4.4), paint, rot_y)
	box(pos + Vector3(0, 1.05, 0.2).rotated(Vector3.UP, rot_y), Vector3(1.7, 0.55 if not wrecked else 0.35, 2.3), "glass" if not wrecked else paint, rot_y, false)
	for c in [Vector3(-0.85, 0, -1.4), Vector3(0.85, 0, -1.4), Vector3(-0.85, 0, 1.4), Vector3(0.85, 0, 1.4)]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.34
		cm.bottom_radius = 0.34
		cm.height = 0.25
		w.mesh = cm
		w.material_override = Materials.get_mat("black_rubber")
		w.position = pos + (c + Vector3(0, 0.34, 0)).rotated(Vector3.UP, rot_y)
		w.rotation = Vector3(0, rot_y, PI * 0.5)
		geometry.add_child(w)


func _container(pos: Vector3, rot_y: float, paint: String) -> void:
	var b := box(pos, Vector3(2.45, 2.6, 6.1), paint, rot_y, true, true)
	# Corrugation ribs
	for i in 12:
		var z := -2.75 + i * 0.5
		deco(pos + Vector3(1.24, 0.1, z).rotated(Vector3.UP, rot_y), Vector3(0.04, 2.4, 0.18), paint, rot_y)
		deco(pos + Vector3(-1.24, 0.1, z).rotated(Vector3.UP, rot_y), Vector3(0.04, 2.4, 0.18), paint, rot_y)


# --- Markers -----------------------------------------------------------------

func spawn(team: int, pos: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	var dir := (face - pos) if face != Vector3.ZERO else (-pos)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	var yaw := atan2(-dir.x, -dir.z)
	_spawns[team].append(Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * 0.1))


## A line of spawns.
func spawn_row(team: int, from: Vector3, to: Vector3, count: int, face := Vector3.ZERO) -> void:
	for i in count:
		spawn(team, from.lerp(to, float(i) / maxf(count - 1, 1)), face)


func hotspot(p: Vector3) -> void:
	_hotspots.append(p)


func flag(label: String, p: Vector3) -> void:
	flags[label] = p
	hotspot(p)


# --- Navigation --------------------------------------------------------------

func bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.25
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	nm.filter_baking_aabb = AABB(Vector3(-size.x * 0.5 - 2, -3, -size.y * 0.5 - 2), Vector3(size.x + 4, 60, size.y + 4))
	nav_region.navigation_mesh = nm
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.25)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.1)
	nav_region.bake_navigation_mesh(true)
	await nav_region.bake_finished

class_name CamoLibrary
## Weapon camos and fabric patterns built on the procedural camo shader.

const SHADER_PATH := "res://assets/shaders/camo.gdshader"

## camo id -> pattern + colours
const CAMOS := {
	"camo_woodland": {"pattern": 0, "c0": Color(0.32, 0.33, 0.22), "c1": Color(0.17, 0.2, 0.12), "c2": Color(0.4, 0.32, 0.2), "c3": Color(0.07, 0.07, 0.06), "scale": 6.0},
	"camo_dune": {"pattern": 0, "c0": Color(0.72, 0.62, 0.45), "c1": Color(0.58, 0.47, 0.32), "c2": Color(0.82, 0.74, 0.58), "c3": Color(0.45, 0.36, 0.25), "scale": 5.0},
	"camo_frostbite": {"pattern": 0, "c0": Color(0.86, 0.88, 0.9), "c1": Color(0.62, 0.66, 0.7), "c2": Color(0.95, 0.96, 0.97), "c3": Color(0.35, 0.38, 0.42), "scale": 6.0},
	"camo_pixel": {"pattern": 1, "c0": Color(0.42, 0.42, 0.36), "c1": Color(0.25, 0.27, 0.22), "c2": Color(0.55, 0.52, 0.42), "c3": Color(0.12, 0.12, 0.1), "scale": 5.0},
	"camo_slate": {"pattern": 4, "c0": Color(0.42, 0.43, 0.45), "c1": Color(0.27, 0.28, 0.3), "c2": Color(0.6, 0.6, 0.6), "c3": Color(0.12, 0.12, 0.13), "scale": 5.0},
	"camo_crimson": {"pattern": 2, "c0": Color(0.55, 0.08, 0.07), "c1": Color(0.12, 0.02, 0.02), "c2": Color(0.75, 0.2, 0.15), "c3": Color(0.05, 0.02, 0.02), "scale": 5.0},
	"camo_ember": {"pattern": 5, "c0": Color(0.08, 0.07, 0.07), "c1": Color(0.18, 0.12, 0.1), "c2": Color(0.0, 0.0, 0.0), "c3": Color(0.0, 0.0, 0.0), "scale": 4.0, "emission": Color(1.0, 0.35, 0.05)},
	"camo_gilded": {"pattern": 3, "c0": Color(1.0, 0.77, 0.34), "c1": Color(0.85, 0.6, 0.22), "c2": Color(0, 0, 0), "c3": Color(0, 0, 0), "scale": 3.0},
}

static var _shader: Shader
static var _cache: Dictionary = {}


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH)
	return _shader


static func weapon_material(camo_id: String) -> Material:
	if not CAMOS.has(camo_id):
		return null
	if _cache.has(camo_id):
		return _cache[camo_id]
	var d: Dictionary = CAMOS[camo_id]
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("pattern", d["pattern"])
	for k in ["c0", "c1", "c2", "c3"]:
		var c: Color = d[k]
		m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("scale", d["scale"])
	m.set_shader_parameter("metallic_value", 0.35)
	m.set_shader_parameter("roughness_value", 0.55)
	m.set_shader_parameter("wear", 0.3)
	if d.has("emission"):
		var e: Color = d["emission"]
		m.set_shader_parameter("emission_color", Vector3(e.r, e.g, e.b))
	_cache[camo_id] = m
	return m


static func fabric_material(base: Color, secondary: Color, style: int) -> Material:
	var key := "fabric_%s_%s_%d" % [base.to_html(), secondary.to_html(), style]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("pattern", 0 if style == 0 else 1)
	m.set_shader_parameter("c0", Vector3(base.r, base.g, base.b))
	var dark := base.darkened(0.35)
	m.set_shader_parameter("c1", Vector3(dark.r, dark.g, dark.b))
	m.set_shader_parameter("c2", Vector3(secondary.r, secondary.g, secondary.b))
	var darker := base.darkened(0.6)
	m.set_shader_parameter("c3", Vector3(darker.r, darker.g, darker.b))
	m.set_shader_parameter("scale", 4.0)
	m.set_shader_parameter("metallic_value", 0.0)
	m.set_shader_parameter("roughness_value", 0.92)
	m.set_shader_parameter("wear", 0.0)
	_cache[key] = m
	return m

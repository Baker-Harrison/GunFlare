class_name Materials
## World materials. Uses baked textures from res://assets/textures/<id>_*.png
## (made by tools/gen_textures.py) when present; otherwise builds noise-based
## textures at runtime. All are triplanar so box geometry needs no UVs.

## id: base colour, variation colour, noise frequency, roughness, normal strength, tile scale, surface type
const DEFS := {
	"concrete": [Color(0.55, 0.54, 0.51), Color(0.42, 0.41, 0.39), 0.012, 0.9, 0.6, 0.35, "concrete"],
	"concrete_dark": [Color(0.36, 0.36, 0.35), Color(0.27, 0.27, 0.27), 0.012, 0.9, 0.6, 0.35, "concrete"],
	"plaster": [Color(0.78, 0.71, 0.6), Color(0.68, 0.6, 0.5), 0.008, 0.95, 0.4, 0.3, "plaster"],
	"plaster_white": [Color(0.86, 0.84, 0.8), Color(0.75, 0.73, 0.7), 0.008, 0.95, 0.4, 0.3, "plaster"],
	"plaster_blue": [Color(0.45, 0.6, 0.68), Color(0.38, 0.5, 0.58), 0.008, 0.95, 0.4, 0.3, "plaster"],
	"plaster_terracotta": [Color(0.72, 0.42, 0.3), Color(0.6, 0.34, 0.24), 0.008, 0.95, 0.4, 0.3, "plaster"],
	"brick": [Color(0.55, 0.3, 0.22), Color(0.4, 0.22, 0.16), 0.03, 0.85, 1.0, 0.5, "concrete"],
	"brick_grey": [Color(0.45, 0.44, 0.43), Color(0.33, 0.32, 0.31), 0.03, 0.85, 1.0, 0.5, "concrete"],
	"sand": [Color(0.78, 0.68, 0.5), Color(0.66, 0.56, 0.4), 0.006, 1.0, 0.5, 0.15, "dirt"],
	"dirt": [Color(0.42, 0.35, 0.26), Color(0.32, 0.27, 0.2), 0.008, 1.0, 0.6, 0.15, "dirt"],
	"grass": [Color(0.3, 0.38, 0.18), Color(0.22, 0.3, 0.13), 0.02, 1.0, 0.5, 0.2, "dirt"],
	"snow": [Color(0.9, 0.92, 0.95), Color(0.8, 0.83, 0.88), 0.006, 0.8, 0.3, 0.15, "dirt"],
	"asphalt": [Color(0.2, 0.2, 0.21), Color(0.14, 0.14, 0.15), 0.05, 0.92, 0.5, 0.25, "concrete"],
	"metal": [Color(0.42, 0.44, 0.46), Color(0.32, 0.34, 0.35), 0.01, 0.5, 0.3, 0.3, "metal"],
	"metal_rust": [Color(0.45, 0.28, 0.17), Color(0.3, 0.2, 0.14), 0.02, 0.8, 0.6, 0.3, "metal"],
	"sheet_metal": [Color(0.5, 0.52, 0.53), Color(0.4, 0.41, 0.42), 0.01, 0.55, 0.4, 0.3, "sheet_metal"],
	"container_red": [Color(0.55, 0.16, 0.12), Color(0.42, 0.12, 0.09), 0.01, 0.6, 0.4, 0.3, "sheet_metal"],
	"container_blue": [Color(0.16, 0.3, 0.5), Color(0.12, 0.22, 0.38), 0.01, 0.6, 0.4, 0.3, "sheet_metal"],
	"container_green": [Color(0.2, 0.38, 0.25), Color(0.15, 0.28, 0.18), 0.01, 0.6, 0.4, 0.3, "sheet_metal"],
	"container_yellow": [Color(0.72, 0.55, 0.15), Color(0.58, 0.44, 0.12), 0.01, 0.6, 0.4, 0.3, "sheet_metal"],
	"wood": [Color(0.48, 0.34, 0.2), Color(0.36, 0.25, 0.14), 0.04, 0.85, 0.6, 0.4, "wood"],
	"wood_dark": [Color(0.3, 0.2, 0.12), Color(0.22, 0.14, 0.08), 0.04, 0.8, 0.6, 0.4, "wood"],
	"tile": [Color(0.7, 0.68, 0.62), Color(0.6, 0.58, 0.52), 0.05, 0.4, 0.6, 0.5, "concrete"],
	"roof": [Color(0.3, 0.28, 0.26), Color(0.22, 0.2, 0.19), 0.02, 0.9, 0.5, 0.3, "concrete"],
	"rock": [Color(0.48, 0.45, 0.4), Color(0.35, 0.33, 0.3), 0.01, 0.95, 1.0, 0.12, "concrete"],
	"glass": [Color(0.25, 0.32, 0.36), Color(0.2, 0.27, 0.3), 0.01, 0.1, 0.1, 0.5, "metal"],
	"fabric_red": [Color(0.6, 0.15, 0.12), Color(0.48, 0.1, 0.08), 0.03, 1.0, 0.3, 0.6, "wood"],
	"fabric_blue": [Color(0.18, 0.3, 0.55), Color(0.12, 0.2, 0.42), 0.03, 1.0, 0.3, 0.6, "wood"],
	"fabric_tan": [Color(0.75, 0.66, 0.48), Color(0.62, 0.54, 0.38), 0.03, 1.0, 0.3, 0.6, "wood"],
	"foliage": [Color(0.22, 0.32, 0.14), Color(0.15, 0.24, 0.1), 0.06, 1.0, 0.6, 0.6, "wood"],
	"ice": [Color(0.75, 0.85, 0.92), Color(0.65, 0.75, 0.85), 0.006, 0.2, 0.2, 0.2, "concrete"],
	"yellow_paint": [Color(0.85, 0.7, 0.15), Color(0.75, 0.6, 0.12), 0.01, 0.6, 0.2, 0.3, "metal"],
	"black_rubber": [Color(0.06, 0.06, 0.06), Color(0.04, 0.04, 0.04), 0.02, 0.9, 0.3, 0.5, "wood"],
}

static var _cache: Dictionary = {}


static func surface(id: String) -> String:
	return DEFS[id][6] if DEFS.has(id) else "concrete"


static func get_mat(id: String) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var d: Array = DEFS.get(id, DEFS["concrete"])
	var m := StandardMaterial3D.new()
	m.resource_name = id
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	var scale: float = d[5]
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = d[3]
	var base := "res://assets/textures/%s" % id
	if ResourceLoader.exists(base + "_albedo.png"):
		m.albedo_texture = load(base + "_albedo.png")
		if ResourceLoader.exists(base + "_normal.png"):
			m.normal_enabled = true
			m.normal_texture = load(base + "_normal.png")
			m.normal_scale = 1.0
		if ResourceLoader.exists(base + "_rough.png"):
			m.roughness_texture = load(base + "_rough.png")
			m.roughness = 1.0
	else:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = d[2]
		noise.fractal_octaves = 5
		noise.seed = hash(id)
		var tex := NoiseTexture2D.new()
		tex.width = 512
		tex.height = 512
		tex.seamless = true
		tex.noise = noise
		var g := Gradient.new()
		g.set_color(0, d[1])
		g.set_color(1, d[0])
		tex.color_ramp = g
		m.albedo_texture = tex
		var ntex := NoiseTexture2D.new()
		ntex.width = 512
		ntex.height = 512
		ntex.seamless = true
		ntex.as_normal_map = true
		ntex.bump_strength = 4.0 * float(d[4])
		var n2 := FastNoiseLite.new()
		n2.frequency = float(d[2]) * 3.0
		n2.fractal_octaves = 4
		n2.seed = hash(id) + 1
		ntex.noise = n2
		m.normal_enabled = true
		m.normal_texture = ntex
		m.normal_scale = 0.6
	if id in ["metal", "sheet_metal"] or id.begins_with("container"):
		m.metallic = 0.55
	if id == "glass":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.45)
		m.metallic = 0.6
		m.roughness = 0.05
	_cache[id] = m
	return m

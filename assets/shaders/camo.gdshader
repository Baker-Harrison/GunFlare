shader_type spatial;
// Procedural camouflage evaluated in object space, so it wraps any weapon or
// garment without UVs. Patterns:
// 0 blotch (woodland/dune/arctic), 1 digital, 2 tiger stripe, 3 polished metal
// (gold), 4 urban splinter, 5 glowing ember veins.

uniform int pattern = 0;
uniform vec3 c0 : source_color = vec3(0.3, 0.32, 0.22);
uniform vec3 c1 : source_color = vec3(0.18, 0.2, 0.13);
uniform vec3 c2 : source_color = vec3(0.42, 0.36, 0.25);
uniform vec3 c3 : source_color = vec3(0.08, 0.08, 0.07);
uniform float scale = 7.0;
uniform float metallic_value = 0.25;
uniform float roughness_value = 0.62;
uniform vec3 emission_color : source_color = vec3(1.0, 0.35, 0.05);
uniform float wear = 0.25;

varying vec3 obj_pos;
varying vec3 obj_norm;

void vertex() {
	obj_pos = VERTEX;
	obj_norm = NORMAL;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 4.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 p = obj_pos * scale;
	vec3 col = c0;
	float metal = metallic_value;
	float rough = roughness_value;
	vec3 emit = vec3(0.0);
	if (pattern == 0) {
		if (fbm(p) > 0.52) col = c1;
		if (fbm(p * 1.3 + 31.0) > 0.58) col = c2;
		if (fbm(p * 1.6 + 77.0) > 0.63) col = c3;
	} else if (pattern == 1) {
		vec3 q = floor(p * 3.0) / 3.0;
		vec3 q2 = floor(p * 6.0) / 6.0;
		if (fbm(q) > 0.5) col = c1;
		if (fbm(q2 * 1.2 + 13.0) > 0.58) col = c2;
		if (fbm(q * 1.5 + 41.0) > 0.62) col = c3;
	} else if (pattern == 2) {
		float s = sin(p.y * 2.5 + p.x * 0.6 + fbm(p * 0.7) * 7.0);
		if (s > 0.35) col = c1;
		if (s > 0.8) col = c3;
		if (fbm(p * 2.0) > 0.62) col = mix(col, c2, 0.6);
	} else if (pattern == 3) {
		float n = fbm(p * 2.0);
		col = mix(c0, c1, n);
		metal = 1.0;
		rough = 0.18 + n * 0.12;
	} else if (pattern == 4) {
		float a = fbm(vec3(floor(p.x * 1.5 + p.y), floor(p.y * 2.0 - p.z), floor(p.z * 1.5)) * 0.7);
		if (a > 0.45) col = c1;
		if (a > 0.6) col = c2;
		if (fbm(p * 3.0) > 0.66) col = c3;
	} else if (pattern == 5) {
		float n = fbm(p * 1.4);
		float vein = 1.0 - smoothstep(0.0, 0.05, abs(n - 0.5));
		col = mix(c0, c1, fbm(p * 3.0));
		emit = emission_color * vein * 3.0;
		rough = 0.45;
	}
	// Edge wear: bare metal shows through on raised areas.
	float edge = smoothstep(0.62, 0.78, fbm(p * 4.0 + 100.0));
	col = mix(col, vec3(0.35, 0.35, 0.36), edge * wear);
	metal = mix(metal, 0.9, edge * wear);
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
}

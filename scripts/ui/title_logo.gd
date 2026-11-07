class_name TitleLogo
extends Control
## Game logo: wide-tracked heavy letters with a brushed-metal gradient, an
## accent glow, a moving shine and a tag line.

const SHADER := """
shader_type canvas_item;
uniform float shine_pos = -0.3;
uniform float width = 900.0;
varying vec2 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.0 && c.r > 0.9) {
		float v = clamp(local_pos.y / 130.0, 0.0, 1.0);
		vec3 metal = mix(vec3(1.0, 0.99, 0.95), vec3(0.62, 0.64, 0.6), smoothstep(0.35, 1.0, v));
		metal += vec3(0.25) * (1.0 - smoothstep(0.0, 0.2, abs(v - 0.48)));
		float d = local_pos.x / width - shine_pos - (local_pos.y / width) * 0.35;
		float shine = 1.0 - smoothstep(0.0, 0.03, abs(d));
		c.rgb = metal * c.rgb + vec3(shine * 0.9);
	}
	COLOR = c;
}
"""

var text := "GUNFARE"
var tagline := "TACTICAL  COMBAT  ·  OFFLINE  WITH  BOTS"
var font_size := 132
var tracking := 14.0
var _t := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	custom_minimum_size = Vector2(_text_width() + 20.0, font_size * 1.35)
	size = custom_minimum_size
	_mat.set_shader_parameter("width", size.x)


func _text_width() -> float:
	var f := UiKit.font(true)
	var w := 0.0
	for ch in text:
		w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking
	return w - tracking


func _process(delta: float) -> void:
	_t += delta
	var cycle := fmod(_t, 7.0) / 7.0
	_mat.set_shader_parameter("shine_pos", lerpf(-0.3, 1.6, cycle))
	queue_redraw()


func _draw() -> void:
	var f := UiKit.font(true)
	var base := float(font_size) * 0.92
	var pulse := 0.5 + 0.5 * sin(_t * 1.3)
	# Accent glow: offset copies at low alpha (red channel < 0.9 skips the metal pass).
	var glow := Color(UiKit.ACCENT.r * 0.85, UiKit.ACCENT.g * 0.85, UiKit.ACCENT.b * 0.85, 0.025 + pulse * 0.02)
	for r in [8.0, 4.0]:
		for k in 8:
			var a := TAU * k / 8.0
			_draw_tracked(f, Vector2(cos(a), sin(a)) * r + Vector2(0, base), glow)
	# Drop shadow.
	_draw_tracked(f, Vector2(5, base + 6), Color(0, 0, 0, 0.55))
	_draw_tracked(f, Vector2(0, base), Color(1, 1, 1, 1))
	# Accent slash under the word and the tag line.
	var w := _text_width()
	var y := base + 22.0
	draw_rect(Rect2(4, y, 90, 5), UiKit.ACCENT * Color(0.88, 0.88, 0.88, 1))
	draw_rect(Rect2(100, y, w - 100, 1), Color(0.8, 0.8, 0.8, 0.35))
	draw_string(UiKit.font(true), Vector2(4, y + 32), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.8, 0.8, 0.78, 0.85))


func _draw_tracked(f: Font, origin: Vector2, color: Color) -> void:
	var x := origin.x
	for ch in text:
		draw_string(f, Vector2(x, origin.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking

class_name MenuBackdrop
extends Control
## Animated backdrop for menus: a slowly drifting gradient with a grid of
## faint topographic lines and a sweeping radar arc.

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := get_viewport_rect().size
	var steps := 24
	for i in steps:
		var f := float(i) / steps
		var c := Color(0.05, 0.07, 0.06).lerp(Color(0.12, 0.14, 0.1), f * 0.8 + sin(_t * 0.2) * 0.05)
		draw_rect(Rect2(0, s.y * f, s.x, s.y / steps + 1), c)
	# Topographic contour lines
	for k in 18:
		var pts := PackedVector2Array()
		var base := s.y * (0.15 + k * 0.05)
		for x in range(0, int(s.x) + 40, 40):
			var y := base + sin(x * 0.004 + k * 0.7 + _t * 0.05) * 30.0 + sin(x * 0.011 + k) * 12.0
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(0.6, 0.8, 0.4, 0.05), 1.5, true)
	# Grid
	for x in range(0, int(s.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.025), 1.0)
	for y in range(0, int(s.y), 80):
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.025), 1.0)
	# Radar sweep
	var c := Vector2(s.x * 0.72, s.y * 0.62)
	var r := s.y * 0.42
	for i in 4:
		draw_arc(c, r * (i + 1) / 4.0, 0, TAU, 96, Color(0.7, 0.95, 0.4, 0.06), 1.5, true)
	var a := fmod(_t * 0.6, TAU)
	for i in 30:
		var aa := a - i * 0.02
		draw_line(c, c + Vector2(cos(aa), sin(aa)) * r, Color(0.7, 0.95, 0.4, 0.12 * (1.0 - i / 30.0)), 2.0)
	# Blips
	for i in 7:
		var ang := float(i) * 2.1 + 0.4
		var d := r * (0.25 + fmod(i * 0.37, 0.7))
		var p := c + Vector2(cos(ang), sin(ang)) * d
		var since := fposmod(a - ang, TAU)
		var alpha := clampf(1.0 - since / 2.5, 0.0, 1.0)
		draw_circle(p, 4.0, Color(1.0, 0.35, 0.3, alpha * 0.8))

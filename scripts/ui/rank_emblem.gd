class_name RankEmblem
extends Control
## Hexagonal rank badge with chevrons for the rank tier and stars for
## Ascension levels.

var rank := 1
var ascension := 0


func _init(p_rank: int = 1, p_ascension: int = 0, edge: float = 84.0) -> void:
	rank = p_rank
	ascension = p_ascension
	custom_minimum_size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.48
	var hex := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 7:
		var a := PI / 6.0 + TAU * i / 6.0
		hex.append(c + Vector2(cos(a), sin(a)) * r)
		inner.append(c + Vector2(cos(a), sin(a)) * r * 0.84)
	var fill := hex.slice(0, 6)
	draw_colored_polygon(fill, Color(0.06, 0.07, 0.06, 0.92))
	draw_polyline(hex, Color(UiKit.ACCENT, 0.9), 2.5, true)
	draw_polyline(inner, Color(1, 1, 1, 0.12), 1.0, true)
	# 1-3 chevrons by rank tier.
	var chevrons := clampi(1 + (rank - 1) / 18, 1, 3)
	for i in chevrons:
		var y := c.y + r * 0.28 - i * r * 0.3
		var w := r * 0.55
		var pts := PackedVector2Array([Vector2(c.x - w, y), Vector2(c.x, y - r * 0.28), Vector2(c.x + w, y)])
		draw_polyline(pts, Color(UiKit.ACCENT, 1.0 - i * 0.12), r * 0.13, true)
	var f := UiKit.font(true)
	var s := str(rank)
	var fs := int(r * 0.42)
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(c.x - tw * 0.5, c.y + r * 0.72), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.TEXT)
	for i in mini(ascension, 5):
		var sx := c.x + (i - (mini(ascension, 5) - 1) * 0.5) * r * 0.3
		draw_circle(Vector2(sx, c.y - r * 0.72), r * 0.07, Color(1.0, 0.82, 0.35))

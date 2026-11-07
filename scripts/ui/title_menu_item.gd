class_name TitleMenuItem
extends Button
## Large front-end menu entry: index number, title, a sliding accent bar and
## a soft highlight strip on hover or focus. Works with mouse, keyboard and
## gamepad focus.

signal highlighted(item: TitleMenuItem)

var index := 0
var title := ""
var detail := ""
var lock_text := ""
var _hot := 0.0
var _target := 0.0
var _intro := 0.0
var _intro_delay := 0.0


func _init(p_index: int, p_title: String, p_detail: String, cb: Callable) -> void:
	index = p_index
	title = p_title
	detail = p_detail
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(560, 66)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)
	pressed.connect(func() -> void:
		Sfx.play_ui("click")
		cb.call())
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(func() -> void:
		_target = 1.0
		Sfx.play_ui("hover")
		highlighted.emit(self))
	focus_exited.connect(func() -> void: _target = 0.0)


## Fades and slides the entry in after `delay` seconds.
func play_intro(delay: float) -> void:
	_intro = 0.0
	_intro_delay = delay


func _process(delta: float) -> void:
	var before := _hot
	_hot = move_toward(_hot, _target, delta * 6.0)
	if _intro_delay > 0.0:
		_intro_delay -= delta
	elif _intro < 1.0:
		_intro = minf(_intro + delta * 3.0, 1.0)
	if before != _hot or _intro < 1.0:
		queue_redraw()


func _draw() -> void:
	var ease_in := 1.0 - pow(1.0 - _intro, 3.0)
	var h := 1.0 - pow(1.0 - _hot, 3.0)
	var slide := (1.0 - ease_in) * -60.0
	var alpha := ease_in * (0.45 if disabled else 1.0)
	var sz := size
	# Highlight strip: a left-to-right fade.
	if h > 0.001:
		var w := sz.x * (0.35 + 0.65 * h)
		var pts := PackedVector2Array([Vector2(slide, 4), Vector2(slide + w, 4), Vector2(slide + w, sz.y - 4), Vector2(slide, sz.y - 4)])
		var c0 := Color(UiKit.ACCENT, 0.22 * h * alpha)
		var c1 := Color(UiKit.ACCENT, 0.0)
		draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))
		draw_rect(Rect2(slide, 4, 5, sz.y - 8), Color(UiKit.ACCENT, h * alpha))
	var bold := UiKit.font(true)
	var reg := UiKit.font()
	var x := slide + 26.0 + h * 14.0
	var num := "%02d" % index
	draw_string(reg, Vector2(x, sz.y * 0.5 + 6), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiKit.ACCENT if h > 0.5 else UiKit.MUTED, alpha))
	var tc := UiKit.TEXT.lerp(Color.WHITE, h)
	if disabled:
		tc = UiKit.LOCKED
	var title_x := x + 40.0
	draw_string(bold, Vector2(title_x, sz.y * 0.5 + 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(tc, alpha))
	if lock_text != "":
		var tw := bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
		var lx := title_x + tw + 18.0
		var lw := reg.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		draw_rect(Rect2(lx, sz.y * 0.5 - 12, lw, 24), Color(1, 1, 1, 0.08 * alpha))
		draw_rect(Rect2(lx, sz.y * 0.5 - 12, lw, 24), Color(1, 1, 1, 0.25 * alpha), false, 1.0)
		draw_string(reg, Vector2(lx + 9, sz.y * 0.5 + 5), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UiKit.MUTED, alpha))
	# Chevron on the right when hot.
	if h > 0.01 and not disabled:
		var cx := slide + sz.x - 40.0 + (1.0 - h) * -20.0
		var cy := sz.y * 0.5
		var col := Color(UiKit.ACCENT, h * alpha)
		draw_polyline(PackedVector2Array([Vector2(cx, cy - 10), Vector2(cx + 10, cy), Vector2(cx, cy + 10)]), col, 3.0, true)

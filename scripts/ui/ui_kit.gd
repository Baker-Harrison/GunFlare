class_name UiKit
## Shared styling for menus: fonts, colours, panels and buttons.

const ACCENT := Color(0.78, 0.95, 0.35)
const ACCENT_DIM := Color(0.55, 0.7, 0.25)
const BG := Color(0.04, 0.05, 0.05, 0.86)
const PANEL := Color(0.08, 0.09, 0.09, 0.9)
const TEXT := Color(0.92, 0.93, 0.9)
const MUTED := Color(0.6, 0.62, 0.6)
const LOCKED := Color(0.45, 0.45, 0.45)
const RED := Color(1.0, 0.38, 0.3)
const BLUE := Color(0.4, 0.8, 1.0)

static var _font: Font
static var _font_bold: Font
static var _theme: Theme


static func font(bold := false) -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Arial Narrow", "Segoe UI", "Sans-Serif"])
		f.font_weight = 500
		_font = f
		var b := SystemFont.new()
		b.font_names = f.font_names
		b.font_weight = 700
		_font_bold = b
	return _font_bold if bold else _font


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	var normal := _flat(Color(0.12, 0.13, 0.13, 0.85), Color(1, 1, 1, 0.08))
	var hover := _flat(Color(0.2, 0.23, 0.15, 0.95), ACCENT_DIM)
	var pressed := _flat(Color(0.28, 0.33, 0.16, 1.0), ACCENT)
	var disabled := _flat(Color(0.08, 0.08, 0.08, 0.7), Color(1, 1, 1, 0.04))
	var focus := _flat(Color(0, 0, 0, 0), ACCENT)
	for cls in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, ACCENT)
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, LOCKED)
	t.set_stylebox("panel", "Panel", _flat(PANEL, Color(1, 1, 1, 0.06)))
	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, Color(1, 1, 1, 0.06)))
	t.set_color("font_color", "Label", TEXT)
	var slider_bg := _flat(Color(0.2, 0.2, 0.2), Color(0, 0, 0, 0))
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", _flat(ACCENT_DIM, Color(0, 0, 0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT, Color(0, 0, 0, 0)))
	t.set_stylebox("normal", "LineEdit", _flat(Color(0.1, 0.1, 0.1), Color(1, 1, 1, 0.15)))
	t.set_stylebox("focus", "LineEdit", _flat(Color(0.1, 0.1, 0.1), ACCENT))
	t.set_stylebox("panel", "PopupMenu", _flat(Color(0.08, 0.08, 0.08, 0.98), Color(1, 1, 1, 0.1)))
	t.set_stylebox("background", "ProgressBar", _flat(Color(0.15, 0.15, 0.15), Color(0, 0, 0, 0)))
	t.set_stylebox("fill", "ProgressBar", _flat(ACCENT_DIM, Color(0, 0, 0, 0)))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func label(text: String, size := 18, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	return l


static func button(text: String, cb: Callable, size := 20, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(true))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func() -> void:
		Sfx.play_ui("click")
		cb.call())
	b.mouse_entered.connect(func() -> void: Sfx.play_ui("hover"))
	return b


static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(c: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(c)
	return mc


static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


static func rank_text() -> String:
	var asc := ""
	if Progression.prestige > 0:
		asc = "  ·  %s %d" % [ContentDB.TERMS["prestige"], Progression.prestige]
	return "%s  ·  Rank %d%s" % [ContentDB.rank_name(Progression.rank), Progression.rank, asc]


static func xp_fraction() -> float:
	var r := Progression.rank
	var lo: int = ContentDB.rank_min_xp[r - 1]
	var hi: int = ContentDB.xp_for_next_rank(r)
	return clampf(float(Progression.xp - lo) / maxf(hi - lo, 1), 0.0, 1.0)

class_name OptionsPanel
extends VBoxContainer
## Options controls shared by the main menu and the pause menu.

var _rebinding := ""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(620, 0)
	_section("CONTROLS")
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.02, 0.5, 0.005)
	_slider("ADS sensitivity", "ads_sensitivity_mult", 0.3, 1.5, 0.05)
	_check("Invert look", "invert_y")
	_section("VIDEO")
	_slider("Field of view", "fov", 55.0, 90.0, 1.0)
	_choice("Graphics quality", "quality", ["Low", "Medium", "High", "Ultra"])
	_check("Fullscreen", "fullscreen")
	_check("V-Sync", "vsync")
	_check("Show FPS", "show_fps")
	_section("AUDIO")
	_slider("Master volume", "master_volume", 0.0, 1.0, 0.05)
	_slider("Effects volume", "sfx_volume", 0.0, 1.0, 0.05)
	_slider("Music volume", "music_volume", 0.0, 1.0, 0.05)
	_section("GAME")
	_choice("Bot difficulty", "bot_difficulty", ["Recruit", "Regular", "Hardened", "Veteran"])
	var h := UiKit.hbox()
	h.add_child(_fixed(UiKit.label("Player name", 16, UiKit.MUTED), 220))
	var le := LineEdit.new()
	le.text = str(Settings.get_value("player_name"))
	le.custom_minimum_size.x = 280
	le.max_length = 16
	le.text_submitted.connect(func(t: String) -> void: Settings.set_value("player_name", t.strip_edges() if t.strip_edges() != "" else "Soldier"))
	le.focus_exited.connect(func() -> void: Settings.set_value("player_name", le.text.strip_edges() if le.text.strip_edges() != "" else "Soldier"))
	h.add_child(le)
	add_child(h)
	_section("KEY BINDINGS (click, then press a key)")
	for action: String in Settings.DEFAULT_BINDINGS:
		var row := UiKit.hbox()
		row.add_child(_fixed(UiKit.label(action.replace("_", " ").capitalize(), 15, UiKit.MUTED), 220))
		var b := Button.new()
		b.text = ", ".join(Settings.bindings[action])
		b.custom_minimum_size.x = 280
		b.add_theme_font_size_override("font_size", 15)
		var a := action
		b.pressed.connect(func() -> void:
			_rebinding = a
			b.text = "...")
		row.add_child(b)
		_bind_buttons[action] = b
		add_child(row)


func _input(event: InputEvent) -> void:
	if _rebinding == "":
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index != MOUSE_BUTTON_LEFT):
		var s := Settings.binding_for_event(event)
		if s != "":
			Settings.rebind(_rebinding, s)
			_bind_buttons[_rebinding].text = s
		_rebinding = ""
		get_viewport().set_input_as_handled()


func _fixed(c: Control, w: float) -> Control:
	c.custom_minimum_size.x = w
	return c


func _section(t: String) -> void:
	var l := UiKit.label(t, 15, UiKit.ACCENT, true)
	add_child(l)


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := UiKit.hbox()
	h.add_child(_fixed(UiKit.label(text, 16, UiKit.MUTED), 220))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(280, 24)
	var val := UiKit.label("%.2f" % s.value, 15)
	s.value_changed.connect(func(v: float) -> void:
		val.text = "%.2f" % v
		Settings.set_value(key, v))
	h.add_child(s)
	h.add_child(val)
	add_child(h)


func _check(text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	add_child(c)


func _choice(text: String, key: String, options: Array) -> void:
	var h := UiKit.hbox()
	h.add_child(_fixed(UiKit.label(text, 16, UiKit.MUTED), 220))
	var o := OptionButton.new()
	for opt in options:
		o.add_item(opt)
	o.selected = int(Settings.get_value(key))
	o.custom_minimum_size.x = 280
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, i))
	h.add_child(o)
	add_child(h)

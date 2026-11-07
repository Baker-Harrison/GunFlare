class_name MainMenu
extends Control
## Front end: a cinematic 3D title stage with an attract screen, a large
## animated menu, a player card and the current loadout. Sub-screens (match
## setup, Create-a-Class, Barracks, Options) open on a panel over the stage.

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float time = 0.0;
uniform float left_shade = 1.0;
uniform float fade = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 uv = UV;
	float vig = 1.0 - smoothstep(0.3, 0.95, length((uv - vec2(0.5)) * vec2(1.25, 1.0)));
	vec3 col = vec3(0.0);
	float a = (1.0 - vig) * 0.85;
	// Left gradient behind the menu, top and bottom bands for the bars.
	a = max(a, (1.0 - smoothstep(0.05, 0.5, uv.x)) * 0.8 * left_shade);
	a = max(a, (1.0 - smoothstep(0.0, 0.12, uv.y)) * 0.55);
	a = max(a, smoothstep(0.86, 1.0, uv.y) * 0.8);
	// Film grain and faint scan lines.
	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(time * 61.0, time * 17.0));
	col += vec3(g) * 0.06;
	a += (g - 0.5) * 0.05;
	a += sin(uv.y * 1080.0 * 1.5) * 0.012;
	a = mix(a, 1.0, fade);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
"""

static var _intro_done := false

var _content: Control
var _stage: TitleStage
var _card: VBoxContainer
var _emblem_holder: Control
var _logo: TitleLogo
var _nav: VBoxContainer
var _detail: Label
var _loadout: VBoxContainer
var _footer: Label
var _panel: PanelContainer
var _banner_box: VBoxContainer
var _prompt: Label
var _overlay_mat: ShaderMaterial
var _attract := false
var _t := 0.0
var _on_home := false
var _cfg := {"mode": "tdm", "map": "dustline", "bots": 11, "difficulty": 1, "class": {"source": "preset", "index": 0}}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	theme = UiKit.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cfg["difficulty"] = int(Settings.get_value("bot_difficulty"))
	if not Game.last_config.is_empty():
		_cfg.merge(Game.last_config, true)
	_stage = TitleStage.new()
	add_child(_stage)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = sh
	overlay.material = _overlay_mat
	add_child(overlay)
	_build_chrome()
	if not UpdateService.state_changed.is_connected(_on_update_state):
		UpdateService.state_changed.connect(_on_update_state)
	Sfx.play_music("menu", -8.0)
	if _intro_done or OS.get_cmdline_user_args().has("--skip-intro"):
		_intro_done = true
		_overlay_mat.set_shader_parameter("fade", 1.0)
		create_tween().tween_method(func(v: float) -> void: _overlay_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.6)
		_home()
	else:
		_start_attract()


func _build_chrome() -> void:
	_logo = TitleLogo.new()
	_logo.position = Vector2(92, 64)
	add_child(_logo)
	# Sub-screen panel (hidden on the home screen).
	_panel = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.03, 0.04, 0.04, 0.88)
	ps.border_color = Color(1, 1, 1, 0.07)
	ps.set_border_width_all(1)
	ps.border_width_left = 4
	ps.border_color = Color(UiKit.ACCENT, 0.5)
	ps.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.position = Vector2(64, 214)
	_panel.size = Vector2(1560, 800)
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_content = UiKit.vbox(10)
	scroll.add_child(_content)
	# Home navigation.
	_nav = UiKit.vbox(2)
	_nav.position = Vector2(70, 352)
	add_child(_nav)
	_detail = UiKit.label("", 17, Color(0.85, 0.86, 0.82, 0.85))
	_detail.position = Vector2(100, 720)
	_detail.custom_minimum_size = Vector2(520, 0)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail)
	_banner_box = UiKit.vbox(6)
	_banner_box.position = Vector2(100, 790)
	add_child(_banner_box)
	# Player card, top right.
	var card_row := UiKit.hbox(18)
	card_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card_row.position = Vector2(-560, 58)
	card_row.custom_minimum_size = Vector2(500, 0)
	add_child(card_row)
	_emblem_holder = Control.new()
	_emblem_holder.custom_minimum_size = Vector2(92, 92)
	card_row.add_child(_emblem_holder)
	_card = UiKit.vbox(4)
	_card.custom_minimum_size.x = 390
	card_row.add_child(_card)
	_update_card()
	# Loadout, bottom right.
	_loadout = UiKit.vbox(2)
	_loadout.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loadout.position = Vector2(-560, -250)
	_loadout.custom_minimum_size = Vector2(500, 0)
	add_child(_loadout)
	# Footer.
	_footer = UiKit.label("", 15, Color(0.75, 0.76, 0.72, 0.8), true)
	_footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_footer.position = Vector2(100, -58)
	add_child(_footer)
	var ver := UiKit.label("BUILD " + UpdateService.current_version, 14, Color(UiKit.MUTED, 0.8), true)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.position = Vector2(-260, -58)
	ver.custom_minimum_size.x = 200
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	_prompt = UiKit.label("PRESS ANY KEY", 26, UiKit.TEXT, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.position = Vector2(-300, -230)
	_prompt.visible = false
	add_child(_prompt)


# --- Attract screen ------------------------------------------------------------

func _start_attract() -> void:
	_attract = true
	_set_home_visible(false)
	_card.get_parent().modulate.a = 0.0
	_footer.modulate.a = 0.0
	_prompt.visible = true
	_logo.pivot_offset = Vector2.ZERO
	_logo.scale = Vector2(1.25, 1.25)
	_logo.position = Vector2((size.x - _logo.size.x * 1.25) * 0.5, size.y * 0.5 - 220)
	_logo.modulate.a = 0.0
	_overlay_mat.set_shader_parameter("fade", 1.0)
	_overlay_mat.set_shader_parameter("left_shade", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _overlay_mat.set_shader_parameter("fade", v), 1.0, 0.0, 2.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_logo, "modulate:a", 1.0, 1.6).set_delay(1.0)


func _finish_attract() -> void:
	if not _attract:
		return
	_attract = false
	_intro_done = true
	Sfx.play_ui("click")
	_prompt.visible = false
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.9)
	tw.tween_property(_logo, "position", Vector2(92, 64), 0.9)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.3)
	tw.tween_property(_card.get_parent(), "modulate:a", 1.0, 0.8).set_delay(0.3)
	tw.tween_property(_footer, "modulate:a", 1.0, 0.8).set_delay(0.4)
	tw.tween_method(func(v: float) -> void: _overlay_mat.set_shader_parameter("left_shade", v), 0.0, 1.0, 0.9)
	_home()


func _input(event: InputEvent) -> void:
	if not _attract:
		return
	var pressed := false
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		_finish_attract()


func _process(delta: float) -> void:
	_t += delta
	_overlay_mat.set_shader_parameter("time", _t)
	if _prompt.visible:
		_prompt.modulate.a = 0.45 + 0.55 * absf(sin(_t * 2.2))


func _set_home_visible(on: bool) -> void:
	_nav.visible = on
	_detail.visible = on
	_banner_box.visible = on
	_loadout.visible = on


func _update_card() -> void:
	UiKit.clear(_card)
	for c in _emblem_holder.get_children():
		c.queue_free()
	var emblem := RankEmblem.new(Progression.rank, Progression.prestige, 92.0)
	_emblem_holder.add_child(emblem)
	_card.add_child(UiKit.label(str(Settings.get_value("player_name")).to_upper(), 30, UiKit.TEXT, true))
	_card.add_child(UiKit.label(UiKit.rank_text().to_upper(), 15, UiKit.ACCENT, true))
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = UiKit.xp_fraction()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(390, 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UiKit.ACCENT
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	_card.add_child(bar)
	var nxt := ContentDB.xp_for_next_rank(Progression.rank)
	_card.add_child(UiKit.label("%d / %d XP" % [Progression.xp, nxt], 13, UiKit.MUTED, true))
	var s := Progression.stats
	var kd := float(s.get("kills", 0)) / maxf(float(s.get("deaths", 0)), 1.0)
	var stats := UiKit.hbox(34)
	for pair in [["K/D", "%.2f" % kd], ["WINS", str(s.get("wins", 0))], ["KILLS", str(s.get("kills", 0))]]:
		var col := UiKit.vbox(0)
		col.add_child(UiKit.label(pair[1], 22, UiKit.TEXT, true))
		col.add_child(UiKit.label(pair[0], 12, UiKit.MUTED, true))
		stats.add_child(col)
	_card.add_child(stats)


func _on_update_state() -> void:
	if _on_home:
		_show_update_banner()


func _show_update_banner() -> void:
	UiKit.clear(_banner_box)
	var box = _update_banner()
	if box == null:
		return
	_banner_box.add_child(box)


func _update_banner():
	var lines: PackedStringArray = []
	if UpdateService.install_notice != "":
		lines.append(UpdateService.install_notice)
	if UpdateService.install_error != "":
		lines.append("The last update failed. " + UpdateService.install_error)
	if UpdateService.status == "available":
		lines.append(UpdateService.message)
	elif UpdateService.status == "downloading":
		lines.append(UpdateService.message)
	elif UpdateService.status == "error" and UpdateService.message != "":
		lines.append(UpdateService.message)
	if lines.is_empty():
		return null
	var box := UiKit.vbox(6)
	box.name = "UpdateBanner"
	for line in lines:
		var label := UiKit.label(line, 16, UiKit.ACCENT, true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(420, 0)
		box.add_child(label)
	if UpdateService.status == "downloading":
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = UpdateService.progress
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(420, 12)
		box.add_child(bar)
	elif UpdateService.can_install():
		box.add_child(UiKit.button("INSTALL UPDATE", func() -> void: UpdateService.install(), 22, 420))
	elif UpdateService.status == "error":
		box.add_child(UiKit.button("TRY AGAIN", func() -> void: UpdateService._check(), 22, 420))
	return box


func _selected_class() -> Dictionary:
	var cls: Dictionary = ContentDB.PRESET_CLASSES[0]
	var sel: Dictionary = _cfg.get("class", {})
	if sel.get("source") == "custom" and sel.get("index", 0) < Progression.classes.size():
		cls = Progression.classes[sel["index"]]
	elif sel.get("source") == "preset":
		cls = ContentDB.PRESET_CLASSES[clampi(sel.get("index", 0), 0, ContentDB.PRESET_CLASSES.size() - 1)]
	return cls


func _item_name(id: String) -> String:
	var item := ContentDB.get_item(id)
	return item.display_name if item else id.to_upper()


func _update_loadout(cls: Dictionary) -> void:
	UiKit.clear(_loadout)
	_loadout.add_child(UiKit.label("ACTIVE LOADOUT", 13, UiKit.ACCENT, true))
	_loadout.add_child(UiKit.label(str(cls.get("name", "Class")).to_upper(), 30, UiKit.TEXT, true))
	var atts: Array = cls.get("primary_attachments", [])
	var names: PackedStringArray = []
	for a in atts:
		names.append(_item_name(a))
	var primary := _item_name(cls["primary"]).to_upper()
	if not names.is_empty():
		primary += "   ·   " + " + ".join(names).to_upper()
	_loadout.add_child(UiKit.label(primary, 15, Color(0.85, 0.86, 0.82), true))
	_loadout.add_child(UiKit.label("SECONDARY  " + _item_name(cls.get("secondary", "")).to_upper(), 13, UiKit.MUTED, true))


func _home() -> void:
	_on_home = true
	UiKit.clear(_content)
	_panel.visible = false
	_stage.set_focus(false)
	_set_home_visible(true)
	_footer.text = "[ENTER]  SELECT        [↑ ↓]  NAVIGATE"
	_logo_to(1.0)
	var cls := _selected_class()
	_stage.show_loadout(cls["primary"], cls.get("primary_attachments", []), cls.get("primary_camo", ""))
	_update_loadout(cls)
	_show_update_banner()
	UiKit.clear(_nav)
	var locked := not Progression.is_unlocked("create_a_class")
	var entries := [
		["PLAY", "Choose a mode, a map and the bots. Then deploy into a match.", _play],
		["CREATE-A-CLASS", "Build custom loadouts: weapons, attachments, camos, perks and equipment.", func() -> void: _open(CreateAClass.new())],
		["BARRACKS", "Examine your challenges, titles, emblems and career record.", func() -> void: _open(Barracks.new())],
		["OPTIONS", "Change the controls, the video, the audio and the gameplay settings.", _options],
		["QUIT", "Close GunFare and go back to the desktop.", func() -> void: get_tree().quit()],
	]
	for i in entries.size():
		var e: Array = entries[i]
		var item := TitleMenuItem.new(i + 1, e[0], e[1], e[2])
		if i == 1 and locked:
			item.disabled = true
			item.lock_text = "RANK 4"
			item.detail = "Reach rank 4 to unlock custom classes."
		item.highlighted.connect(func(it: TitleMenuItem) -> void: _detail.text = it.detail)
		_nav.add_child(item)
		item.play_intro(0.15 + i * 0.07)
	(_nav.get_child(0) as Control).grab_focus.call_deferred()
	_detail.text = entries[0][1]


func _logo_to(s: float) -> void:
	if _attract:
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "scale", Vector2(s, s), 0.45)
	tw.tween_property(_logo, "position", Vector2(92, 64 if s >= 1.0 else 40), 0.45)


func _show_panel() -> void:
	_on_home = false
	UiKit.clear(_content)
	_set_home_visible(false)
	_stage.set_focus(true)
	_logo_to(0.62)
	_footer.text = "[ESC]  BACK"
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.position.x = 30
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(_panel, "position:x", 64.0, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if _attract or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not _on_home:
		Progression.save_profile()
		_update_card()
		_home()


func _open(screen: Control) -> void:
	_show_panel()
	_content.add_child(screen)
	if screen.has_signal("closed"):
		screen.closed.connect(func() -> void:
			_update_card()
			_home())


func _options() -> void:
	_show_panel()
	_content.add_child(UiKit.label("OPTIONS", 40, UiKit.TEXT, true))
	_content.add_child(OptionsPanel.new())
	_content.add_child(UiKit.button("BACK", func() -> void:
		_update_card()
		_home(), 22, 300))


func _play() -> void:
	_show_panel()
	_content.add_child(UiKit.label("MATCH SETUP", 40, UiKit.TEXT, true))
	var cols := UiKit.hbox(30)
	_content.add_child(cols)
	# Modes
	var mv := UiKit.vbox(6)
	cols.add_child(mv)
	mv.add_child(UiKit.label("GAME MODE", 15, UiKit.ACCENT, true))
	var mode_group := ButtonGroup.new()
	for m: Dictionary in ModesInfo.MODES:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = mode_group
		b.text = m["name"].to_upper()
		b.tooltip_text = m["desc"]
		b.custom_minimum_size = Vector2(320, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_pressed = _cfg["mode"] == m["id"]
		var id: String = m["id"]
		b.pressed.connect(func() -> void:
			_cfg["mode"] = id
			Sfx.play_ui("click"))
		mv.add_child(b)
	# Maps
	var mapv := UiKit.vbox(6)
	cols.add_child(mapv)
	mapv.add_child(UiKit.label("MAP", 15, UiKit.ACCENT, true))
	var map_group := ButtonGroup.new()
	for m: Dictionary in MapCatalog.MAPS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = map_group
		b.text = m["name"].to_upper()
		b.tooltip_text = m["desc"]
		b.custom_minimum_size = Vector2(320, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_pressed = _cfg["map"] == m["id"]
		var id2: String = m["id"]
		b.pressed.connect(func() -> void:
			_cfg["map"] = id2
			Sfx.play_ui("click"))
		mapv.add_child(b)
	var rb := UiKit.button("RANDOM MAP", func() -> void:
		_cfg["map"] = MapCatalog.MAPS[randi() % MapCatalog.MAPS.size()]["id"]
		_play(), 16, 320)
	mapv.add_child(rb)
	# Settings + class
	var sv := UiKit.vbox(8)
	cols.add_child(sv)
	sv.add_child(UiKit.label("BOTS", 15, UiKit.ACCENT, true))
	var bots_label := UiKit.label("%d bots" % _cfg["bots"], 18)
	var bs := HSlider.new()
	bs.min_value = 1
	bs.max_value = 17
	bs.step = 1
	bs.value = _cfg["bots"]
	bs.custom_minimum_size = Vector2(320, 24)
	bs.value_changed.connect(func(v: float) -> void:
		_cfg["bots"] = int(v)
		bots_label.text = "%d bots" % int(v))
	sv.add_child(bs)
	sv.add_child(bots_label)
	var diff := OptionButton.new()
	for d in ["Recruit", "Regular", "Hardened", "Veteran"]:
		diff.add_item(d)
	diff.selected = _cfg["difficulty"]
	diff.item_selected.connect(func(i: int) -> void:
		_cfg["difficulty"] = i
		Settings.set_value("bot_difficulty", i))
	sv.add_child(UiKit.label("DIFFICULTY", 15, UiKit.ACCENT, true))
	sv.add_child(diff)
	sv.add_child(UiKit.label("CLASS", 15, UiKit.ACCENT, true))
	var cls := OptionButton.new()
	var options: Array = []
	for i in Progression.custom_class_slots():
		var c: Dictionary = Progression.classes[i]
		if Progression.validate_loadout(c).is_empty():
			options.append({"source": "custom", "index": i, "name": c.get("name", "Custom %d" % (i + 1))})
	for i in ContentDB.PRESET_CLASSES.size():
		options.append({"source": "preset", "index": i, "name": ContentDB.PRESET_CLASSES[i]["name"] + " (default)"})
	for i in options.size():
		cls.add_item(options[i]["name"])
		if options[i]["source"] == _cfg["class"].get("source") and options[i]["index"] == _cfg["class"].get("index"):
			cls.selected = i
	cls.item_selected.connect(func(i: int) -> void: _cfg["class"] = {"source": options[i]["source"], "index": options[i]["index"]})
	if cls.selected < 0 and not options.is_empty():
		cls.selected = 0
		_cfg["class"] = {"source": options[0]["source"], "index": options[0]["index"]}
	sv.add_child(cls)
	var start := UiKit.button("START MATCH", func() -> void: Game.start_match(_cfg.duplicate(true)), 28, 320)
	start.add_theme_color_override("font_color", UiKit.ACCENT)
	sv.add_child(start)
	_content.add_child(UiKit.button("BACK", _home, 20, 300))

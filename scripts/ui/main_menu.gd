class_name MainMenu
extends Control
## Front end: Play (match setup), Create-a-Class, Barracks, Options.

var _content: Control
var _showcase: WeaponShowcase
var _card: VBoxContainer
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
	add_child(MenuBackdrop.new())
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := UiKit.label("GUNFARE", 92, UiKit.TEXT, true)
	title.position = Vector2(80, 50)
	add_child(title)
	var sub := UiKit.label("MULTIPLAYER  ·  OFFLINE WITH BOTS", 18, UiKit.ACCENT, true)
	sub.position = Vector2(86, 160)
	add_child(sub)
	var ver := UiKit.label("VERSION " + UpdateService.current_version, 14, UiKit.MUTED, true)
	ver.position = Vector2(86, 186)
	add_child(ver)
	_card = UiKit.vbox(4)
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.position = Vector2(-520, 60)
	_card.custom_minimum_size.x = 440
	add_child(_card)
	_update_card()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 220)
	scroll.size = Vector2(1500, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_content = UiKit.vbox(10)
	scroll.add_child(_content)
	_showcase = WeaponShowcase.new()
	_showcase.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_showcase.position = Vector2(-980, -240)
	_showcase.size = Vector2(900, 520)
	add_child(_showcase)
	if not UpdateService.state_changed.is_connected(_on_update_state):
		UpdateService.state_changed.connect(_on_update_state)
	_home()
	Sfx.play_music("menu", -8.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and has_node("ScrollContainer"):
		pass


func _update_card() -> void:
	UiKit.clear(_card)
	_card.add_child(UiKit.label(str(Settings.get_value("player_name")).to_upper(), 28, UiKit.TEXT, true))
	_card.add_child(UiKit.label(UiKit.rank_text(), 18, UiKit.ACCENT))
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = UiKit.xp_fraction()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(420, 10)
	_card.add_child(bar)
	var nxt := ContentDB.xp_for_next_rank(Progression.rank)
	_card.add_child(UiKit.label("%d / %d XP" % [Progression.xp, nxt], 14, UiKit.MUTED))
	var s := Progression.stats
	var kd := float(s.get("kills", 0)) / maxf(float(s.get("deaths", 0)), 1.0)
	_card.add_child(UiKit.label("K/D %.2f   ·   Wins %d   ·   Kills %d" % [kd, s.get("wins", 0), s.get("kills", 0)], 14, UiKit.MUTED))


func _on_update_state() -> void:
	if _on_home:
		_show_update_banner()


func _show_update_banner() -> void:
	var old := _content.get_node_or_null("UpdateBanner")
	if old:
		old.free()
	var box = _update_banner()
	if box == null:
		return
	_content.add_child(box)
	_content.move_child(box, 0)


func _update_banner():
	var lines: PackedStringArray = []
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


func _home() -> void:
	_on_home = true
	UiKit.clear(_content)
	_showcase.visible = true
	var cls: Dictionary = ContentDB.PRESET_CLASSES[0]
	var sel: Dictionary = _cfg.get("class", {})
	if sel.get("source") == "custom" and sel.get("index", 0) < Progression.classes.size():
		cls = Progression.classes[sel["index"]]
	elif sel.get("source") == "preset":
		cls = ContentDB.PRESET_CLASSES[clampi(sel.get("index", 0), 0, ContentDB.PRESET_CLASSES.size() - 1)]
	_showcase.show_weapon(cls["primary"], cls.get("primary_attachments", []), cls.get("primary_camo", ""))
	_show_update_banner()
	_content.add_child(UiKit.button("PLAY", _play, 30, 420))
	_content.add_child(UiKit.button("CREATE-A-CLASS", func() -> void: _open(CreateAClass.new()), 30, 420))
	_content.add_child(UiKit.button("BARRACKS", func() -> void: _open(Barracks.new()), 30, 420))
	_content.add_child(UiKit.button("OPTIONS", _options, 30, 420))
	_content.add_child(UiKit.button("QUIT", func() -> void: get_tree().quit(), 30, 420))
	var locked := not Progression.is_unlocked("create_a_class")
	if locked:
		_content.get_child(1).disabled = true
		_content.get_child(1).text = "CREATE-A-CLASS  (RANK 4)"


func _open(screen: Control) -> void:
	_on_home = false
	UiKit.clear(_content)
	_showcase.visible = false
	_content.add_child(screen)
	if screen.has_signal("closed"):
		screen.closed.connect(func() -> void:
			_update_card()
			_home())


func _options() -> void:
	_on_home = false
	UiKit.clear(_content)
	_showcase.visible = false
	_content.add_child(UiKit.label("OPTIONS", 40, UiKit.TEXT, true))
	_content.add_child(OptionsPanel.new())
	_content.add_child(UiKit.button("BACK", func() -> void:
		_update_card()
		_home(), 22, 300))


func _play() -> void:
	_on_home = false
	UiKit.clear(_content)
	_showcase.visible = false
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

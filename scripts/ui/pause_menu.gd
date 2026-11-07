class_name PauseMenu
extends CanvasLayer
## In-match pause: resume, change class, quick options, leave.

var match_ref: Match
var _root: Control
var _content: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_content = UiKit.vbox(10)
	_content.position = Vector2(90, 160)
	_root.add_child(_content)
	_main()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _main() -> void:
	UiKit.clear(_content)
	_content.add_child(UiKit.label("PAUSED", 48, UiKit.TEXT, true))
	_content.add_child(UiKit.button("RESUME", close, 24, 360))
	_content.add_child(UiKit.button("CHANGE CLASS", _classes, 24, 360))
	_content.add_child(UiKit.button("OPTIONS", _options, 24, 360))
	_content.add_child(UiKit.button("LEAVE MATCH", func() -> void: match_ref.leave(), 24, 360))


func _classes() -> void:
	UiKit.clear(_content)
	_content.add_child(UiKit.label("CHOOSE CLASS", 36, UiKit.TEXT, true))
	if Progression.custom_class_slots() > 0:
		for i in Progression.custom_class_slots():
			var c: Dictionary = Progression.classes[i]
			var idx := i
			var b := UiKit.button(c.get("name", "Custom %d" % (i + 1)).to_upper(), func() -> void:
				match_ref.choose_class({"source": "custom", "index": idx})
				close(), 20, 420)
			b.disabled = not Progression.validate_loadout(c).is_empty()
			_content.add_child(b)
	for i in ContentDB.PRESET_CLASSES.size():
		var idx2 := i
		_content.add_child(UiKit.button(ContentDB.PRESET_CLASSES[i]["name"].to_upper() + "  (default)", func() -> void:
			match_ref.choose_class({"source": "preset", "index": idx2})
			close(), 20, 420))
	_content.add_child(UiKit.button("BACK", _main, 20, 420))


func _options() -> void:
	UiKit.clear(_content)
	_content.add_child(UiKit.label("OPTIONS", 36, UiKit.TEXT, true))
	_content.add_child(OptionsPanel.new())
	_content.add_child(UiKit.button("BACK", _main, 20, 420))


func close() -> void:
	get_tree().paused = false
	if match_ref and not match_ref.ended:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()

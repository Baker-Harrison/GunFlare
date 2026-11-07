extends Node
## Player options and input bindings. Saved to user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

## action -> default bindings. Strings are key names, "mouse_N" mouse buttons.
const DEFAULT_BINDINGS := {
	"move_forward": ["W"],
	"move_back": ["S"],
	"move_left": ["A"],
	"move_right": ["D"],
	"jump": ["Space"],
	"sprint": ["Shift"],
	"crouch": ["C", "Ctrl"],
	"prone": ["Z"],
	"fire": ["mouse_1"],
	"ads": ["mouse_2"],
	"reload": ["R"],
	"swap_weapon": ["1", "mouse_4", "mouse_5"],
	"melee": ["V", "mouse_3"],
	"lethal": ["G"],
	"tactical": ["Q"],
	"interact": ["F"],
	"use_streak": ["4"],
	"cycle_streak": ["5"],
	"toggle_attachment": ["B"],
	"scoreboard": ["Tab"],
	"pause": ["Escape"],
}

var values := {
	"mouse_sensitivity": 0.12, # degrees per pixel
	"ads_sensitivity_mult": 0.8,
	"invert_y": false,
	"fov": 70.0, # vertical degrees
	"master_volume": 0.8,
	"sfx_volume": 1.0,
	"music_volume": 0.5,
	"quality": 2, # 0 low, 1 medium, 2 high, 3 ultra
	"show_fps": false,
	"fullscreen": true,
	"vsync": true,
	"bot_difficulty": 1, # 0 recruit, 1 regular, 2 hardened, 3 veteran
	"player_name": "Soldier",
}
var bindings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bindings = DEFAULT_BINDINGS.duplicate(true)
	_load()
	apply_bindings()
	apply()


func get_value(key: String):
	return values.get(key)


func set_value(key: String, value) -> void:
	values[key] = value
	apply()
	save()
	changed.emit()


func apply() -> void:
	for bus_name in ["Master", "SFX", "Music"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var key: String = {"Master": "master_volume", "SFX": "sfx_volume", "Music": "music_volume"}[bus_name]
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(values[key]), 0.0001)))
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--shots"):
		var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)


func apply_bindings() -> void:
	for action: String in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for b: String in bindings[action]:
			var ev := _event_for(b)
			if ev:
				InputMap.action_add_event(action, ev)


func rebind(action: String, binding: String) -> void:
	bindings[action] = [binding]
	apply_bindings()
	save()
	changed.emit()


static func _event_for(binding: String) -> InputEvent:
	if binding.begins_with("mouse_"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(binding.substr(6)) as MouseButton
		return mb
	var code := OS.find_keycode_from_string(binding)
	if code == KEY_NONE:
		push_warning("Unknown key binding: " + binding)
		return null
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k


static func binding_for_event(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		return "mouse_%d" % ev.button_index
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode)
	return ""


func save() -> void:
	var cfg := ConfigFile.new()
	for k: String in values:
		cfg.set_value("options", k, values[k])
	for a: String in bindings:
		cfg.set_value("bindings", a, bindings[a])
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k: String in values:
		values[k] = cfg.get_value("options", k, values[k])
	for a: String in bindings:
		var b = cfg.get_value("bindings", a, bindings[a])
		if b is Array and not b.is_empty():
			bindings[a] = b

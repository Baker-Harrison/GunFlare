extends Node
## Scene flow: main menu <-> matches.

var last_config: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Command line: --match <map> <mode> for quick testing.
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--match":
		var cfg := {"map": args[1] if args.size() > 1 else "dustline", "mode": args[2] if args.size() > 2 else "tdm", "bots": 11}
		start_match.call_deferred(cfg)


func start_match(config: Dictionary) -> void:
	last_config = config.duplicate(true)
	get_tree().paused = false
	var m := Match.new()
	m.name = "Match"
	m.config = config
	get_tree().change_scene_to_node(m)


func return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var menu := MainMenu.new()
	menu.name = "MainMenu"
	get_tree().change_scene_to_node(menu)

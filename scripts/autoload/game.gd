extends Node
## Scene flow: main menu <-> matches.

var last_config: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Command line: --match <map> <mode> for quick testing.
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--match":
		var cfg := {"map": args[1] if args.size() > 1 else "dustline", "mode": args[2] if args.size() > 2 else "tdm", "bots": 11}
		if args.has("--autoplay"):
			cfg["autoplay"] = true
		start_match.call_deferred(cfg)
		var shot := args.find("--shots")
		if shot >= 0:
			_capture_shots.call_deferred(args[shot + 1], int(args[shot + 2]) if args.size() > shot + 2 else 4)
	elif args.has("--shots"):
		var i := args.find("--shots")
		_capture_shots.call_deferred(args[i + 1], 1)


## Dev tool: saves a few screenshots during a match, then quits.
func _capture_shots(dir: String, count: int) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(6.0).timeout
	for i in count:
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("shot_%d.png" % i))
		print("[shots] saved ", i)
	get_tree().quit()


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

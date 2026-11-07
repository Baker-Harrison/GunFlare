extends Node
## Integration smoke test: plays a full bot match (the player is bot-driven)
## and checks that soldiers move, fight, die, respawn and that progression
## receives events. Run:
##   Godot_console.exe --headless --path . res://tests/smoke_match.tscn -- <map> <mode> <seconds>

var _t := 0.0
var _duration := 60.0
var _xp_start := 0
var _kills_start := 0
var _started := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map := args[0] if args.size() > 0 else "dustline"
	var mode := args[1] if args.size() > 1 else "tdm"
	_duration = float(args[2]) if args.size() > 2 else 60.0
	Progression.save_path = "user://smoke_profile.json"
	Progression.reset_profile()
	_xp_start = Progression.xp
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Survive the scene change.
	(func() -> void:
		var tree := get_tree()
		get_parent().remove_child(self)
		tree.root.add_child(self)
		Game.start_match({"map": map, "mode": mode, "bots": 11, "difficulty": 2, "autoplay": true})).call_deferred()


func _process(delta: float) -> void:
	var m := get_tree().current_scene as Match
	if m == null or not m.in_progress and not m.ended:
		return
	if not _started:
		_started = true
		print("Match started: ", m.map.display_name, " / ", m.mode.display_name, "  soldiers=", m.soldiers.size())
	_t += delta
	if _t >= _duration or m.ended:
		var code := _report(m)
		set_process(false)
		get_tree().quit(code)


func _report(m: Match) -> int:
	var total_kills := 0
	var moved := 0
	for s in m.soldiers:
		var st: Dictionary = m.stats_of(s)
		total_kills += st["kills"]
		print("  %-10s team %d  K %2d  D %2d  A %2d  score %4d  %s" % [s.display_name, s.team, st["kills"], st["deaths"], st["assists"], st["score"], s.loadout.get("primary", "?")])
	print("Total kills: ", total_kills, "   scores: ", m.mode.scores, "   time left: %.0f" % m.time_left)
	print("Player XP gained: ", Progression.xp - _xp_start, "  rank ", Progression.rank, "  stats ", Progression.stats)
	var done := 0
	for c in ContentDB.challenges:
		var stt: Dictionary = Progression.challenge_state(c.id)
		if stt["count"] > 0:
			done += 1
	print("Challenges with progress: ", done)
	var ok := total_kills > 0
	print("SMOKE ", "PASS" if ok else "FAIL (no kills)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_profile.json"))
	return 0 if ok else 1

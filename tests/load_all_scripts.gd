extends SceneTree
## Loads every GDScript file in the project. A parse error in any script makes
## the run fail, also for a script that no test opens.
## Run: godot --headless --path . --script res://tests/load_all_scripts.gd


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://scripts", paths)
	_collect("res://tests", paths)
	var failed := 0
	for path in paths:
		if path == (get_script() as Script).resource_path:
			continue
		var script := ResourceLoader.load(path) as GDScript
		if script == null or not script.can_instantiate():
			printerr("SCRIPT LOAD FAILED: ", path)
			failed += 1
	print("%d scripts loaded, %d failed" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)

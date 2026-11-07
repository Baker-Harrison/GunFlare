class_name TdmMode
extends GameMode


func _init() -> void:
	id = "tdm"
	display_name = "Team Deathmatch"
	short_name = "TDM"
	score_limit = 75
	time_limit = 600.0


func bot_goal(s: Soldier) -> Variant:
	# Drift toward where the enemy team was last seen, else a random hotspot.
	var m := match_ref
	var enemies: Array = []
	for o: Soldier in m.soldiers:
		if o.alive and o.team != s.team:
			enemies.append(o.global_position)
	if not enemies.is_empty() and randf() < 0.55:
		var p: Vector3 = enemies[randi() % enemies.size()]
		return p + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	return m.map.random_hotspot()

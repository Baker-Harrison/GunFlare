class_name KillConfirmedMode
extends GameMode
## Kills drop tags. Grab enemy tags to score; grab your team's to deny.

var tags: Array = [] # [{node, team(victim), pos, t}]


func _init() -> void:
	id = "kc"
	display_name = "Kill Confirmed"
	short_name = "KC"
	score_limit = 65
	time_limit = 600.0


func on_kill(killer: Soldier, victim: Soldier, _info: DamageInfo) -> int:
	if victim:
		var tag := TagPickup.new()
		tag.victim_team = victim.team
		match_ref.add_child(tag)
		tag.global_position = victim.global_position + Vector3.UP * 0.6
		tags.append({"node": tag, "team": victim.team, "pos": tag.global_position, "t": 0.0})
	return 50


func update(delta: float) -> void:
	for t: Dictionary in tags.duplicate():
		t["t"] += delta
		var node: Node3D = t["node"]
		if t["t"] > 45.0:
			node.queue_free()
			tags.erase(t)
			continue
		for s: Soldier in match_ref.soldiers:
			if not s.alive or s.global_position.distance_to(t["pos"]) > 1.4:
				continue
			if s.team != t["team"]:
				add_team_score(s.team, 1)
				match_ref.add_personal_score(s, 50)
				if s.is_player:
					GameEvents.report("bonus", {"bonus": "tag_confirm"})
					match_ref.hud_popup("KILL CONFIRMED", Color(0.5, 1, 0.5))
			else:
				match_ref.add_personal_score(s, 50)
				if s.is_player:
					GameEvents.report("bonus", {"bonus": "tag_deny"})
					match_ref.hud_popup("KILL DENIED", Color(0.5, 0.85, 1))
			Sfx.play_3d("tag_pickup", t["pos"], -2.0)
			node.queue_free()
			tags.erase(t)
			break


func bot_goal(s: Soldier) -> Variant:
	var best = null
	var best_d := 35.0
	for t: Dictionary in tags:
		var d: float = s.global_position.distance_to(t["pos"])
		if d < best_d:
			best_d = d
			best = t["pos"]
	if best != null:
		return best
	return match_ref.map.random_hotspot()


func hud_objectives(_viewer: Soldier) -> Array:
	var out: Array = []
	for t: Dictionary in tags:
		var mine: bool = t["team"] == _viewer.team
		out.append({"label": "◆", "pos": t["pos"], "color": Color(0.4, 0.85, 1.0) if mine else Color(1.0, 0.8, 0.3)})
	return out

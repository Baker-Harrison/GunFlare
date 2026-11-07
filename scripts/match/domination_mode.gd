class_name DominationMode
extends GameMode
## Three flags. Stand in a flag's ring to capture it; every held flag scores
## a point every few seconds.

const CAPTURE_RADIUS := 4.5
const CAPTURE_TIME := 10.0
const SCORE_INTERVAL := 5.0

var flags: Array = [] # [{label, pos, owner, progress, node}]
var _score_t := 0.0


func _init() -> void:
	id = "dom"
	display_name = "Domination"
	short_name = "DOM"
	score_limit = 200
	time_limit = 900.0
	respawn_delay = 4.0


func setup(m: Node) -> void:
	super.setup(m)
	for label: String in m.map.flags:
		var pos: Vector3 = m.map.flags[label]
		var node := ObjectiveMarker.new()
		node.label = label
		m.add_child(node)
		node.global_position = pos
		flags.append({"label": label, "pos": pos, "owner": -1, "progress": 0.0, "capturing": -1, "node": node})
	# Teams start owning their home flag, as in the classic mode.
	if flags.size() == 3:
		flags[0]["owner"] = 0
		flags[2]["owner"] = 1
	for f in flags:
		f["node"].set_owner_team(f["owner"])


func update(delta: float) -> void:
	for f: Dictionary in flags:
		var counts := [0, 0]
		var cappers: Array = []
		for s: Soldier in match_ref.soldiers:
			if s.alive and s.global_position.distance_to(f["pos"]) < CAPTURE_RADIUS and absf(s.global_position.y - f["pos"].y) < 3.0:
				counts[s.team] += 1
				cappers.append(s)
		var contested: bool = counts[0] > 0 and counts[1] > 0
		var team := -1
		if counts[0] > 0 and counts[1] == 0:
			team = 0
		elif counts[1] > 0 and counts[0] == 0:
			team = 1
		f["capturing"] = team if not contested else -2
		if team >= 0 and team != f["owner"]:
			var rate := minf(counts[team], 3) / CAPTURE_TIME
			# Neutralise first, then capture.
			var dir := 1.0 if team == 0 else -1.0
			f["progress"] = clampf(f["progress"] + dir * rate * delta * (2.0 if f["owner"] >= 0 else 1.0), -1.0, 1.0)
			if (team == 0 and f["progress"] >= 1.0) or (team == 1 and f["progress"] <= -1.0):
				_capture(f, team, cappers)
		elif team < 0 and not contested and f["owner"] >= 0:
			# Drift back to the owner.
			var target := 1.0 if f["owner"] == 0 else -1.0
			f["progress"] = move_toward(f["progress"], target, delta * 0.2)
		f["node"].set_progress(f["progress"], f["capturing"])
	_score_t += delta
	if _score_t >= SCORE_INTERVAL:
		_score_t = 0.0
		for t in 2:
			var held := 0
			for f: Dictionary in flags:
				if f["owner"] == t:
					held += 1
			if held > 0:
				add_team_score(t, held)


func _capture(f: Dictionary, team: int, cappers: Array) -> void:
	f["owner"] = team
	f["progress"] = 1.0 if team == 0 else -1.0
	f["node"].set_owner_team(team)
	match_ref.announce_capture(f["label"], team, cappers)


func on_kill(killer: Soldier, victim: Soldier, _info: DamageInfo) -> int:
	# Bonus for kills on or near a flag.
	var pts := 50
	if killer and victim:
		for f: Dictionary in flags:
			if victim.global_position.distance_to(f["pos"]) < CAPTURE_RADIUS * 2.0:
				pts += 50
				if killer.is_player:
					GameEvents.report("bonus", {"bonus": "defender" if f["owner"] == killer.team else "attacker"})
				break
	return pts


func hud_objectives(viewer: Soldier) -> Array:
	var out: Array = []
	for f: Dictionary in flags:
		var col := Color(0.9, 0.9, 0.9)
		if f["owner"] == viewer.team:
			col = Color(0.4, 0.85, 1.0)
		elif f["owner"] >= 0:
			col = Color(1.0, 0.35, 0.3)
		out.append({"label": f["label"], "pos": f["pos"], "color": col})
	return out


func bot_goal(s: Soldier) -> Variant:
	# Go for the nearest flag we don't own, sometimes defend.
	var best = null
	var best_d := INF
	for f: Dictionary in flags:
		var d: float = s.global_position.distance_to(f["pos"])
		if f["owner"] != s.team:
			d *= 0.6
		elif randf() < 0.75:
			continue
		if d < best_d:
			best_d = d
			best = f["pos"]
	if best == null:
		return null
	return best + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))


func spawn_bias(s: Soldier, p: Vector3) -> float:
	# Prefer spawns near flags we own.
	var bias := 0.0
	for f: Dictionary in flags:
		if f["owner"] == s.team:
			bias -= clampf(40.0 - p.distance_to(f["pos"]), 0.0, 40.0) * 0.3
	return bias

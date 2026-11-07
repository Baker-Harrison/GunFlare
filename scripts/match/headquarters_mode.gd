class_name HeadquartersMode
extends GameMode
## One HQ zone at a time. Capture it, then hold it: the owners score every
## second and cannot respawn until it falls or times out.

const CAPTURE_TIME := 10.0
const HOLD_TIME := 60.0
const RADIUS := 5.0

var points: Array = []
var current := -1
var owner_team := -1
var progress := 0.0
var hold_t := 0.0
var idle_t := 0.0
var marker: ObjectiveMarker
var _score_t := 0.0


func _init() -> void:
	id = "hq"
	display_name = "Headquarters"
	short_name = "HQ"
	score_limit = 250
	time_limit = 900.0
	respawn_delay = 5.0


func setup(m: Node) -> void:
	super.setup(m)
	points = m.map.hq_points.duplicate()
	if points.is_empty():
		for k in m.map.flags:
			points.append(m.map.flags[k])
	marker = ObjectiveMarker.new()
	marker.label = "HQ"
	marker.radius = RADIUS
	m.add_child(marker)
	_next_point()


func _next_point() -> void:
	var prev := current
	current = randi() % points.size()
	if points.size() > 1 and current == prev:
		current = (current + 1) % points.size()
	owner_team = -1
	progress = 0.0
	hold_t = 0.0
	idle_t = 0.0
	marker.global_position = points[current]
	marker.set_owner_team(-1)
	match_ref.hud_banner("HQ ONLINE", "A new headquarters has been established", Color(1, 0.85, 0.3))


func pos() -> Vector3:
	return points[current]


func update(delta: float) -> void:
	var counts := [0, 0]
	for s: Soldier in match_ref.soldiers:
		if s.alive and s.global_position.distance_to(pos()) < RADIUS:
			counts[s.team] += 1
	if owner_team < 0:
		idle_t += delta
		var team := -1
		if counts[0] > 0 and counts[1] == 0:
			team = 0
		elif counts[1] > 0 and counts[0] == 0:
			team = 1
		if team >= 0:
			progress += minf(counts[team], 3) / CAPTURE_TIME * delta
			if progress >= 1.0:
				owner_team = team
				hold_t = HOLD_TIME
				marker.set_owner_team(team)
				var cappers: Array = []
				for s: Soldier in match_ref.soldiers:
					if s.alive and s.team == team and s.global_position.distance_to(pos()) < RADIUS:
						cappers.append(s)
				match_ref.announce_capture("HQ", team, cappers)
		else:
			progress = move_toward(progress, 0.0, delta * 0.05)
		marker.set_progress(progress, team)
	else:
		hold_t -= delta
		_score_t += delta
		if _score_t >= 1.0:
			_score_t = 0.0
			add_team_score(owner_team, 1)
		# Attackers destroy it by standing in it uncontested.
		var attackers: int = counts[1 - owner_team]
		if attackers > 0 and counts[owner_team] == 0:
			progress -= delta / CAPTURE_TIME * minf(attackers, 3)
			if progress <= 0.0:
				match_ref.hud_banner("HQ DESTROYED", "", Color(1, 0.4, 0.3))
				_next_point()
				return
		if hold_t <= 0.0:
			_next_point()


func can_respawn(s: Soldier) -> bool:
	return owner_team != s.team


func hud_objectives(viewer: Soldier) -> Array:
	var col := Color(0.95, 0.95, 0.95)
	if owner_team == viewer.team:
		col = Color(0.4, 0.85, 1.0)
	elif owner_team >= 0:
		col = Color(1.0, 0.35, 0.3)
	return [{"label": "HQ", "pos": pos(), "color": col}]


func bot_goal(s: Soldier) -> Variant:
	return pos() + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))

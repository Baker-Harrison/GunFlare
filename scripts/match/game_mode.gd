class_name GameMode
extends RefCounted
## Base class for match rules.

var match_ref: Node
var id := "tdm"
var display_name := "Team Deathmatch"
var short_name := "TDM"
var description := ""
var team_based := true
var score_limit := 75
var time_limit := 600.0
var respawn_delay := 3.5
var scores := [0, 0]


static func create(mode_id: String) -> GameMode:
	match mode_id:
		"ffa":
			return FfaMode.new()
		"dom":
			return DominationMode.new()
		"kc":
			return KillConfirmedMode.new()
		"hq":
			return HeadquartersMode.new()
	return TdmMode.new()


func setup(m: Node) -> void:
	match_ref = m


func update(_delta: float) -> void:
	pass


## Called for every kill. Return points awarded to the killer's personal score.
func on_kill(killer: Soldier, victim: Soldier, _info: DamageInfo) -> int:
	if killer and killer != victim and team_based:
		add_team_score(killer.team, 1)
	return 100


func add_team_score(team: int, amount: int) -> void:
	if team < 0 or team >= scores.size():
		return
	scores[team] += amount
	if scores[team] >= score_limit:
		scores[team] = score_limit
		match_ref.end_match()


func leader_team() -> int:
	if scores[0] == scores[1]:
		return -1
	return 0 if scores[0] > scores[1] else 1


## Did this soldier's side win?
func did_win(s: Soldier) -> bool:
	return leader_team() == s.team


func hud_objectives(_viewer: Soldier) -> Array:
	return []


## Where a bot should head when it has nothing better to do.
func bot_goal(s: Soldier) -> Variant:
	return null


func spawn_bias(_s: Soldier, _p: Vector3) -> float:
	return 0.0

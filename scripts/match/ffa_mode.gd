class_name FfaMode
extends GameMode


func _init() -> void:
	id = "ffa"
	display_name = "Free-for-All"
	short_name = "FFA"
	team_based = false
	score_limit = 30
	time_limit = 600.0
	respawn_delay = 2.5


func on_kill(killer: Soldier, victim: Soldier, _info: DamageInfo) -> int:
	if killer and killer != victim:
		var k: int = match_ref.stats_of(killer)["kills"] + 1
		if k >= score_limit:
			match_ref.end_match.call_deferred()
	return 50


func leader() -> Soldier:
	var best: Soldier = null
	var best_k := -1
	for s: Soldier in match_ref.soldiers:
		var k: int = match_ref.stats_of(s)["kills"]
		if k > best_k:
			best_k = k
			best = s
	return best


func did_win(s: Soldier) -> bool:
	# Top three count as a win, like the classic playlists.
	var sorted: Array = match_ref.soldiers.duplicate()
	sorted.sort_custom(func(a: Soldier, b: Soldier) -> bool: return match_ref.stats_of(a)["kills"] > match_ref.stats_of(b)["kills"])
	return sorted.find(s) < 3


func bot_goal(_s: Soldier) -> Variant:
	return match_ref.map.random_hotspot()

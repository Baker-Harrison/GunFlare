extends Node
## Global event bus. Gameplay (players and bots) reports what happened;
## Progression and ChallengeTracker listen. Bots and, later, networked
## players report the same events, so progression never needs to change.
##
## Events and their payload keys:
##   "kill"            weapon, headshot, perks (Array), attachment_count,
##                     distance, explosive, melee, downed, streak (id if a
##                     streak reward got the kill, else "")
##   "assist"          weapon
##   "death"           (none required)
##   "bonus"           bonus (id from ContentDB.BONUSES)
##   "streak_earned"   streak, perks
##   "streak_used"     streak
##   "streak_destroyed" streak, perks   (you shot down an enemy streak reward)
##   "equipment_destroyed" perks
##   "match_end"       won (bool), minutes (float)

signal reported(event_name: String, info: Dictionary)


func report(event_name: String, info: Dictionary = {}) -> void:
	reported.emit(event_name, info)

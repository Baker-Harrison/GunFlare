extends Node
## Counts game events toward challenges and pays out tiers.
## Progress itself lives in Progression so it saves with the profile.

signal challenge_progressed(challenge: ChallengeData, count: int)
signal tier_completed(challenge: ChallengeData, tier_index: int)

var _by_event: Dictionary = {} # event name -> Array[ChallengeData]


func _ready() -> void:
	for c in ContentDB.challenges:
		if not _by_event.has(c.event):
			_by_event[c.event] = []
		_by_event[c.event].append(c)
	GameEvents.reported.connect(_on_event)


func _on_event(event_name: String, info: Dictionary) -> void:
	for c: ChallengeData in _by_event.get(event_name, []):
		if matches(c.conditions, info):
			var amount := 1 if c.amount_key == "" else int(info.get(c.amount_key, 0))
			advance(c, amount)


func advance(c: ChallengeData, amount: int) -> void:
	var state := Progression.challenge_state(c.id)
	if amount <= 0 or state["tier"] >= c.tiers.size():
		return
	state["count"] += amount
	challenge_progressed.emit(c, state["count"])
	while state["tier"] < c.tiers.size() and state["count"] >= int(c.tiers[state["tier"]]["target"]):
		var tier: Dictionary = c.tiers[state["tier"]]
		state["tier"] += 1
		for reward: Dictionary in tier.get("rewards", []):
			Progression.grant_reward(reward)
		Progression.award_xp(int(tier.get("xp", 0)), c.display_name)
		tier_completed.emit(c, state["tier"] - 1)


## Condition rules, checked against the event payload:
##   "key": value       payload[key] == value, or contains value if it's an Array
##   "key_min": number  payload[key] >= number
##   "key_max": number  payload[key] <= number
static func matches(conditions: Dictionary, info: Dictionary) -> bool:
	for key: String in conditions:
		var want = conditions[key]
		if key.ends_with("_min"):
			if float(info.get(key.trim_suffix("_min"), -INF)) < float(want):
				return false
		elif key.ends_with("_max"):
			if float(info.get(key.trim_suffix("_max"), INF)) > float(want):
				return false
		else:
			var have = info.get(key)
			if have is Array:
				if not have.has(want):
					return false
			elif typeof(have) != typeof(want) or have != want:
				return false
	return true

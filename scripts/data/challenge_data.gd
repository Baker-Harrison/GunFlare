class_name ChallengeData
extends Resource
## A tiered challenge. Each matching game event adds to a counter; each tier
## pays XP and rewards when the counter reaches its target.

@export var id: String = ""
@export var display_name: String = ""
## {target} is replaced with the current tier's target.
@export var description: String = ""
## weapon, perk, streak, feat, lifetime
@export var category: String = ""
## Game event that counts (see GameEvents).
@export var event: String = "kill"
## Conditions on the event payload (see ChallengeTracker.matches).
@export var conditions: Dictionary = {}
## Payload key to add instead of 1 per event. Empty = count events.
@export var amount_key: String = ""
## [{ "target": int, "xp": int, "rewards": [reward dicts] }], targets ascending.
## Reward dicts: {type: attachment|camo, weapon, id} / {type: elite, id} /
## {type: title, id} / {type: emblem, id}
@export var tiers: Array = []
## Lifetime challenges keep their progress through Ascension.
@export var lifetime: bool = false


func describe(tier_index: int) -> String:
	if tiers.is_empty():
		return description
	var t: Dictionary = tiers[clampi(tier_index, 0, tiers.size() - 1)]
	return description.replace("{target}", str(t["target"]))

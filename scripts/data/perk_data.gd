class_name PerkData
extends UnlockableData
## A perk in one of three slots. Completing its challenge upgrades it to Elite.

@export_range(1, 3) var slot: int = 1
@export_multiline var elite_description: String = ""

@export_group("Elite challenge")
## Game event that counts toward the challenge (see GameEvents).
@export var elite_event: String = "kill"
## Conditions on the event payload (see ChallengeTracker.matches).
@export var elite_conditions: Dictionary = {}
@export var elite_target: int = 100
## Challenge text; {target} is replaced with elite_target.
@export var elite_challenge_text: String = ""

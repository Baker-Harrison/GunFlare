class_name UnlockableData
extends Resource
## Base for anything the player can unlock: weapons, attachments, camos,
## equipment, perks, streak rewards and menu features.

## Unique id used everywhere in code and save files.
@export var id: String = ""
## weapon, attachment, camo, lethal, tactical, perk, killstreak, deathstreak, feature
@export var kind: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Player rank that unlocks this. 0 = not unlocked by rank (challenge reward instead).
@export var unlock_rank: int = 1

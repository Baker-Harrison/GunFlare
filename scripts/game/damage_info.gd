class_name DamageInfo
extends RefCounted
## One instance of damage dealt to a soldier or vehicle.

var attacker: Node = null # Soldier (may be freed / null for world damage)
var weapon_id: String = "" # weapon, equipment, or streak id
var amount: float = 0.0
var zone: String = "chest" # head, chest, limb
var explosive := false
var melee := false
var streak := "" # streak reward id when a streak got the kill
var position := Vector3.ZERO
var direction := Vector3.FORWARD
var distance := 0.0
var penetrated := false
var attachment_count := 0
var attacker_perks: Array = []
var attacker_downed := false
var suppressed := false


var headshot: bool:
	get:
		return zone == "head"

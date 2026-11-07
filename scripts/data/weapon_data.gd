class_name WeaponData
extends UnlockableData
## A gun. Unlocked by rank; its attachments unlock from kills with it,
## its camos from headshots with it (primaries only).

## assault, smg, lmg, sniper, shotgun, pistol, machine_pistol, launcher
@export var weapon_class: String = ""
@export_enum("primary", "secondary") var slot: String = "primary"

@export_group("Stats")
@export var damage: float = 30.0
@export var fire_rate_rpm: float = 600.0
@export var magazine: int = 30
@export var range_m: float = 40.0

## attachment id -> kills needed with this weapon. Order = unlock order.
@export var attachment_unlocks: Dictionary = {}

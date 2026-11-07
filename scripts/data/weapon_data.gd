class_name WeaponData
extends UnlockableData
## A gun. Unlocked by rank; its attachments unlock from kills with it,
## its camos from headshots with it (primaries only).

## assault, smg, lmg, sniper, shotgun, pistol, machine_pistol, launcher
@export var weapon_class: String = ""
@export_enum("primary", "secondary") var slot: String = "primary"
## auto, burst, semi, bolt, pump, launcher
@export var fire_mode: String = "auto"
@export var burst_count: int = 3

@export_group("Damage")
@export var damage_max: float = 30.0
@export var damage_min: float = 20.0
## Full damage up to range_min (m), falls linearly to damage_min at range_max.
@export var range_min: float = 25.0
@export var range_max: float = 50.0
@export var head_mult: float = 1.4
@export var chest_mult: float = 1.0
@export var limb_mult: float = 1.0
@export var pellets: int = 1
## Bullet penetration strength (walls), 0..1.
@export var penetration: float = 0.5

@export_group("Handling")
@export var fire_rate_rpm: float = 750.0
@export var magazine: int = 30
@export var reserve_mags: int = 4
@export var reload_time: float = 2.2
@export var reload_empty_time: float = 2.8
@export var ads_time: float = 0.25
@export var ads_fov_mult: float = 0.8
@export var move_mult: float = 0.95
@export var ads_move_mult: float = 0.5
## Degrees.
@export var hip_spread: float = 3.5
@export var ads_spread: float = 0.15
@export var recoil_vertical: float = 0.6
@export var recoil_horizontal: float = 0.25
@export var sprint_out_time: float = 0.25
@export var swap_time: float = 0.6

@export_group("Projectile")
## Launchers: projectile speed m/s and blast radius.
@export var projectile_speed: float = 0.0
@export var blast_radius: float = 0.0
@export var projectile_gravity: float = 0.0

@export_group("Presentation")
## Model id under res://assets/weapons/<model>.glb
@export var model: String = ""
## Gunshot sound family: rifle, rifle_heavy, smg, lmg, sniper, pistol, magnum, shotgun, launcher
@export var sound: String = "rifle"

## attachment id -> kills needed with this weapon. Order = unlock order.
@export var attachment_unlocks: Dictionary = {}


## Damage at a given distance, before hit-zone multiplier.
func damage_at(distance: float) -> float:
	if distance <= range_min:
		return damage_max
	if distance >= range_max:
		return damage_min
	return lerpf(damage_max, damage_min, (distance - range_min) / (range_max - range_min))


func seconds_per_shot() -> float:
	return 60.0 / fire_rate_rpm

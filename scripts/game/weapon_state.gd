class_name WeaponState
extends RefCounted
## Runtime state of one carried weapon: ammo, fire timing, reloads and
## the effect of its attachments.

signal reload_started(total: float, empty: bool)
signal reload_finished
signal shell_loaded
signal dry_fired

var data: WeaponData
var attachments: Array = []
var camo := ""
var mag := 0
var reserve := 0
var mag_size := 0
var cooldown := 0.0
var burst_left := 0
var trigger_prev := false
var reloading := false
var reload_timer := 0.0
var reload_total := 0.0
var shell_reload := false
var bloom := 0.0 # extra spread from sustained fire, degrees

## Underbarrel attachment mode (grenade launcher / shotgun).
var alt_mode := false
var alt_ammo := 0
var alt_reserve := 0

var _reload_mult := 1.0


func _init(weapon: WeaponData, attachment_ids: Array = [], camo_id := "", extra_mags := 0, reload_mult := 1.0) -> void:
	data = weapon
	attachments = attachment_ids.duplicate()
	camo = camo_id
	_reload_mult = reload_mult
	mag_size = data.magazine
	if has("ext_mag"):
		mag_size = int(ceil(mag_size * 1.5))
	if has("akimbo"):
		mag_size *= 2
	mag = mag_size
	reserve = mag_size * (data.reserve_mags + extra_mags)
	shell_reload = data.weapon_class == "shotgun" and data.fire_mode != "auto" and data.magazine > 2
	if has("underbarrel_gl"):
		alt_ammo = 1
		alt_reserve = 1
	elif has("underbarrel_shotgun"):
		alt_ammo = 4
		alt_reserve = 4


func has(attachment: String) -> bool:
	return attachments.has(attachment)


func has_alt() -> bool:
	return has("underbarrel_gl") or has("underbarrel_shotgun")


# --- Derived stats -----------------------------------------------------------

func rpm() -> float:
	if alt_mode:
		return 60.0 if has("underbarrel_gl") else 80.0
	return data.fire_rate_rpm * (1.25 if has("rapid_fire") else 1.0)


func recoil_mult() -> float:
	var m := 1.0
	if has("grip"):
		m *= 0.6
	if has("rapid_fire"):
		m *= 1.1
	if has("akimbo"):
		m *= 1.3
	return m


func range_mult() -> float:
	return 0.75 if has("suppressor") else 1.0


func penetration() -> float:
	return minf(data.penetration + (0.5 if has("fmj") else 0.0), 1.5)


func optic() -> String:
	for o in ContentDB.OPTICS:
		if has(o):
			return o
	return ""


func ads_fov_mult() -> float:
	match optic():
		"marksman_scope":
			return 0.5
		"thermal":
			return 0.4 if data.weapon_class != "sniper" else 0.3
		"reflex", "holo":
			return maxf(data.ads_fov_mult, 0.78)
	return data.ads_fov_mult


func ads_time(perk_mult := 1.0) -> float:
	var t := data.ads_time
	if optic() in ["marksman_scope", "thermal"]:
		t += 0.05
	return t * perk_mult


func can_ads() -> bool:
	return not has("akimbo")


func is_scoped() -> bool:
	return data.weapon_class == "sniper" or optic() in ["marksman_scope", "thermal"]


func pellets() -> int:
	if alt_mode and has("underbarrel_shotgun"):
		return 8
	return data.pellets


func is_projectile() -> bool:
	return data.fire_mode == "launcher" or (alt_mode and has("underbarrel_gl"))


func current_ammo() -> int:
	return alt_ammo if alt_mode else mag


func current_reserve() -> int:
	return alt_reserve if alt_mode else reserve


func current_mag_size() -> int:
	if alt_mode:
		return 1 if has("underbarrel_gl") else 4
	return mag_size


func needs_reload() -> bool:
	return current_ammo() < current_mag_size() and current_reserve() > 0


func is_empty() -> bool:
	return current_ammo() <= 0 and current_reserve() <= 0


# --- Actions -----------------------------------------------------------------

func toggle_alt() -> bool:
	if not has_alt():
		return false
	alt_mode = not alt_mode
	cancel_reload()
	return true


func start_reload() -> bool:
	if reloading or not needs_reload():
		return false
	reloading = true
	var empty := current_ammo() == 0
	if alt_mode:
		reload_total = (2.0 if has("underbarrel_gl") else 0.6) * _reload_mult
	elif shell_reload:
		reload_total = data.reload_time * _reload_mult
	else:
		reload_total = (data.reload_empty_time if empty else data.reload_time) * _reload_mult
	# Shell-by-shell reloads start with a short lift before the first shell.
	reload_timer = reload_total + (0.25 * _reload_mult if shell_reload and not alt_mode else 0.0)
	reload_started.emit(reload_total, empty)
	return true


func cancel_reload() -> void:
	reloading = false
	reload_timer = 0.0


func refill(mags: int) -> void:
	reserve = mini(reserve + mag_size * mags, mag_size * (data.reserve_mags + 3))


## Advance timers. Returns the number of shots to fire this frame (0 or 1).
func tick(delta: float, trigger: bool, allowed: bool) -> int:
	cooldown = maxf(cooldown - delta, -0.05)
	bloom = move_toward(bloom, 0.0, delta * 4.0)
	var pressed := trigger and not trigger_prev
	trigger_prev = trigger

	if reloading:
		reload_timer -= delta
		if shell_reload and not alt_mode:
			if pressed and mag > 0 and allowed:
				reloading = false # fire interrupts a shell reload
			elif reload_timer <= 0.0:
				mag += 1
				reserve -= 1
				shell_loaded.emit()
				if mag >= mag_size or reserve <= 0:
					reloading = false
					reload_finished.emit()
				else:
					reload_timer += reload_total
		elif reload_timer <= 0.0:
			_finish_reload()

	if not allowed or reloading:
		burst_left = 0
		return 0

	var spr := 60.0 / rpm()
	var shots := 0
	var mode := "semi" if alt_mode else data.fire_mode
	if burst_left > 0:
		if cooldown <= 0.0 and current_ammo() > 0:
			shots = 1
			burst_left -= 1
			cooldown = maxf(cooldown, 0.0) + spr
			if burst_left == 0:
				cooldown += 0.2
		else:
			burst_left = 0 if current_ammo() <= 0 else burst_left
	elif mode == "auto":
		if trigger and cooldown <= 0.0 and current_ammo() > 0:
			shots = 1
			cooldown = maxf(cooldown, 0.0) + spr
	elif mode == "burst":
		if pressed and cooldown <= 0.0 and current_ammo() > 0:
			shots = 1
			burst_left = data.burst_count - 1
			cooldown = spr
	elif pressed and cooldown <= 0.0 and current_ammo() > 0:
		shots = 1
		cooldown = spr

	if pressed and current_ammo() <= 0 and cooldown <= 0.0:
		dry_fired.emit()
	if shots > 0:
		if alt_mode:
			alt_ammo -= 1
		else:
			mag -= 1
		bloom = minf(bloom + data.hip_spread * 0.12, data.hip_spread)
	return shots


func _finish_reload() -> void:
	reloading = false
	if alt_mode:
		var n := mini(current_mag_size() - alt_ammo, alt_reserve)
		alt_ammo += n
		alt_reserve -= n
	else:
		var n := mini(mag_size - mag, reserve)
		mag += n
		reserve -= n
	reload_finished.emit()

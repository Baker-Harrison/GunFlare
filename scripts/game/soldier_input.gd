class_name SoldierInput
extends RefCounted
## What a controller (player or bot) wants the soldier to do this frame.

var move := Vector2.ZERO # x = right, y = forward, length <= 1
var look_delta := Vector2.ZERO # radians: x yaw (left +), y pitch (up +)
var fire := false
var ads := false
var sprint := false
var jump := false
var crouch_pressed := false
var prone_pressed := false
var reload := false
var swap := false
var melee := false
var lethal := false # held: cook / aim, released: throw
var tactical := false
var interact := false
var use_streak := false
var toggle_attachment := false


func clear_pulses() -> void:
	jump = false
	crouch_pressed = false
	prone_pressed = false
	reload = false
	swap = false
	melee = false
	use_streak = false
	toggle_attachment = false
	look_delta = Vector2.ZERO

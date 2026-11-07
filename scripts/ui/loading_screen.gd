class_name LoadingScreen
extends Control
## Shown while a map builds and its navigation bakes.

const TIPS := [
	"Aiming down sights tightens your spread but slows you down.",
	"Suppressed weapons keep you off the enemy minimap.",
	"Firing an unsuppressed weapon shows you as a red dot on enemy minimaps.",
	"Cook a Shard Grenade by holding G before throwing it.",
	"Pick up a fallen enemy's weapon by holding F over it.",
	"Shortcut perk: your streak rewards need one fewer kill.",
	"Ghostline hides you from Pulse Scans, sentries and drones.",
	"Shoot down enemy aircraft with launchers for bonus XP.",
	"Hold your breath with Shift while scoped to steady your aim.",
	"Prone makes you harder to spot at range — and steadies recoil.",
	"Bullets penetrate wood, plaster and sheet metal. Piercing rounds go further.",
	"Completing weapon challenges unlocks attachments and camos.",
]

var map_name := ""
var mode_name := ""
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UiKit.vbox(10)
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	v.position = Vector2(80, -260)
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	add_child(v)
	v.add_child(UiKit.label(mode_name.to_upper(), 22, UiKit.ACCENT, true))
	v.add_child(UiKit.label(map_name.to_upper(), 64, UiKit.TEXT, true))
	_status = UiKit.label("Loading...", 18, UiKit.MUTED)
	v.add_child(_status)
	var tip := UiKit.label("TIP: " + TIPS[randi() % TIPS.size()], 18, UiKit.TEXT)
	v.add_child(tip)


func set_status(t: String) -> void:
	if _status:
		_status.text = t

class_name EndScreen
extends CanvasLayer
## End-of-match report: result, scoreboard, XP earned, rank bar, unlocks and
## completed challenges.

var match_ref: Match
var won := false
var tied := false
var xp_gained := 0
var rank_start := 1
var unlocks: Array = []
var challenges: Array = []
var _bar: ProgressBar
var _rank_label: Label
var _shown_xp := 0.0


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.025, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := UiKit.vbox(12)
	v.position = Vector2(80, 60)
	root.add_child(v)
	var title := "DRAW" if tied else ("VICTORY" if won else "DEFEAT")
	v.add_child(UiKit.label(title, 72, UiKit.ACCENT if won else (UiKit.TEXT if tied else UiKit.RED), true))
	v.add_child(UiKit.label("%s  —  %s" % [match_ref.mode.display_name.to_upper(), match_ref.map.display_name.to_upper()], 20, UiKit.MUTED))
	var cols := UiKit.hbox(40)
	v.add_child(cols)
	# Scoreboard
	var sb := UiKit.vbox(4)
	sb.custom_minimum_size.x = 760
	cols.add_child(sb)
	var data: Dictionary = match_ref.scoreboard_rows()
	for t: Dictionary in data["teams"]:
		sb.add_child(UiKit.label("%s   %d" % [t["name"], t["score"]] if match_ref.mode.team_based else t["name"], 22, t["color"], true))
		var hdr := UiKit.hbox()
		for h in [["NAME", 300], ["SCORE", 100], ["KILLS", 90], ["DEATHS", 90], ["ASSISTS", 90]]:
			var l := UiKit.label(h[0], 13, UiKit.MUTED)
			l.custom_minimum_size.x = h[1]
			hdr.add_child(l)
		sb.add_child(hdr)
		for r: Dictionary in t["rows"]:
			var row := UiKit.hbox()
			var col := Color(1, 0.85, 0.3) if r["me"] else UiKit.TEXT
			for cell in [[r["name"], 300], [str(r["score"]), 100], [str(r["kills"]), 90], [str(r["deaths"]), 90], [str(r["assists"]), 90]]:
				var l2 := UiKit.label(cell[0], 17, col)
				l2.custom_minimum_size.x = cell[1]
				row.add_child(l2)
			sb.add_child(row)
	# Progress
	var pv := UiKit.vbox(8)
	pv.custom_minimum_size.x = 520
	cols.add_child(pv)
	pv.add_child(UiKit.label("XP EARNED", 16, UiKit.MUTED, true))
	pv.add_child(UiKit.label("+%d" % xp_gained, 48, Color(1, 0.88, 0.4), true))
	_rank_label = UiKit.label(UiKit.rank_text(), 20)
	pv.add_child(_rank_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(480, 16)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = UiKit.xp_fraction()
	pv.add_child(_bar)
	if Progression.rank > rank_start:
		pv.add_child(UiKit.label("PROMOTED  %d → %d" % [rank_start, Progression.rank], 22, UiKit.ACCENT, true))
	if Progression.can_prestige():
		pv.add_child(UiKit.label("%s AVAILABLE IN BARRACKS" % ContentDB.TERMS["prestige"].to_upper(), 18, Color(1, 0.85, 0.3), true))
	if not unlocks.is_empty():
		pv.add_child(UiKit.label("UNLOCKED", 16, UiKit.MUTED, true))
		for u in unlocks.slice(0, 10):
			pv.add_child(UiKit.label("• " + str(u), 17, Color(0.7, 1.0, 0.6)))
	if not challenges.is_empty():
		pv.add_child(UiKit.label("CHALLENGES COMPLETED", 16, UiKit.MUTED, true))
		for c in challenges.slice(0, 8):
			pv.add_child(UiKit.label("• " + str(c), 17, Color(1, 0.85, 0.3)))
	var buttons := UiKit.hbox(12)
	v.add_child(buttons)
	buttons.add_child(UiKit.button("PLAY AGAIN", func() -> void:
		Fx.attach_to(null)
		Sfx.attach_to(null)
		Game.start_match(match_ref.config), 22, 260))
	buttons.add_child(UiKit.button("MAIN MENU", func() -> void: match_ref.leave(), 22, 260))

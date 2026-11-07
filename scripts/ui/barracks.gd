class_name Barracks
extends VBoxContainer
## Challenges, ranks, titles & emblems, career stats and Ascension.

signal closed

var _tabs: HBoxContainer
var _page: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label("BARRACKS", 40, UiKit.TEXT, true))
	_tabs = UiKit.hbox(8)
	add_child(_tabs)
	for t in [["CHALLENGES", _challenges.bind("weapon")], ["PERK CHALLENGES", _challenges.bind("perk")],
			["STREAKS", _challenges.bind("streak")], ["FEATS", _challenges.bind("feat")], ["CAREER", _career],
			["RANKS", _ranks], [ContentDB.TERMS["prestige"].to_upper(), _ascension]]:
		_tabs.add_child(UiKit.button(t[0], t[1], 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1400, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_page = UiKit.vbox(4)
	scroll.add_child(_page)
	add_child(UiKit.button("BACK", func() -> void: closed.emit(), 20, 300))
	_challenges("weapon")


func _challenges(category: String) -> void:
	UiKit.clear(_page)
	for c in ContentDB.challenges:
		if c.category != category and not (category == "feat" and c.category == "lifetime"):
			continue
		var st: Dictionary = Progression.challenge_state(c.id)
		var tier: int = st["tier"]
		var done := tier >= c.tiers.size()
		var row := UiKit.hbox(12)
		var nm := UiKit.label(c.display_name.to_upper() + ("  ✓" if done else ""), 16, UiKit.ACCENT if done else UiKit.TEXT, true)
		nm.custom_minimum_size.x = 360
		row.add_child(nm)
		var desc := UiKit.label(c.describe(tier), 15, UiKit.MUTED)
		desc.custom_minimum_size.x = 480
		row.add_child(desc)
		var p := ProgressBar.new()
		p.show_percentage = false
		p.custom_minimum_size = Vector2(240, 10)
		var target: int = c.tiers[mini(tier, c.tiers.size() - 1)]["target"]
		p.max_value = target
		p.value = mini(st["count"], target)
		row.add_child(p)
		row.add_child(UiKit.label("%d/%d" % [mini(st["count"], target), target] + ("   Tier %d/%d" % [mini(tier + 1, c.tiers.size()), c.tiers.size()] if c.tiers.size() > 1 else ""), 14, UiKit.MUTED))
		_page.add_child(row)


func _career() -> void:
	UiKit.clear(_page)
	var s := Progression.stats
	for k in ["kills", "deaths", "assists", "headshots", "wins", "losses", "matches"]:
		_page.add_child(UiKit.label("%s:  %d" % [k.capitalize(), s.get(k, 0)], 20))
	var kd := float(s.get("kills", 0)) / maxf(float(s.get("deaths", 0)), 1.0)
	_page.add_child(UiKit.label("K/D ratio:  %.2f" % kd, 20, UiKit.ACCENT))
	_page.add_child(UiKit.label("", 10))
	_page.add_child(UiKit.label("TITLES (%d)" % Progression.titles.size(), 16, UiKit.ACCENT, true))
	_page.add_child(UiKit.label(", ".join(Progression.titles) if not Progression.titles.is_empty() else "None yet — complete challenges to earn titles.", 15, UiKit.MUTED))
	_page.add_child(UiKit.label("EMBLEMS (%d)" % Progression.emblems.size(), 16, UiKit.ACCENT, true))
	_page.add_child(UiKit.label(", ".join(Progression.emblems.map(func(e: String) -> String: return e.trim_prefix("emblem_").capitalize())) if not Progression.emblems.is_empty() else "None yet.", 15, UiKit.MUTED))


func _ranks() -> void:
	UiKit.clear(_page)
	for r in range(1, ContentDB.MAX_RANK + 1):
		var unl := ContentDB.unlocks_at_rank(r).map(func(i: UnlockableData) -> String: return i.display_name)
		var reached := Progression.rank >= r
		var t := "%2d  %-16s  %8d XP   %s" % [r, ContentDB.rank_name(r), ContentDB.rank_min_xp[r - 1], ", ".join(unl)]
		_page.add_child(UiKit.label(t, 15, UiKit.TEXT if reached else UiKit.LOCKED))


func _ascension() -> void:
	UiKit.clear(_page)
	var term: String = ContentDB.TERMS["prestige"]
	_page.add_child(UiKit.label("%s %d / %d" % [term.to_upper(), Progression.prestige, ContentDB.MAX_PRESTIGE], 28, UiKit.ACCENT, true))
	_page.add_child(UiKit.label("Reach Rank %d and complete it to %s. You restart at Rank 1: rank unlocks,\nattachments, camos, Elite perks, classes and challenge progress reset. Titles, emblems,\nlifetime challenges and stats are kept. The first two Ascensions each grant an extra class slot." % [ContentDB.MAX_RANK, term.to_lower()], 17, UiKit.MUTED))
	if Progression.can_prestige():
		var confirm := false
		var b := UiKit.button("ENTER %s %d" % [term.to_upper(), Progression.prestige + 1], func() -> void: pass, 24, 420)
		b.pressed.connect(func() -> void:
			if not confirm:
				confirm = true
				b.text = "ARE YOU SURE? CLICK AGAIN"
				return
			Progression.prestige_up()
			Sfx.play_2d("rank_up", 0.0)
			_ascension())
		_page.add_child(b)
	else:
		var need := ContentDB.max_xp - Progression.xp
		_page.add_child(UiKit.label("%d XP to go." % need if Progression.prestige < ContentDB.MAX_PRESTIGE else "Maximum %s reached." % term, 18))

class_name CreateAClass
extends VBoxContainer
## Edit custom classes: weapons, attachments, camos, perks, equipment,
## setback perk, plus streak reward selection.

signal closed

var _slot := 0
var _body: HBoxContainer
var _list: VBoxContainer
var _editor: VBoxContainer
var _picker: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label("CREATE-A-CLASS", 40, UiKit.TEXT, true))
	_body = UiKit.hbox(24)
	add_child(_body)
	_list = UiKit.vbox(6)
	_list.custom_minimum_size.x = 300
	_body.add_child(_list)
	_editor = UiKit.vbox(6)
	_editor.custom_minimum_size.x = 560
	_body.add_child(_editor)
	_picker = UiKit.vbox(4)
	_picker.custom_minimum_size.x = 520
	_body.add_child(_picker)
	add_child(UiKit.button("BACK", func() -> void:
		Progression.save_profile()
		closed.emit(), 20, 300))
	_refresh()


func _cls() -> Dictionary:
	return Progression.classes[_slot]


func _refresh() -> void:
	UiKit.clear(_list)
	_list.add_child(UiKit.label("CLASSES", 15, UiKit.ACCENT, true))
	for i in Progression.custom_class_slots():
		var idx := i
		var c: Dictionary = Progression.classes[i]
		var b := UiKit.button(c.get("name", "Custom %d" % (i + 1)).to_upper(), func() -> void:
			_slot = idx
			UiKit.clear(_picker)
			_refresh(), 18, 280)
		if i == _slot:
			b.add_theme_color_override("font_color", UiKit.ACCENT)
		_list.add_child(b)
	_list.add_child(UiKit.label("", 10))
	_list.add_child(UiKit.button("STREAK REWARDS", _pick_streaks, 18, 280))
	_build_editor()


func _build_editor() -> void:
	UiKit.clear(_editor)
	var c := _cls()
	var name_edit := LineEdit.new()
	name_edit.text = c.get("name", "Custom Class")
	name_edit.max_length = 20
	name_edit.text_changed.connect(func(t: String) -> void:
		c["name"] = t
		Progression.save_profile())
	name_edit.focus_exited.connect(_refresh_list_only)
	_editor.add_child(name_edit)
	_row("PRIMARY", _item_name(c["primary"]), func() -> void: _pick_weapon("primary"))
	_row("  Attachment", _att_names(c, "primary"), func() -> void: _pick_attachments("primary"))
	_row("  Camo", _item_name(c.get("primary_camo", "")) if c.get("primary_camo", "") != "" else "None", _pick_camo)
	_row("SECONDARY", _item_name(c["secondary"]), func() -> void: _pick_weapon("secondary"))
	_row("  Attachment", _att_names(c, "secondary"), func() -> void: _pick_attachments("secondary"))
	_row("LETHAL", _item_name(c["lethal"]), func() -> void: _pick_simple("lethal", "lethal"))
	_row("TACTICAL", _item_name(c["tactical"]), func() -> void: _pick_simple("tactical", "tactical"))
	for i in 3:
		var idx := i
		var pid: String = c["perks"][i]
		var nm := _item_name(pid) + ("  ★ ELITE" if Progression.has_elite(pid) else "")
		_row("PERK %d" % (i + 1), nm, func() -> void: _pick_perk(idx))
	_row("SETBACK PERK", _item_name(c["deathstreak"]), func() -> void: _pick_simple("deathstreak", "deathstreak"))
	var errs := Progression.validate_loadout(c)
	if not errs.is_empty():
		_editor.add_child(UiKit.label("⚠ " + errs[0], 15, UiKit.RED))
	# Stats of the primary
	var w := ContentDB.get_item(c["primary"]) as WeaponData
	if w:
		_editor.add_child(UiKit.label("", 6))
		_stat_bar("DAMAGE", w.damage_max / 100.0)
		_stat_bar("FIRE RATE", w.fire_rate_rpm / 1100.0)
		_stat_bar("RANGE", clampf(w.range_max / 100.0, 0.0, 1.0))
		_stat_bar("ACCURACY", 1.0 - clampf(w.recoil_vertical / 3.5, 0.0, 1.0))
		_stat_bar("MOBILITY", (w.move_mult - 0.8) / 0.2)


func _refresh_list_only() -> void:
	_refresh()


func _row(label: String, value: String, cb: Callable) -> void:
	var h := UiKit.hbox()
	var l := UiKit.label(label, 15, UiKit.MUTED, true)
	l.custom_minimum_size.x = 160
	h.add_child(l)
	var b := UiKit.button(value.to_upper(), cb, 17, 380)
	h.add_child(b)
	_editor.add_child(h)


func _stat_bar(label: String, f: float) -> void:
	var h := UiKit.hbox()
	var l := UiKit.label(label, 13, UiKit.MUTED)
	l.custom_minimum_size.x = 160
	h.add_child(l)
	var p := ProgressBar.new()
	p.max_value = 1.0
	p.value = clampf(f, 0.02, 1.0)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(380, 10)
	h.add_child(p)
	_editor.add_child(h)


func _item_name(id: String) -> String:
	var it := ContentDB.get_item(id)
	return it.display_name if it else id


func _att_names(c: Dictionary, slot: String) -> String:
	var atts: Array = c.get(slot + "_attachments", [])
	if atts.is_empty():
		return "None"
	return ", ".join(atts.map(func(a: String) -> String: return _item_name(a)))


func _picker_header(t: String) -> void:
	UiKit.clear(_picker)
	_picker.add_child(UiKit.label(t, 15, UiKit.ACCENT, true))


func _option(text: String, sub: String, locked: bool, selected: bool, cb: Callable) -> void:
	var b := UiKit.button(text.to_upper() + ("   — " + sub if sub != "" else ""), cb, 16, 500)
	b.disabled = locked
	if selected:
		b.add_theme_color_override("font_color", UiKit.ACCENT)
	_picker.add_child(b)


func _apply() -> void:
	Progression.save_profile()
	_build_editor()


func _pick_weapon(slot: String) -> void:
	_picker_header(slot.to_upper() + " WEAPON")
	var c := _cls()
	var allow_primary: bool = slot == "secondary" and c["perks"].has("second_holster")
	var weapons := ContentDB.items_of_kind("weapon")
	weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool:
		return a.weapon_class + str(a.unlock_rank).pad_zeros(3) < b.weapon_class + str(b.unlock_rank).pad_zeros(3))
	var last_cls := ""
	for w: WeaponData in weapons:
		if w.slot != slot and not (allow_primary and w.slot == "primary"):
			continue
		if w.weapon_class != last_cls:
			last_cls = w.weapon_class
			_picker.add_child(UiKit.label(_class_title(w.weapon_class), 13, UiKit.MUTED, true))
		var unlocked := Progression.is_unlocked(w.id)
		var id := w.id
		_option(w.display_name, "" if unlocked else "Rank %d" % w.unlock_rank, not unlocked, c[slot] == w.id, func() -> void:
			if c[slot] != id:
				c[slot] = id
				c[slot + "_attachments"] = []
				if slot == "primary":
					c["primary_camo"] = ""
			_apply())


func _class_title(cls: String) -> String:
	return {"assault": "ASSAULT RIFLES", "smg": "SUBMACHINE GUNS", "lmg": "LIGHT MACHINE GUNS", "sniper": "SNIPER RIFLES",
		"pistol": "PISTOLS", "machine_pistol": "MACHINE PISTOLS", "shotgun": "SHOTGUNS", "launcher": "LAUNCHERS"}.get(cls, cls.to_upper())


func _pick_attachments(slot: String) -> void:
	var c := _cls()
	var w := ContentDB.get_item(c[slot]) as WeaponData
	_picker_header("ATTACHMENTS — " + w.display_name.to_upper())
	var max_n := 1
	if c["perks"].has("packmule") and (slot == "primary" or Progression.has_elite("packmule")):
		max_n = 2
	_picker.add_child(UiKit.label("Up to %d. %s" % [max_n, "Packmule allows two." if max_n == 1 else ""], 13, UiKit.MUTED))
	var atts: Array = c[slot + "_attachments"]
	_option("None", "", false, atts.is_empty(), func() -> void:
		c[slot + "_attachments"] = []
		_apply()
		_pick_attachments(slot))
	for att: String in w.attachment_unlocks:
		var kills: int = w.attachment_unlocks[att]
		var unlocked := Progression.is_attachment_unlocked(w.id, att)
		var progress: int = Progression.challenge_state(w.id + "_marksman")["count"]
		var a := att
		_option(_item_name(att), "" if unlocked else "%d/%d kills" % [mini(progress, kills), kills], not unlocked, atts.has(att), func() -> void:
			var cur: Array = c[slot + "_attachments"]
			if cur.has(a):
				cur.erase(a)
			else:
				if cur.size() >= max_n:
					cur.pop_front()
				cur.append(a)
			if not Progression.validate_loadout(c).is_empty() and cur.size() > 1:
				cur.erase(a)
				cur.clear()
				cur.append(a)
			_apply()
			_pick_attachments(slot))


func _pick_camo() -> void:
	var c := _cls()
	var w := ContentDB.get_item(c["primary"]) as WeaponData
	_picker_header("CAMO — " + w.display_name.to_upper())
	_option("None", "", false, c.get("primary_camo", "") == "", func() -> void:
		c["primary_camo"] = ""
		_apply())
	var hs: int = Progression.challenge_state(w.id + "_expert")["count"]
	for row in ContentDB.CAMO_TRACK:
		var id: String = row[0]
		var unlocked := Progression.is_camo_unlocked(w.id, id)
		_option(row[1], "" if unlocked else "%d/%d headshots" % [mini(hs, row[2]), row[2]], not unlocked, c.get("primary_camo", "") == id, func() -> void:
			c["primary_camo"] = id
			_apply())


func _pick_perk(slot_index: int) -> void:
	var c := _cls()
	_picker_header("PERK %d" % (slot_index + 1))
	for p: PerkData in ContentDB.items_of_kind("perk"):
		if p.slot != slot_index + 1:
			continue
		var unlocked := Progression.is_unlocked(p.id)
		var st: Dictionary = Progression.challenge_state(p.id + "_elite")
		var sub := p.description
		if not unlocked:
			sub = "Rank %d" % p.unlock_rank
		elif Progression.has_elite(p.id):
			sub += "  ★ " + p.elite_description
		else:
			sub += "  (Elite: %d/%d)" % [mini(st["count"], p.elite_target), p.elite_target]
		var id := p.id
		_option(p.display_name, sub, not unlocked, c["perks"][slot_index] == p.id, func() -> void:
			c["perks"][slot_index] = id
			# Second Holster can't keep a primary in the secondary slot when removed.
			var sec := ContentDB.get_item(c["secondary"]) as WeaponData
			if sec and sec.slot == "primary" and not c["perks"].has("second_holster"):
				c["secondary"] = "m9"
				c["secondary_attachments"] = []
			if not c["perks"].has("packmule"):
				for s in ["primary", "secondary"]:
					var a: Array = c[s + "_attachments"]
					while a.size() > 1:
						a.pop_back()
			_apply())


func _pick_simple(kind: String, key: String) -> void:
	var c := _cls()
	_picker_header(kind.to_upper())
	for it: UnlockableData in ContentDB.items_of_kind(kind):
		var unlocked := Progression.is_unlocked(it.id)
		var id := it.id
		_option(it.display_name, it.description if unlocked else "Rank %d" % it.unlock_rank, not unlocked, c[key] == it.id, func() -> void:
			c[key] = id
			_apply())


func _pick_streaks() -> void:
	_picker_header("STREAK REWARDS — choose 3")
	var sel: Array = Progression.selected_streaks.duplicate()
	var all := ContentDB.items_of_kind("killstreak")
	all.sort_custom(func(a: StreakData, b: StreakData) -> bool: return a.count < b.count)
	for st: StreakData in all:
		var unlocked := Progression.is_unlocked(st.id)
		var id := st.id
		_option("%s  (%d kills)" % [st.display_name, st.count], st.description if unlocked else "Rank %d" % st.unlock_rank, not unlocked, sel.has(st.id), func() -> void:
			var cur: Array = Progression.selected_streaks.duplicate()
			if cur.has(id):
				return
			cur.pop_front()
			cur.append(id)
			cur.sort_custom(func(a: String, b: String) -> bool: return ContentDB.get_item(a).count < ContentDB.get_item(b).count)
			Progression.set_streaks(cur)
			Progression.save_profile()
			_pick_streaks())

class_name WeaponModels
## Builds weapon and equipment models. Uses res://assets/weapons/<id>.glb
## (made by tools/blender) when present, else a procedural model. Every
## weapon model carries marker nodes: Muzzle, Optic, Underbarrel, Mag, ADS,
## LeftHand. Forward is -Z, origin at the pistol grip.

static var _mats: Dictionary = {}

## Proportions for procedural models.
const PROFILES := {
	"m4a1": {"len": 0.36, "barrel": 0.3, "mag": "straight", "stock": "collapsible", "sight": "rail", "hand": "rail"},
	"m16a4": {"len": 0.36, "barrel": 0.45, "mag": "straight", "stock": "fixed", "sight": "carry", "hand": "round"},
	"ak74": {"len": 0.38, "barrel": 0.36, "mag": "curved", "stock": "folding", "sight": "post", "hand": "wood_dark", "wood": false},
	"scar_h": {"len": 0.4, "barrel": 0.34, "mag": "straight_short", "stock": "folding", "sight": "rail", "hand": "rail", "tan": true},
	"g36c": {"len": 0.36, "barrel": 0.24, "mag": "translucent", "stock": "folding", "sight": "handle", "hand": "polymer"},
	"famas": {"len": 0.52, "barrel": 0.18, "mag": "straight", "stock": "bullpup", "sight": "handle", "hand": "polymer"},
	"aug": {"len": 0.5, "barrel": 0.22, "mag": "translucent", "stock": "bullpup", "sight": "scope", "hand": "polymer", "green": true},
	"fal": {"len": 0.42, "barrel": 0.46, "mag": "straight_short", "stock": "wood", "sight": "post", "hand": "wood", "wood": true},
	"hk416": {"len": 0.36, "barrel": 0.28, "mag": "straight", "stock": "collapsible", "sight": "rail", "hand": "rail"},
	"ak47": {"len": 0.38, "barrel": 0.36, "mag": "curved", "stock": "wood", "sight": "post", "hand": "wood", "wood": true},
	"mp5": {"len": 0.3, "barrel": 0.14, "mag": "curved_thin", "stock": "collapsible", "sight": "drum", "hand": "polymer"},
	"ump45": {"len": 0.34, "barrel": 0.14, "mag": "straight", "stock": "folding", "sight": "rail", "hand": "polymer"},
	"p90": {"len": 0.46, "barrel": 0.08, "mag": "top", "stock": "bullpup", "sight": "rail", "hand": "polymer"},
	"mp7": {"len": 0.24, "barrel": 0.1, "mag": "grip", "stock": "collapsible", "sight": "rail", "hand": "polymer"},
	"vector": {"len": 0.32, "barrel": 0.12, "mag": "grip_front", "stock": "folding", "sight": "rail", "hand": "polymer"},
	"mini_uzi": {"len": 0.22, "barrel": 0.06, "mag": "grip", "stock": "wire", "sight": "post", "hand": "none"},
	"m249": {"len": 0.46, "barrel": 0.42, "mag": "box", "stock": "fixed", "sight": "rail", "hand": "round", "heavy": true},
	"rpk": {"len": 0.4, "barrel": 0.5, "mag": "drum", "stock": "wood", "sight": "post", "hand": "wood", "wood": true},
	"m60e4": {"len": 0.52, "barrel": 0.48, "mag": "box", "stock": "fixed", "sight": "rail", "hand": "round", "heavy": true},
	"pkm": {"len": 0.5, "barrel": 0.55, "mag": "box", "stock": "skeleton", "sight": "post", "hand": "none", "heavy": true},
	"m24": {"len": 0.32, "barrel": 0.6, "mag": "none", "stock": "rifle", "sight": "scope", "hand": "rifle", "green": true},
	"svd": {"len": 0.4, "barrel": 0.6, "mag": "straight_short", "stock": "skeleton_wood", "sight": "scope", "hand": "wood", "wood": true},
	"m14ebr": {"len": 0.4, "barrel": 0.48, "mag": "straight_short", "stock": "collapsible", "sight": "scope", "hand": "rail", "tan": true},
	"m107": {"len": 0.5, "barrel": 0.7, "mag": "straight_short", "stock": "fixed", "sight": "scope", "hand": "rail", "heavy": true},
	"m9": {"pistol": true},
	"usp45": {"pistol": true},
	"p226": {"pistol": true},
	"magnum": {"pistol": true, "revolver": true},
	"skorpion": {"len": 0.2, "barrel": 0.08, "mag": "curved_thin", "stock": "wire", "sight": "post", "hand": "none"},
	"tmp": {"len": 0.2, "barrel": 0.08, "mag": "grip", "stock": "none", "sight": "rail", "hand": "polymer"},
	"m93r": {"pistol": true, "long": true},
	"m1014": {"len": 0.36, "barrel": 0.45, "mag": "tube", "stock": "collapsible", "sight": "rail", "hand": "polymer"},
	"spas12": {"len": 0.36, "barrel": 0.45, "mag": "tube", "stock": "folding", "sight": "post", "hand": "pump"},
	"double_barrel": {"len": 0.2, "barrel": 0.6, "mag": "none", "stock": "wood", "sight": "none", "hand": "wood", "wood": true, "double": true},
	"aa12": {"len": 0.44, "barrel": 0.3, "mag": "drum", "stock": "fixed", "sight": "rail", "hand": "polymer"},
	"rpg7": {"launcher": "rpg"},
	"at4": {"launcher": "tube"},
	"m79": {"launcher": "break"},
}


static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"metal":
			m.albedo_color = Color(0.1, 0.1, 0.105)
			m.metallic = 0.75
			m.roughness = 0.42
		"polymer":
			m.albedo_color = Color(0.07, 0.07, 0.07)
			m.roughness = 0.72
		"tan":
			m.albedo_color = Color(0.55, 0.47, 0.34)
			m.roughness = 0.7
		"green":
			m.albedo_color = Color(0.22, 0.25, 0.19)
			m.roughness = 0.7
		"wood":
			m.albedo_color = Color(0.42, 0.22, 0.1)
			m.roughness = 0.55
		"wood_dark":
			m.albedo_color = Color(0.22, 0.12, 0.06)
			m.roughness = 0.5
		"translucent":
			m.albedo_color = Color(0.15, 0.15, 0.15, 0.75)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.3
		"glass":
			m.albedo_color = Color(0.2, 0.3, 0.35, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.5
			m.roughness = 0.05
		"olive_drab":
			m.albedo_color = Color(0.3, 0.32, 0.2)
			m.roughness = 0.65
		"red_light":
			m.albedo_color = Color(1, 0.1, 0.05)
			m.emission_enabled = true
			m.emission = Color(1, 0.1, 0.05)
			m.emission_energy_multiplier = 4.0
		"brass":
			m.albedo_color = Color(0.8, 0.6, 0.25)
			m.metallic = 0.9
			m.roughness = 0.3
	_mats[kind] = m
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, nm := "", camo := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	if nm != "":
		mi.name = nm
	if camo:
		mi.set_meta("camo", true)
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, length: float, pos: Vector3, material: Material, along_z := true, camo := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 14
	mi.mesh = c
	mi.material_override = material
	mi.position = pos
	if along_z:
		mi.rotation = Vector3(PI * 0.5, 0, 0)
	if camo:
		mi.set_meta("camo", true)
	parent.add_child(mi)
	return mi


static func _marker(parent: Node3D, nm: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n


static func create(weapon_id: String, attachments: Array = [], camo := "") -> Node3D:
	var data := ContentDB.get_item(weapon_id) as WeaponData
	var model_id := data.model if data else weapon_id
	var path := "res://assets/weapons/%s.glb" % model_id
	var root: Node3D
	if ResourceLoader.exists(path):
		root = (load(path) as PackedScene).instantiate()
	else:
		root = _procedural(weapon_id, data)
	root.name = "Weapon_" + weapon_id
	_add_attachments(root, attachments, data)
	if camo != "":
		var cm := CamoLibrary.weapon_material(camo)
		if cm:
			_apply_camo(root, cm)
	return root


static func _apply_camo(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var is_camo := mi.has_meta("camo") or mi.name.to_lower().contains("camo") or mi.name.to_lower().contains("body")
		if not is_camo and mi.mesh:
			for i in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(i)
				if sm and sm.resource_name.to_lower().contains("camo"):
					mi.set_surface_override_material(i, m)
		if is_camo:
			mi.material_override = m
	for c in n.get_children():
		_apply_camo(c, m)


static func _procedural(id: String, data: WeaponData) -> Node3D:
	var root := Node3D.new()
	var p: Dictionary = PROFILES.get(id, {"len": 0.36, "barrel": 0.3, "mag": "straight", "stock": "fixed", "sight": "rail", "hand": "rail"})
	var metal := mat("metal")
	var body_mat := mat("tan") if p.get("tan", false) else (mat("green") if p.get("green", false) else mat("polymer"))
	if p.has("launcher"):
		_build_launcher(root, p["launcher"])
		return root
	if p.get("pistol", false):
		_build_pistol(root, p)
		return root
	var L: float = p["len"]
	var B: float = p["barrel"]
	var heavy: bool = p.get("heavy", false)
	var bullpup: bool = p["stock"] == "bullpup"
	var rh := 0.075 if not heavy else 0.095
	var rw := 0.05 if not heavy else 0.065
	# Receiver sits above and ahead of the grip.
	var rec_z := -L * 0.35 if not bullpup else -L * 0.15
	_box(root, Vector3(rw, rh, L), Vector3(0, 0.06, rec_z), metal if not bullpup else body_mat, "Body", true)
	_box(root, Vector3(rw * 0.9, 0.03, L * 0.6), Vector3(0, 0.1 + rh * 0.3, rec_z - L * 0.1), metal) # top
	# Grip
	_box(root, Vector3(0.035, 0.11, 0.045), Vector3(0, -0.03, 0.02), mat("polymer"), "", false, Vector3(0.3, 0, 0))
	_box(root, Vector3(0.012, 0.03, 0.05), Vector3(0, 0.01, -0.03), metal) # trigger guard
	# Handguard + barrel
	var front_z := rec_z - L * 0.5
	var hand: String = p["hand"]
	var hand_len := B * 0.6
	if hand != "none":
		var hm: Material = body_mat
		if hand == "wood":
			hm = mat("wood")
		elif hand == "wood_dark":
			hm = mat("wood_dark")
		elif hand == "rail":
			hm = metal
		_box(root, Vector3(rw * 1.05, rh * 0.85, hand_len), Vector3(0, 0.06, front_z - hand_len * 0.5), hm, "Handguard", hand != "wood")
		if hand == "rail":
			for side in [-1, 1]:
				_box(root, Vector3(0.008, 0.015, hand_len * 0.9), Vector3(side * rw * 0.55, 0.06, front_z - hand_len * 0.5), metal)
		if hand == "pump":
			_box(root, Vector3(0.06, 0.05, 0.14), Vector3(0, 0.03, front_z - 0.12), mat("polymer"))
	var barrel_r := 0.011 if not heavy else 0.015
	if id in ["m1014", "spas12", "aa12"]:
		barrel_r = 0.016
	_cyl(root, barrel_r, B, Vector3(0, 0.075, front_z - B * 0.5), metal)
	if p.get("double", false):
		_cyl(root, barrel_r, B, Vector3(0, 0.045, front_z - B * 0.5), metal)
	var muzzle_z := front_z - B
	_cyl(root, barrel_r * 1.6, 0.04, Vector3(0, 0.075, muzzle_z + 0.02), metal) # flash hider
	if p["mag"] == "tube":
		_cyl(root, 0.012, B * 0.8, Vector3(0, 0.04, front_z - B * 0.4), metal)
	# Front sight post
	if p["sight"] in ["post", "carry"]:
		_box(root, Vector3(0.008, 0.05, 0.01), Vector3(0, 0.11, muzzle_z + 0.08), metal)
	# Rear sight / carry handle / scope
	var top_y := 0.06 + rh * 0.5
	match p["sight"]:
		"carry":
			_box(root, Vector3(0.02, 0.04, 0.14), Vector3(0, top_y + 0.03, rec_z + 0.03), metal)
		"handle":
			_box(root, Vector3(0.025, 0.05, L * 0.6), Vector3(0, top_y + 0.035, rec_z), body_mat)
		"scope":
			_cyl(root, 0.022, 0.3, Vector3(0, top_y + 0.04, rec_z), metal)
			_cyl(root, 0.028, 0.05, Vector3(0, top_y + 0.04, rec_z - 0.15), metal)
			_cyl(root, 0.026, 0.04, Vector3(0, top_y + 0.04, rec_z + 0.14), metal)
		"rail", "drum":
			_box(root, Vector3(0.025, 0.012, L * 0.7), Vector3(0, top_y + 0.006, rec_z), metal)
			_box(root, Vector3(0.016, 0.03, 0.02), Vector3(0, top_y + 0.02, rec_z + L * 0.3), metal) # rear BUIS
	# Stock
	var stock: String = p["stock"]
	match stock:
		"fixed", "rifle":
			_box(root, Vector3(0.045, 0.09, 0.26), Vector3(0, 0.03, 0.17), body_mat, "Stock", true)
		"wood", "skeleton_wood":
			_box(root, Vector3(0.042, 0.1, 0.28), Vector3(0, 0.02, 0.18), mat("wood"), "Stock")
		"collapsible":
			_cyl(root, 0.014, 0.18, Vector3(0, 0.07, 0.1), metal)
			_box(root, Vector3(0.04, 0.085, 0.09), Vector3(0, 0.04, 0.2), mat("polymer"), "Stock")
		"folding", "skeleton":
			_box(root, Vector3(0.03, 0.015, 0.24), Vector3(0, 0.085, 0.14), metal)
			_box(root, Vector3(0.03, 0.015, 0.24), Vector3(0, 0.0, 0.14), metal)
			_box(root, Vector3(0.035, 0.1, 0.03), Vector3(0, 0.04, 0.25), metal)
		"wire":
			_box(root, Vector3(0.025, 0.01, 0.18), Vector3(0, 0.06, 0.1), metal)
		"bullpup":
			_box(root, Vector3(0.05, 0.1, 0.12), Vector3(0, 0.04, 0.12), body_mat, "Stock", true)
	# Magazine
	var mag := Node3D.new()
	mag.name = "Mag"
	root.add_child(mag)
	var mag_z := rec_z + L * 0.15 if not bullpup else 0.07
	mag.position = Vector3(0, 0.02, mag_z)
	match p["mag"]:
		"straight":
			_box(mag, Vector3(0.026, 0.14, 0.06), Vector3(0, -0.07, 0), metal)
		"straight_short":
			_box(mag, Vector3(0.028, 0.1, 0.065), Vector3(0, -0.05, 0), metal)
		"curved", "curved_thin":
			var w := 0.022 if p["mag"] == "curved_thin" else 0.028
			for i in 4:
				_box(mag, Vector3(w, 0.05, 0.06), Vector3(0, -0.025 - i * 0.042, -i * 0.012 - i * i * 0.004), mat("metal") if p.get("wood", false) or id == "ak74" else metal, "", false, Vector3(-i * 0.14, 0, 0))
		"translucent":
			_box(mag, Vector3(0.026, 0.13, 0.06), Vector3(0, -0.065, -0.01), mat("translucent"), "", false, Vector3(-0.15, 0, 0))
		"drum":
			_cyl(mag, 0.07, 0.06, Vector3(0, -0.08, 0), metal, false).rotation = Vector3(0, 0, PI * 0.5)
		"box":
			_box(mag, Vector3(0.09, 0.1, 0.1), Vector3(-0.05, -0.06, 0), mat("olive_drab"))
		"top":
			_box(mag, Vector3(0.045, 0.025, 0.3), Vector3(0, 0.11, -0.1), mat("translucent"))
		"grip":
			mag.position = Vector3(0, -0.04, 0.02)
			_box(mag, Vector3(0.025, 0.12, 0.035), Vector3(0, -0.06, 0), metal)
		"grip_front":
			_box(mag, Vector3(0.025, 0.14, 0.035), Vector3(0, -0.07, -0.08), metal)
	_marker(root, "Muzzle", Vector3(0, 0.075, muzzle_z))
	_marker(root, "Optic", Vector3(0, top_y + 0.012, rec_z - L * 0.05))
	_marker(root, "Underbarrel", Vector3(0, 0.06 - rh * 0.5, front_z - hand_len * 0.45))
	_marker(root, "LeftHand", Vector3(0, 0.03, front_z - hand_len * 0.4))
	var ads_y := top_y + (0.035 if p["sight"] in ["carry", "handle"] else 0.02)
	if p["sight"] == "scope":
		ads_y = top_y + 0.04
	_marker(root, "ADS", Vector3(0, ads_y, rec_z + L * 0.35))
	return root


static func _build_pistol(root: Node3D, p: Dictionary) -> void:
	var metal := mat("metal")
	var revolver: bool = p.get("revolver", false)
	var slide_len := 0.19 if not p.get("long", false) else 0.23
	_box(root, Vector3(0.03, 0.035, slide_len), Vector3(0, 0.06, -slide_len * 0.4), metal, "Body", true)
	_box(root, Vector3(0.028, 0.025, slide_len * 0.85), Vector3(0, 0.035, -slide_len * 0.38), mat("polymer"))
	_box(root, Vector3(0.028, 0.11, 0.045), Vector3(0, -0.02, 0.0), mat("polymer"), "", false, Vector3(0.25, 0, 0))
	if revolver:
		_cyl(root, 0.022, 0.05, Vector3(0, 0.05, -0.03), metal)
		_cyl(root, 0.009, 0.2, Vector3(0, 0.06, -0.16), metal)
	var mag := Node3D.new()
	mag.name = "Mag"
	root.add_child(mag)
	mag.position = Vector3(0, -0.02, 0.0)
	if not revolver:
		_box(mag, Vector3(0.022, 0.09, 0.035), Vector3(0, -0.04, 0), metal)
	_box(root, Vector3(0.006, 0.012, 0.008), Vector3(0, 0.083, -slide_len * 0.85), metal)
	_box(root, Vector3(0.02, 0.012, 0.008), Vector3(0, 0.083, 0.03), metal)
	var muzzle_z := -slide_len * 0.9 if not revolver else -0.26
	_marker(root, "Muzzle", Vector3(0, 0.06, muzzle_z))
	_marker(root, "Optic", Vector3(0, 0.078, -0.05))
	_marker(root, "Underbarrel", Vector3(0, 0.02, -0.12))
	_marker(root, "LeftHand", Vector3(0, -0.02, 0.0))
	_marker(root, "ADS", Vector3(0, 0.09, 0.05))


static func _build_launcher(root: Node3D, kind: String) -> void:
	var metal := mat("metal")
	match kind:
		"rpg":
			_cyl(root, 0.03, 0.95, Vector3(0, 0.08, -0.15), metal)
			_cyl(root, 0.034, 0.25, Vector3(0, 0.08, -0.05), mat("wood"))
			var warhead := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.05
			cone.height = 0.22
			warhead.mesh = cone
			warhead.material_override = mat("olive_drab")
			warhead.rotation = Vector3(-PI * 0.5, 0, 0)
			warhead.position = Vector3(0, 0.08, -0.75)
			warhead.name = "Mag"
			root.add_child(warhead)
			_box(root, Vector3(0.03, 0.1, 0.04), Vector3(0, 0.0, 0.0), mat("wood"))
			_box(root, Vector3(0.03, 0.1, 0.04), Vector3(0, 0.0, -0.2), mat("wood"))
			_marker(root, "Muzzle", Vector3(0, 0.08, -0.65))
		"tube":
			_cyl(root, 0.045, 1.0, Vector3(0, 0.09, -0.2), mat("olive_drab"), true, true)
			_box(root, Vector3(0.03, 0.1, 0.04), Vector3(0, 0.0, 0.0), mat("polymer"))
			_box(root, Vector3(0.03, 0.06, 0.08), Vector3(-0.05, 0.14, -0.1), metal)
			var m := Node3D.new()
			m.name = "Mag"
			root.add_child(m)
			_marker(root, "Muzzle", Vector3(0, 0.09, -0.7))
		"break":
			_cyl(root, 0.025, 0.35, Vector3(0, 0.07, -0.25), metal)
			_box(root, Vector3(0.04, 0.06, 0.12), Vector3(0, 0.06, -0.02), metal)
			_box(root, Vector3(0.04, 0.09, 0.3), Vector3(0, 0.02, 0.18), mat("wood"))
			_box(root, Vector3(0.03, 0.1, 0.04), Vector3(0, -0.02, 0.02), mat("wood"))
			var m2 := Node3D.new()
			m2.name = "Mag"
			root.add_child(m2)
			_marker(root, "Muzzle", Vector3(0, 0.07, -0.43))
	_marker(root, "Optic", Vector3(0, 0.14, -0.1))
	_marker(root, "Underbarrel", Vector3(0, 0.0, -0.3))
	_marker(root, "LeftHand", Vector3(0, 0.03, -0.3))
	_marker(root, "ADS", Vector3(-0.0, 0.16, 0.05))


# --- Attachments -------------------------------------------------------------

static func _add_attachments(root: Node3D, attachments: Array, data: WeaponData) -> void:
	for att: String in attachments:
		var path := "res://assets/attachments/%s.glb" % att
		var node: Node3D
		if ResourceLoader.exists(path):
			node = (load(path) as PackedScene).instantiate()
		else:
			node = _procedural_attachment(att)
		if node == null:
			continue
		node.name = "Att_" + att
		var marker_name := "Optic"
		if att in ["suppressor"]:
			marker_name = "Muzzle"
		elif att in ["underbarrel_gl", "underbarrel_shotgun", "grip"]:
			marker_name = "Underbarrel"
		elif att in ["pulse_tracker"]:
			marker_name = "Underbarrel"
		elif att in ["fmj", "ext_mag", "rapid_fire", "akimbo", "tactical_knife"]:
			if att == "ext_mag":
				var mag := root.find_child("Mag", true, false) as Node3D
				if mag:
					mag.scale = Vector3(1.0, 1.35, 1.0)
			node.queue_free()
			continue
		var marker := root.find_child(marker_name, true, false) as Node3D
		if marker == null:
			node.queue_free()
			continue
		marker.add_child(node)
		if att == "suppressor":
			# Mark the end of the suppressor for flashes/tracers.
			var tip := Node3D.new()
			tip.name = "MuzzleTip"
			node.add_child(tip)
			tip.position = Vector3(0, 0, -0.18)
		if att in ["reflex", "holo", "marksman_scope", "thermal"]:
			var ads := root.find_child("ADS", true, false) as Node3D
			var eye := node.find_child("Eye", true, false) as Node3D
			if ads and eye:
				ads.position = marker.position + eye.position


static func _procedural_attachment(att: String) -> Node3D:
	var n := Node3D.new()
	var metal := mat("metal")
	match att:
		"reflex":
			_box(n, Vector3(0.03, 0.015, 0.05), Vector3(0, 0.008, 0), metal)
			_box(n, Vector3(0.03, 0.035, 0.006), Vector3(0, 0.03, -0.02), metal)
			_box(n, Vector3(0.024, 0.026, 0.002), Vector3(0, 0.03, -0.017), mat("glass"))
			var dot := _box(n, Vector3(0.002, 0.002, 0.001), Vector3(0, 0.032, -0.016), mat("red_light"))
			dot.name = "Reticle"
			_marker(n, "Eye", Vector3(0, 0.032, 0.0))
		"holo":
			_box(n, Vector3(0.04, 0.02, 0.09), Vector3(0, 0.01, 0), metal)
			_box(n, Vector3(0.04, 0.04, 0.006), Vector3(0, 0.04, -0.035), metal)
			_box(n, Vector3(0.04, 0.04, 0.006), Vector3(0, 0.04, 0.035), metal)
			_box(n, Vector3(0.034, 0.03, 0.002), Vector3(0, 0.04, -0.03), mat("glass"))
			_marker(n, "Eye", Vector3(0, 0.04, 0.0))
		"marksman_scope", "thermal":
			_box(n, Vector3(0.03, 0.02, 0.06), Vector3(0, 0.01, 0), metal)
			_cyl(n, 0.02, 0.14, Vector3(0, 0.04, 0), metal)
			_cyl(n, 0.024, 0.03, Vector3(0, 0.04, -0.07), metal)
			if att == "thermal":
				_box(n, Vector3(0.05, 0.05, 0.12), Vector3(0, 0.045, 0), mat("polymer"))
			_marker(n, "Eye", Vector3(0, 0.04, 0.0))
		"suppressor":
			_cyl(n, 0.019, 0.18, Vector3(0, 0, -0.09), metal)
		"underbarrel_gl":
			_cyl(n, 0.022, 0.2, Vector3(0, -0.035, 0), metal)
			_box(n, Vector3(0.03, 0.03, 0.12), Vector3(0, -0.01, 0), metal)
		"underbarrel_shotgun":
			_cyl(n, 0.015, 0.25, Vector3(0, -0.03, -0.02), metal)
			_box(n, Vector3(0.025, 0.025, 0.1), Vector3(0, -0.01, 0.02), metal)
		"grip":
			_box(n, Vector3(0.022, 0.08, 0.025), Vector3(0, -0.045, 0), mat("polymer"))
		"pulse_tracker":
			_box(n, Vector3(0.05, 0.04, 0.06), Vector3(0, -0.03, 0.05), mat("polymer"))
			var screen := _box(n, Vector3(0.045, 0.032, 0.002), Vector3(0, -0.025, 0.081), mat("red_light"))
			screen.name = "Screen"
		_:
			return null
	return n


# --- Equipment ---------------------------------------------------------------

static func create_equipment(kind: String) -> Node3D:
	var path := "res://assets/equipment/%s.glb" % kind
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	var n := Node3D.new()
	var metal := mat("metal")
	match kind:
		"shard_grenade":
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.04
			sm.height = 0.085
			s.mesh = sm
			s.material_override = mat("olive_drab")
			n.add_child(s)
			_cyl(n, 0.012, 0.03, Vector3(0, 0.045, 0), metal, false)
			_box(n, Vector3(0.01, 0.06, 0.012), Vector3(0.02, 0.03, 0), metal)
		"sticky_charge":
			_cyl(n, 0.03, 0.08, Vector3.ZERO, mat("olive_drab"), false)
			_box(n, Vector3(0.012, 0.012, 0.012), Vector3(0, 0.045, 0), mat("red_light"))
		"hatchet":
			_box(n, Vector3(0.018, 0.018, 0.3), Vector3(0, 0, 0.05), mat("polymer"))
			_box(n, Vector3(0.006, 0.08, 0.06), Vector3(0, 0.03, -0.1), metal)
		"tripwire_mine":
			_box(n, Vector3(0.2, 0.1, 0.04), Vector3(0, 0.1, 0), mat("olive_drab"), "", false, Vector3(0, 0, 0))
			_box(n, Vector3(0.01, 0.06, 0.01), Vector3(-0.07, 0.03, 0), metal)
			_box(n, Vector3(0.01, 0.06, 0.01), Vector3(0.07, 0.03, 0), metal)
			_box(n, Vector3(0.012, 0.012, 0.012), Vector3(0, 0.16, -0.02), mat("red_light"))
		"breach_charge":
			_box(n, Vector3(0.12, 0.05, 0.08), Vector3.ZERO, mat("olive_drab"))
			_box(n, Vector3(0.004, 0.08, 0.004), Vector3(0.04, 0.06, 0), metal)
			_box(n, Vector3(0.012, 0.012, 0.012), Vector3(-0.03, 0.03, 0), mat("red_light"))
		"spawn_beacon":
			_cyl(n, 0.03, 0.18, Vector3(0, 0.09, 0), mat("polymer"), false)
			_box(n, Vector3(0.025, 0.025, 0.025), Vector3(0, 0.2, 0), mat("red_light"))
		"flash_pop", "dazer", "smoke_canister":
			var c := mat("metal")
			if kind == "smoke_canister":
				c = mat("green")
			elif kind == "dazer":
				c = mat("olive_drab")
			_cyl(n, 0.025, 0.11, Vector3.ZERO, c, false)
			_cyl(n, 0.012, 0.02, Vector3(0, 0.065, 0), metal, false)
		"rocket":
			_cyl(n, 0.04, 0.5, Vector3(0, 0, 0.1), mat("olive_drab"))
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.045
			cm.height = 0.18
			cone.mesh = cm
			cone.material_override = mat("olive_drab")
			cone.rotation = Vector3(-PI * 0.5, 0, 0)
			cone.position = Vector3(0, 0, -0.24)
			n.add_child(cone)
		"grenade_round":
			_cyl(n, 0.02, 0.06, Vector3.ZERO, mat("brass"))
		_:
			_box(n, Vector3(0.06, 0.06, 0.06), Vector3.ZERO, metal)
	return n

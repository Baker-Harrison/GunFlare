class_name AircraftModels
## Procedural aircraft and turret models (replaced by Blender assets in
## res://assets/vehicles/<kind>.glb when present). Forward is -Z.


static func _m(c: Color, metal := 0.4, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3(PI * 0.5, 0, 0), r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func create(kind: String) -> Node3D:
	var path := "res://assets/vehicles/%s.glb" % kind
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	var n := Node3D.new()
	var grey := _m(Color(0.42, 0.44, 0.46), 0.5, 0.45)
	var dark := _m(Color(0.12, 0.13, 0.14), 0.4, 0.5)
	var olive := _m(Color(0.27, 0.3, 0.22), 0.3, 0.6)
	var glass := _m(Color(0.1, 0.15, 0.2), 0.8, 0.1)
	match kind:
		"uav", "jammer":
			_cyl(n, 0.35, 4.5, Vector3.ZERO, grey, Vector3(PI * 0.5, 0, 0), 0.25)
			_box(n, Vector3(9.0, 0.08, 0.9), Vector3(0, 0.1, 0.2), grey)
			_box(n, Vector3(2.2, 0.06, 0.5), Vector3(0, 0.0, 2.0), grey)
			_box(n, Vector3(0.06, 0.8, 0.5), Vector3(0, 0.4, 2.0), grey)
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.3
			sm.height = 0.6
			ball.mesh = sm
			ball.material_override = dark
			ball.position = Vector3(0, -0.35, -1.5)
			n.add_child(ball)
		"jet", "bomber":
			var s := 1.0 if kind == "jet" else 1.8
			_cyl(n, 0.7 * s, 14.0 * s, Vector3.ZERO, grey, Vector3(PI * 0.5, 0, 0), 0.5 * s)
			_box(n, Vector3(11.0 * s, 0.25, 3.5 * s), Vector3(0, -0.1, 1.0 * s), grey)
			_box(n, Vector3(4.5 * s, 0.15, 1.5 * s), Vector3(0, 0.2, 6.0 * s), grey)
			_box(n, Vector3(0.15, 2.6 * s, 2.0 * s), Vector3(0, 1.3 * s, 5.8 * s), grey, Vector3(-0.3, 0, 0))
			_box(n, Vector3(0.9 * s, 0.6 * s, 2.2 * s), Vector3(0, 0.7 * s, -3.8 * s), glass)
			var flame := _m(Color(1, 0.6, 0.3))
			flame.emission_enabled = true
			flame.emission = Color(1, 0.5, 0.2)
			flame.emission_energy_multiplier = 5.0
			_cyl(n, 0.45 * s, 1.0, Vector3(0, 0, 7.3 * s), flame)
		"drone":
			_box(n, Vector3(1.6, 0.6, 2.4), Vector3.ZERO, dark)
			for x in [-1, 1]:
				for z in [-1, 1]:
					_box(n, Vector3(0.1, 0.1, 1.4), Vector3(x * 1.1, 0.1, z * 1.1), dark, Vector3(0, PI * 0.25 * x * z, 0))
					var rotor := Node3D.new()
					rotor.name = "Rotor" if x == -1 and z == -1 else "R"
					rotor.position = Vector3(x * 1.6, 0.35, z * 1.6)
					n.add_child(rotor)
					_box(rotor, Vector3(1.6, 0.03, 0.15), Vector3.ZERO, grey)
			_cyl(n, 0.08, 0.8, Vector3(0, -0.4, -0.8), dark)
		"chopper", "transport":
			var body := olive if kind == "chopper" else _m(Color(0.32, 0.34, 0.3), 0.3, 0.6)
			_box(n, Vector3(2.2, 2.2, 6.0), Vector3(0, 0, 0), body)
			_box(n, Vector3(2.0, 1.6, 1.6), Vector3(0, -0.1, -3.6), glass)
			_cyl(n, 0.45, 7.0, Vector3(0, 0.5, 6.0), body, Vector3(PI * 0.5, 0, 0), 0.25)
			_box(n, Vector3(0.15, 2.0, 1.2), Vector3(0, 1.4, 9.2), body)
			var rotor2 := Node3D.new()
			rotor2.name = "Rotor"
			rotor2.position = Vector3(0, 1.5, 0)
			n.add_child(rotor2)
			_box(rotor2, Vector3(15.0, 0.06, 0.5), Vector3.ZERO, dark)
			_box(rotor2, Vector3(0.5, 0.06, 15.0), Vector3.ZERO, dark)
			if kind == "chopper":
				_box(n, Vector3(3.6, 0.15, 0.6), Vector3(0, -0.4, 0.5), body)
				_cyl(n, 0.2, 1.2, Vector3(1.8, -0.6, 0.3), dark)
				_cyl(n, 0.2, 1.2, Vector3(-1.8, -0.6, 0.3), dark)
			else:
				_box(n, Vector3(0.15, 0.15, 5.0), Vector3(1.1, -1.4, 0), dark)
				_box(n, Vector3(0.15, 0.15, 5.0), Vector3(-1.1, -1.4, 0), dark)
		"gunship":
			_cyl(n, 2.0, 28.0, Vector3.ZERO, grey, Vector3(PI * 0.5, 0, 0), 1.6)
			_box(n, Vector3(40.0, 0.5, 4.0), Vector3(0, 1.2, -1.0), grey)
			_box(n, Vector3(14.0, 0.3, 3.0), Vector3(0, 1.8, 12.5), grey)
			_box(n, Vector3(0.3, 6.0, 4.0), Vector3(0, 4.0, 12.5), grey)
			for x in [-12.0, -6.5, 6.5, 12.0]:
				_cyl(n, 0.7, 4.0, Vector3(x, 0.6, -2.5), dark)
				var prop := Node3D.new()
				prop.name = "Rotor" if x == -12.0 else "P"
				prop.position = Vector3(x, 0.6, -4.6)
				n.add_child(prop)
				_box(prop, Vector3(0.3, 4.0, 0.08), Vector3.ZERO, dark)
		"sentry":
			_cyl(n, 0.08, 0.9, Vector3(0, 0.45, 0), dark, Vector3.ZERO)
			for a in 3:
				_box(n, Vector3(0.06, 0.06, 0.9), Vector3(0, 0.2, 0), dark, Vector3(0.6, a * TAU / 3.0, 0))
			var head := Node3D.new()
			head.name = "Head"
			head.position = Vector3(0, 1.0, 0)
			n.add_child(head)
			_box(head, Vector3(0.4, 0.35, 0.6), Vector3.ZERO, olive)
			_cyl(head, 0.04, 0.7, Vector3(0, 0.05, -0.6), dark)
			_box(head, Vector3(0.5, 0.4, 0.04), Vector3(0, 0.1, -0.33), olive)
			var muzzle := Node3D.new()
			muzzle.name = "Muzzle"
			muzzle.position = Vector3(0, 0.05, -0.95)
			head.add_child(muzzle)
		"crate":
			var wood := _m(Color(0.45, 0.38, 0.22), 0.0, 0.85)
			_box(n, Vector3(1.4, 0.9, 1.0), Vector3(0, 0.45, 0), wood)
			for z in [-0.5, 0.5]:
				_box(n, Vector3(1.45, 0.12, 0.06), Vector3(0, 0.15, z), dark)
				_box(n, Vector3(1.45, 0.12, 0.06), Vector3(0, 0.75, z), dark)
			var lightm := _m(Color(1, 0.85, 0.3))
			lightm.emission_enabled = true
			lightm.emission = Color(1, 0.8, 0.2)
			lightm.emission_energy_multiplier = 3.0
			_box(n, Vector3(0.12, 0.12, 0.12), Vector3(0.5, 0.96, 0.3), lightm)
	return n

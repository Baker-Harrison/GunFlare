class_name WeaponShowcase
extends SubViewportContainer
## Studio-lit, slowly turning weapon preview for menus.

var _vp: SubViewport
var _pivot: Node3D
var _model: Node3D
var _cam: Camera3D
var _t := 0.0
var _id := ""
var _key := ""


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.4)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.position = Vector3(1.6, 0.35, 0.0)
	_vp.add_child(_cam)
	_cam.look_at(Vector3(0, 0.05, 0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 60, 0)
	key.light_energy = 2.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -130, 0)
	rim.light_energy = 1.6
	rim.light_color = Color(0.7, 0.85, 1.0)
	_vp.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.0, -0.5, 1.0)
	fill.light_energy = 0.6
	_vp.add_child(fill)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)


func show_weapon(weapon_id: String, attachments: Array = [], camo := "") -> void:
	var key := "%s|%s|%s" % [weapon_id, ",".join(attachments), camo]
	if key == _key:
		return
	_key = key
	if _model:
		_model.queue_free()
	_model = WeaponModels.create(weapon_id, attachments, camo)
	_pivot.add_child(_model)
	# Centre and scale to fit.
	var aabb := _aabb(_model, Transform3D.IDENTITY)
	var size := maxf(aabb.size.length(), 0.1)
	var s := 0.9 / size
	_model.scale = Vector3(s, s, s)
	_model.position = -aabb.get_center() * s


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[n, xf]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var t: Transform3D = item[1]
		if node is Node3D and node != n:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var b := t * (node as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in node.get_children():
			stack.append([c, t])
	return out


func _process(delta: float) -> void:
	_t += delta
	if _pivot:
		_pivot.rotation.y = sin(_t * 0.35) * 0.5
		_pivot.position.y = sin(_t * 0.8) * 0.01

class_name PlayerController
extends Node3D
## Drives the local player's Soldier from mouse/keyboard, owns the camera,
## the viewmodel overlay and the HUD.

signal pause_requested

var soldier: Soldier
var camera: Camera3D
var vm_viewport: SubViewport
var vm_camera: Camera3D
var viewmodel: Viewmodel
var hud: Hud
var enabled := true
## Test harness: a BotBrain drives the player; ignore local input.
var autoplay := false
var _shake := 0.0
var _shake_t := 0.0
var _death_cam_target: Node3D
var _death_time := 0.0
var _breath := 4.0
var _fov_kick := 0.0


func setup(s: Soldier, world_env: Environment) -> void:
	soldier = s
	soldier.is_player = true
	soldier.is_bot = false
	soldier.controller = self
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.cull_mask = 0xFFFFF & ~Viewmodel.LAYER
	camera.near = 0.03
	camera.far = 1500.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.current = true

	# Viewmodel overlay: a transparent viewport that only renders layer 2.
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(container)
	vm_viewport = SubViewport.new()
	vm_viewport.transparent_bg = true
	vm_viewport.handle_input_locally = false
	vm_viewport.msaa_3d = Viewport.MSAA_4X
	vm_viewport.positional_shadow_atlas_size = 1024
	container.add_child(vm_viewport)
	vm_camera = Camera3D.new()
	vm_camera.cull_mask = Viewmodel.LAYER
	vm_camera.near = 0.045
	vm_camera.far = 10.0
	vm_camera.fov = Viewmodel.FOV_HIP
	vm_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if world_env:
		var env := world_env.duplicate() as Environment
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.ssr_enabled = false
		env.sdfgi_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
		vm_camera.environment = env
	vm_viewport.add_child(vm_camera)
	vm_camera.current = true

	viewmodel = Viewmodel.new()
	viewmodel.soldier = soldier
	camera.add_child(viewmodel)
	soldier.viewmodel = viewmodel
	soldier.model.set_first_person(true)

	hud = Hud.new()
	hud.player = self
	add_child(hud)
	soldier.shot_fired.connect(func(_w: WeaponState) -> void: _fov_kick = 0.6)
	# Flinch: taking hits knocks your aim.
	soldier.damaged.connect(func(info: DamageInfo) -> void:
		add_shake(0.25 + minf(info.amount / 100.0, 1.0) * 0.4)
		var f := deg_to_rad(randf_range(0.6, 1.8)) * (0.5 if soldier.has_perk("steady_hand") else 1.0)
		soldier.pitch += f
		soldier.yaw += f * randf_range(-0.8, 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or soldier == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and soldier.alive:
		var sens: float = Settings.get_value("mouse_sensitivity")
		var w := soldier.weapon()
		if soldier.ads > 0.5:
			sens *= float(Settings.get_value("ads_sensitivity_mult")) * (w.ads_fov_mult() if w else 1.0) / 0.8
		var inv := -1.0 if Settings.get_value("invert_y") else 1.0
		var stun := 1.0 - soldier.stun_amount * 0.7
		soldier.yaw -= deg_to_rad(event.relative.x * sens) * stun
		soldier.pitch = clampf(soldier.pitch - deg_to_rad(event.relative.y * sens) * inv * stun, deg_to_rad(-85), deg_to_rad(85))
		viewmodel.add_mouse_sway(event.relative)
	if event.is_action_pressed("pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if soldier == null or autoplay:
		return
	var i := soldier.input
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not soldier.alive:
		i.move = Vector2.ZERO
		i.fire = false
		i.ads = false
		i.sprint = false
		i.lethal = false
		i.tactical = false
		return
	i.move = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward")).limit_length(1.0)
	i.fire = Input.is_action_pressed("fire")
	i.ads = Input.is_action_pressed("ads")
	i.sprint = Input.is_action_pressed("sprint") and not i.ads
	if Input.is_action_just_pressed("jump"):
		i.jump = true
	if Input.is_action_just_pressed("crouch"):
		i.crouch_pressed = true
	if Input.is_action_just_pressed("prone"):
		i.prone_pressed = true
	if Input.is_action_just_pressed("reload"):
		i.reload = true
	if Input.is_action_just_pressed("swap_weapon"):
		i.swap = true
	if Input.is_action_just_pressed("melee"):
		i.melee = true
		viewmodel.play_melee()
	if Input.is_action_just_pressed("use_streak"):
		i.use_streak = true
	if Input.is_action_just_pressed("cycle_streak") and not soldier.streak_inventory.is_empty():
		soldier.streak_index = (soldier.streak_index + 1) % soldier.streak_inventory.size()
		Sfx.play_ui("tick")
	if Input.is_action_just_pressed("toggle_attachment"):
		i.toggle_attachment = true
	var lethal_was := i.lethal
	i.lethal = Input.is_action_pressed("lethal")
	if lethal_was and not i.lethal:
		viewmodel.play_throw()
	if Input.is_action_just_pressed("tactical"):
		viewmodel.play_throw()
	i.tactical = Input.is_action_pressed("tactical")
	i.interact = Input.is_action_pressed("interact")
	# Hold breath while scoped (sprint key), like a real marksman.
	var w := soldier.weapon()
	viewmodel.hold_breath = false
	if w and w.is_scoped() and soldier.ads > 0.9 and Input.is_action_pressed("sprint") and _breath > 0.0:
		viewmodel.hold_breath = true
		_breath -= _delta
	else:
		_breath = minf(_breath + _delta * 0.5, 4.0)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 2.0)


func _process(delta: float) -> void:
	if soldier == null:
		return
	Sfx.listener_position = camera.global_position
	var w := soldier.weapon()
	var base_fov: float = Settings.get_value("fov")
	if soldier.alive:
		var head_xf := soldier.head.get_global_transform_interpolated()
		var origin := head_xf.origin
		camera.global_transform = Transform3D(Basis.from_euler(Vector3(soldier.pitch, soldier.yaw, 0.0)), origin)
		# Sniper sway when scoped and not holding breath.
		if w and w.is_scoped() and soldier.ads > 0.9 and not viewmodel.hold_breath:
			var t := Time.get_ticks_msec() / 1000.0
			var amp := deg_to_rad(0.35) * (0.4 if soldier.stance == Soldier.Stance.PRONE else 1.0)
			camera.rotate_object_local(Vector3.RIGHT, sin(t * 1.3) * amp)
			camera.rotate_object_local(Vector3.UP, sin(t * 0.9 + 1.0) * amp)
		var target_fov := base_fov
		if w:
			target_fov = lerpf(base_fov, base_fov * w.ads_fov_mult(), soldier.ads)
		if soldier.sprinting:
			target_fov += 4.0
		_fov_kick = move_toward(_fov_kick, 0.0, delta * 8.0)
		camera.fov = lerpf(camera.fov, target_fov - _fov_kick * (1.0 - soldier.ads), minf(delta * 18.0, 1.0))
	else:
		_update_death_cam(delta)
	# Shake
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 1.8)
		_shake_t += delta * 40.0
		var a := _shake * _shake * 0.02
		camera.rotate_object_local(Vector3.RIGHT, sin(_shake_t * 1.3) * a)
		camera.rotate_object_local(Vector3.FORWARD, cos(_shake_t * 0.9) * a)
	vm_camera.global_transform = camera.global_transform
	vm_camera.fov = lerpf(Viewmodel.FOV_HIP, Viewmodel.FOV_ADS, soldier.ads)
	viewmodel.visible = soldier.alive


func on_player_died(killer: Node3D) -> void:
	_death_cam_target = killer
	_death_time = 0.0


func _update_death_cam(delta: float) -> void:
	_death_time += delta
	# After a beat, cut to the killer's eyes looking at where we fell.
	var k := _death_cam_target as Soldier
	if _death_time > 1.2 and k and is_instance_valid(k) and k != soldier and k.alive:
		var eye := k.aim_origin()
		var target := soldier.global_position + Vector3.UP * 0.4
		if eye.distance_to(target) > 0.5:
			var want := Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
			if _death_time < 1.3:
				camera.global_transform = want
			else:
				camera.global_transform = camera.global_transform.interpolate_with(want, minf(delta * 6.0, 1.0))
			var w := k.weapon()
			camera.fov = lerpf(camera.fov, 45.0 if w and w.is_scoped() else 60.0, delta * 2.0)
			hud.set_killcam(k)
			return
	hud.set_killcam(null)
	# Pull up and back from the body and look at the killer.
	var body_pos := soldier.global_position + Vector3.UP * 0.5
	var cam_pos := body_pos + Vector3.UP * minf(1.0 + _death_time * 1.5, 3.5) - soldier.global_basis.z * -1.5
	camera.global_position = camera.global_position.lerp(cam_pos, minf(delta * 3.0, 1.0))
	var look := body_pos
	if _death_cam_target and is_instance_valid(_death_cam_target) and _death_cam_target != soldier:
		look = _death_cam_target.global_position + Vector3.UP * 1.4
	if camera.global_position.distance_to(look) > 0.1:
		var want := camera.global_transform.looking_at(look, Vector3.UP)
		camera.global_transform = camera.global_transform.interpolate_with(want, minf(delta * 4.0, 1.0))
	camera.fov = lerpf(camera.fov, 55.0, delta * 2.0)

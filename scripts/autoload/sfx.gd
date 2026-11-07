extends Node
## Pooled sound playback. Sounds live in res://assets/audio/<name>.wav, with
## optional variants <name>_2.wav, <name>_3.wav... picked at random.

const POOL_3D := 48
const POOL_2D := 20
const AUDIO_DIR := "res://assets/audio/"

var _streams: Dictionary = {} # name -> Array[AudioStream]
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _i3 := 0
var _i2 := 0
var _root: Node3D
var _music: AudioStreamPlayer
var listener_position := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_all()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players_2d.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)


func _ensure_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# A gentle limiter on master keeps stacked gunfire from clipping.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, lim)


func _load_all() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		var file := f.trim_suffix(".import")
		if not (file.ends_with(".wav") or file.ends_with(".ogg")):
			continue
		var base := file.get_basename()
		var key := base
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			key = parts[0]
		var s = load(AUDIO_DIR + file)
		if s == null:
			continue
		if not _streams.has(key):
			_streams[key] = []
		if not _streams[key].has(s):
			_streams[key].append(s)


func has_sound(sound_name: String) -> bool:
	return _streams.has(sound_name)


## A looping 3D emitter attached to `parent` (vehicles, turrets).
func attach_loop(parent: Node3D, sound_name: String, volume_db := 0.0, max_distance := 300.0) -> AudioStreamPlayer3D:
	var s := _pick(sound_name)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.unit_size = 12.0
	p.max_distance = max_distance
	p.autoplay = true
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
	parent.add_child(p)
	return p


func _pick(sound_name: String) -> AudioStream:
	var list: Array = _streams.get(sound_name, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()]


## World-space players live in the match world.
func attach_to(world_root: Node3D) -> void:
	_root = world_root
	_players_3d.clear()
	if world_root == null:
		return
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 220.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -18.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		world_root.add_child(p)
		_players_3d.append(p)


func play_3d(sound_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, max_distance := 220.0) -> AudioStreamPlayer3D:
	var s := _pick(sound_name)
	if s == null or _players_3d.is_empty():
		return null
	# Steal the oldest voice.
	var p := _players_3d[_i3]
	_i3 = (_i3 + 1) % _players_3d.size()
	if not is_instance_valid(p):
		return null
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.play()
	return p


func play_2d(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _pick(sound_name)
	if s == null:
		return
	var p := _players_2d[_i2]
	_i2 = (_i2 + 1) % _players_2d.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_ui(sound_name: String) -> void:
	play_2d("ui_" + sound_name, -6.0)


func play_gunshot(w: WeaponState, pos: Vector3, is_local_player: bool) -> void:
	var family := w.data.sound
	if w.alt_mode:
		family = "launcher" if w.has("underbarrel_gl") else "shotgun"
	var suppressed := w.has("suppressor") and not w.alt_mode
	var key := "gun_" + family + ("_suppressed" if suppressed else "")
	if not has_sound(key):
		key = "gun_suppressed" if suppressed and has_sound("gun_suppressed") else "gun_" + family
	if not has_sound(key):
		key = "gun_rifle"
	var pitch := randf_range(0.96, 1.04)
	if is_local_player:
		play_2d(key, -3.0 if not suppressed else -8.0, pitch)
		if not suppressed:
			play_2d("gun_tail", -14.0, pitch)
	else:
		var dist := pos.distance_to(listener_position)
		if dist > 45.0 and not suppressed and has_sound("gun_distant"):
			play_3d("gun_distant", pos, 6.0, pitch, 400.0)
		else:
			play_3d(key, pos, 0.0 if not suppressed else -10.0, pitch, 60.0 if suppressed else 300.0)


func play_music(track: String, volume_db := -6.0) -> void:
	var s := _pick("music_" + track)
	if s == null:
		_music.stop()
		return
	if _music.stream == s and _music.playing:
		return
	_music.stream = s
	_music.volume_db = volume_db
	_music.play()


func stop_music() -> void:
	_music.stop()

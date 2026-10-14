extends SceneTree
const Pool = preload("res://source_voice_pool.gd")
const World = preload("res://imported_main.gd")
const AudioMath = preload("res://source_audio_math.gd")
class LoopWorld extends World:
	func _ready() -> void:
		pass
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	if AudioMath.loop_volume(30,100,4096,false) != 3000 or AudioMath.loop_volume(30,100,8192,false) != 1976 or AudioMath.loop_volume(30,100,0,true) != 0 or AudioMath.loop_volume(400,100,4096,false) != 0:
		quit(1)
		return
	var ordinary = Pool.new()
	for index in range(4,24):
		if ordinary.allocate(false) != index:
			quit(1)
			return
	if ordinary.allocate(false) != 4:
		quit(1)
		return
	ordinary.set_pitch(4,65530)
	if ordinary.shift_pitch(4,10) != {"raw":4,"effective":4} or ordinary.shift_pitch(4,-5) != {"raw":65535,"effective":16384}:
		quit(1)
		return
	ordinary.release(4)
	if ordinary.shift_pitch(4,1).raw != 0 or not ordinary.shift_pitch(-1,100).ignored or not ordinary.shift_pitch(0,1).has("fault"):
		quit(1)
		return
	var held = Pool.new()
	for index in range(4,24):
		if held.allocate(true) != index:
			quit(1)
			return
	if held.allocate(false) != -1 or not held.release(10) or held.allocate(false) != 10 or not held.release(-1) or held.release(24):
		quit(1)
		return
	var world = LoopWorld.new()
	root.add_child(world)
	world.camera = Camera3D.new()
	world.add_child(world.camera)
	var voice := AudioStreamPlayer3D.new()
	world.add_child(voice)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	voice.stream = stream
	world.source_voice_nodes[4] = voice
	world.source_voice_pool.set_pitch(4,2048)
	if not world.shift_imported_sound_pitch(4,1024) or voice.pitch_scale != 1.5 or voice.stream != stream or world.source_voice_pool.pitch_registers[4] != 3072:
		world.free()
		quit(1)
		return
	var roots: Array = []
	roots.resize(192)
	roots.fill(0) # Zero-distance fixture never reads the root lookup entries.
	world.runtime_tables = {"distanceRoot":{"values":roots}}
	world.source_sample_volumes["fixture"] = 30
	if not world.update_imported_loop_sound({"file":"fixture"},4,Vector3.ZERO) or not is_equal_approx(voice.volume_db,linear_to_db(4834.0/16384.0)) or voice.stream != stream or voice.pitch_scale != 1.5:
		world.free()
		quit(1)
		return
	world.source_audio_muted = true
	world.update_imported_loop_sound({"file":"fixture"},4,Vector3.ZERO)
	if voice.volume_db != -INF:
		world.free()
		quit(1)
		return
	world.sound_voices.append(voice)
	world.source_voice_pool.reserved[4] = true
	world.retire_imported_voice(voice)
	if voice.stream != null or not voice.is_queued_for_deletion() or world.source_voice_nodes.has(4) or not world.sound_voices.is_empty() or not world.source_voice_pool.reserved[4] or world.source_voice_pool.pitch_registers[4] != 3072:
		world.free()
		quit(1)
		return
	world.stop_imported_audio()
	if world.source_voice_pool.reserved[4] or world.source_voice_pool.pitch_registers[4] != 3072:
		world.free()
		quit(1)
		return
	world.source_transition_state = 2
	if not world.play_imported_sound({},Vector3.ZERO) or world.play_imported_sound_voice({},Vector3.ZERO) != -1:
		world.free()
		quit(1)
		return
	world.source_transition_state = 0
	world.source_audio_master_gain = 0
	if not world.play_imported_sound({},Vector3.ZERO) or world.play_imported_sound_voice({},Vector3.ZERO) != -1:
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: source voices, retirement and accepted transition/zero-gain allocation rejection")
	quit(0)

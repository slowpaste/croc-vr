extends SceneTree
const Random = preload("res://source_random.gd")
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
class AudioWorld extends World:
	var captured: Array = []
	var stopped: Array[int] = []
	var shifted: Array = []
	var looped: Array = []
	func _ready() -> void:
		pass
	func play_imported_sound(_asset: Dictionary, _location: Vector3, volume_percent: float = 100.0, pitch_steps: int = 0, _command_scratch: bool = false) -> bool:
		captured.append({"volume":volume_percent,"pitch":pitch_steps})
		return true
	func play_imported_sound_voice(_asset: Dictionary, _location: Vector3, volume_percent: float = 100.0, pitch_steps: int = 0, _command_scratch: bool = false, _angle_override: Variant = null) -> int:
		captured.append({"volume":volume_percent,"pitch":pitch_steps})
		return 4
	func stop_imported_sound_voice(index: int) -> bool:
		stopped.append(index)
		return true
	func shift_imported_sound_pitch(index: int, delta: int) -> bool:
		shifted.append({"voice":index,"delta":delta})
		return true
	func update_imported_loop_sound(asset: Dictionary, index: int, _location: Vector3) -> bool:
		looped.append({"file":asset.file,"voice":index})
		return true
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var audio_rng = Random.new()
	if audio_rng.sound_variation(20,-12,0) != {"volume":20,"pitch":-12} or audio_rng.draws != 0:
		quit(1)
		return
	if audio_rng.sound_variation(20,-12,32767) != {"volume":-21448,"pitch":-12} or audio_rng.draws != 2 or audio_rng.accumulator != 0:
		quit(1)
		return
	var rng = Random.new()
	for expected in [0,9988,13486]:
		if rng.bounded(65536).value != expected:
			quit(1)
			return
	if rng.draws != 6 or rng.accumulator != 3636475054:
		quit(1)
		return
	if not rng.bounded(0).has("fault") or rng.draws != 8:
		quit(1)
		return
	var world = World.new()
	var a = Actor.new()
	var b = Actor.new()
	world.add_child(a)
	world.add_child(b)
	a.world = world
	b.world = world
	a.vm.configure({"instructions":[]},0,a)
	b.vm.configure({"instructions":[]},0,b)
	var expression := [{"op":4,"value":65536},{"op":25},{"op":18}]
	if a.vm.evaluate(expression) != 0 or b.vm.evaluate(expression) != 9988 or world.source_random.draws != 4:
		world.free()
		quit(1)
		return
	world.free()
	var audio_world = AudioWorld.new()
	root.add_child(audio_world)
	var voice = Actor.new()
	audio_world.add_child(voice)
	voice.world = audio_world
	voice.handles.append({"audio":true,"file":"fixture"})
	voice.vm.configure({"instructions":[]},0,voice)
	var args := [4,[{"op":4,"value":65536},{"op":18}],[{"op":4,"value":20 << 16},{"op":18}],[{"op":4,"value":-786432},{"op":18}],[{"op":4,"value":32767 << 16},{"op":18}]]
	if voice.asl_command({"op":9,"args":args},voice.vm) != "continue" or audio_world.captured != [{"volume":-21448.0,"pitch":-12}] or audio_world.source_random.draws != 2:
		audio_world.free()
		quit(1)
		return
	var sound_expression := [{"op":19,"kind":9,"mode":4,"args":[[{"op":4,"value":65536},{"op":18}],[{"op":4,"value":1310720},{"op":18}],[{"op":4,"value":-786432},{"op":18}],[{"op":4,"value":65536},{"op":25},{"op":18}]]},{"op":18}]
	if voice.vm.evaluate(sound_expression) != 4 or audio_world.captured.back() != {"volume":20.0,"pitch":-12} or audio_world.source_random.draws != 4:
		audio_world.free()
		quit(1)
		return
	if voice.asl_command({"op":10,"args":[[{"op":4,"value":4},{"op":18}]]},voice.vm) != "continue" or audio_world.stopped != [4]:
		audio_world.free()
		quit(1)
		return
	if voice.asl_command({"op":161,"args":[[{"op":4,"value":4},{"op":18}],[{"op":4,"value":-786432},{"op":18}]]},voice.vm) != "continue" or audio_world.shifted != [{"voice":4,"delta":-12}]:
		audio_world.free()
		quit(1)
		return
	if voice.asl_command({"op":147,"args":[[{"op":4,"value":65536},{"op":18}],[{"op":4,"value":4},{"op":18}]]},voice.vm) != "continue" or audio_world.looped != [{"file":"fixture","voice":4}]:
		audio_world.free()
		quit(1)
		return
	audio_world.free()
	print("PASS: source BIOS random sequence, two-draw accumulator, zero-bound trap and shared actor stream")
	quit(0)

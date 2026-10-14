extends AudioStreamPlayer
const Mix = preload("res://source_spu_voice_mix.gd")
const Retirement = preload("res://source_spu_stream_retirement.gd")
signal pcm_completed
var pcm := PackedByteArray()
var cursor := 0
var channels := Vector2i.ZERO
var generator_playback: AudioStreamGeneratorPlayback = null
var submitted := 0
var last_submitted := PackedVector2Array()
var automatic := false
var capacity := 0
var completed := false
var loop_begin := 0
var loop_end := 0
var looping := false
var loop_count := 0
var pitch_register := 4096
var zero_pitch := false
var retirement: Node = null
func start_pcm(wav: AudioStreamWAV, left: int, right: int, auto_pump: bool = false, source_pitch: int = 4096) -> bool:
	if wav == null or wav.stereo or wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.data.is_empty() or wav.data.size()%2 != 0 or wav.mix_rate <= 0: return false
	if wav.loop_mode not in [AudioStreamWAV.LOOP_DISABLED,AudioStreamWAV.LOOP_FORWARD]: return false
	if wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and (wav.loop_begin < 0 or wav.loop_begin >= wav.loop_end or wav.loop_end > int(wav.data.size()/2)): return false
	stop_pcm()
	retirement = Retirement.owner(get_tree())
	pcm = wav.data;channels = Vector2i(left,right);cursor = 0;submitted = 0
	looping = wav.loop_mode == AudioStreamWAV.LOOP_FORWARD
	loop_begin = wav.loop_begin;loop_end = wav.loop_end;loop_count = 0
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = wav.mix_rate;generator.buffer_length = 0.04
	stream = generator;play();generator_playback = get_stream_playback()
	automatic = auto_pump;completed = false
	set_source_pitch(source_pitch)
	capacity = generator_playback.get_frames_available() if generator_playback != null else 0
	if OS.get_cmdline_user_args().has("--trace-voice-lifetime") and generator_playback != null:
		print("VOICE_START: node=",get_instance_id()," playback=",generator_playback.get_instance_id())
	if automatic and not zero_pitch: pump(4096)
	return generator_playback != null
func _process(_delta: float) -> void:
	if not automatic or generator_playback == null or zero_pitch: return
	pump(4096)
	if not looping and cursor == int(pcm.size()/2) and submitted > 0 and generator_playback.get_frames_available() >= capacity:
		stop_pcm();completed = true;pcm_completed.emit()
func pump(limit: int = 1024) -> int:
	if generator_playback == null or limit <= 0 or zero_pitch: return 0
	var remaining := mini(limit,generator_playback.get_frames_available())
	var total := 0
	while remaining > 0:
		var end := loop_end if looping else int(pcm.size()/2)
		if looping and cursor == end: cursor = loop_begin;loop_count += 1
		var count := mini(remaining,end-cursor)
		if count <= 0: break
		var mixed := Mix.mono16_block(pcm,cursor,count,channels.x,channels.y)
		if mixed.has("fault") or not generator_playback.push_buffer(mixed.frames): break
		last_submitted = mixed.frames;cursor += count;submitted += count;total += count;remaining -= count
	return total
func set_channels(left: int, right: int) -> void:
	channels = Vector2i(left,right)
func set_source_pitch(value: int) -> bool:
	if stream == null or not stream is AudioStreamGenerator: return false
	pitch_register = value&65535
	var effective := mini(pitch_register,16384)
	zero_pitch = effective == 0
	pitch_scale = float(maxi(effective,1))*44100.0/4096.0/float(stream.mix_rate)
	stream_paused = zero_pitch
	return true
func stop_pcm() -> void:
	if generator_playback == null and stream == null:
		automatic = false;looping = false
		return
	if OS.get_cmdline_user_args().has("--trace-voice-lifetime") and generator_playback != null:
		print("VOICE_STOP: node=",get_instance_id()," playback=",generator_playback.get_instance_id())
	if generator_playback != null and is_instance_valid(retirement): retirement.retain(stream,generator_playback)
	stop();automatic = false;looping = false;generator_playback = null;stream = null;pcm = PackedByteArray();last_submitted = PackedVector2Array()
func _exit_tree() -> void: stop_pcm()

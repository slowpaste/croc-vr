extends AudioStreamPlayer
const Reader = preload("res://source_xa_channel_reader.gd")
const Mix = preload("res://source_cd_mix.gd")
const Zigzag = preload("res://source_xa_zigzag.gd")
const Worker = preload("res://source_xa_worker.gd")
const Retirement = preload("res://source_spu_stream_retirement.gd")
var retirement: Node = null
var worker: RefCounted = null
var worker_content := ""
var interpolator: RefCounted = null
var cd_mix: Array = [] # Explicit source routing; empty keeps diagnostic raw PCM.
func set_cd_mix(values: Array) -> bool:
	if values.size() != 4: return false
	for value in values:
		if not value is int or value < 0 or value > 255: return false
	cd_mix = values.duplicate()
	return true
var reader := Reader.new()
var playback: AudioStreamGeneratorPlayback = null
var pending := PackedVector2Array()
var pending_offset := 0
var queued_frames := 0
var end_of_channel := false
var stream_fault := ""
var decoded_tail: Dictionary = {} # Producer checkpoint; not an audible/CD cursor.
func pending_output(amount: int) -> PackedVector2Array:
	var output := pending.slice(pending_offset,pending_offset+amount)
	if not cd_mix.is_empty():
		for frame in range(output.size()):
			output[frame] = Mix.frame(roundi(output[frame].x*32768.0),roundi(output[frame].y*32768.0),cd_mix)
	return output
func _exit_tree() -> void:
	stop_stream()
func start_stream(content_root: String, record: Dictionary, source_sector: int, predictor_history: Array, interpolation_state: Dictionary = {}, threaded: bool = false) -> bool:
	if not Reader.valid_history(predictor_history): return false
	if not interpolation_state.is_empty() and (int(record.get("sampleRate",0)) != 37800 or not Zigzag.valid_snapshot(interpolation_state)): return false
	stop_stream()
	retirement = Retirement.owner(get_tree())
	if not interpolation_state.is_empty():
		interpolator = Zigzag.new()
		interpolator.restore(interpolation_state)
	if not reader.open_channel(content_root,record) or reader.seek_sector(source_sector,predictor_history).has("fault"):
		stop_stream()
		return false
	if threaded:
		worker = Worker.new()
		worker_content = content_root
		if worker.start(content_root,record,source_sector,predictor_history,interpolation_state) != OK:
			stop_stream()
			return false
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = 44100.0 if interpolator != null else float(record.sampleRate)
	generator.buffer_length = 0.25
	stream = generator
	play()
	playback = get_stream_playback()
	return playback != null
func seek_stream(source_sector: int, predictor_history: Array, interpolation_state: Dictionary = {}) -> Dictionary:
	if playback == null:
		return {"fault":"No native XA streaming playback"}
	if interpolator != null and not Zigzag.valid_snapshot(interpolation_state):
		return {"fault":"Interpolated XA seek requires explicit valid filter history"}
	var mapped := reader.seek_sector(source_sector,predictor_history)
	if mapped.has("fault"):
		return mapped
	if interpolator != null: interpolator.restore(interpolation_state)
	if worker != null:
		if worker.start(worker_content,reader.record,source_sector,predictor_history,interpolation_state) != OK:
			return {"fault":"XA worker seek restart failed"}
	# Restart playback to clear both generator FIFO and resampler's cached frames.
	retain_playback()
	stop()
	playback = null
	pending = PackedVector2Array()
	pending_offset = 0
	queued_frames = 0
	end_of_channel = false
	decoded_tail.clear()
	play()
	playback = get_stream_playback()
	if playback == null:
		return {"fault":"Native XA streaming seek restart failed"}
	stream_fault = ""
	return mapped
func pump(maximum_sectors: int = 4) -> Dictionary:
	if not stream_fault.is_empty(): return {"fault":stream_fault}
	if playback == null:
		return {"fault":"No native XA streaming playback"}
	var decoded := 0
	var pushed := 0
	var packet_receipts: Array=[]
	while playback.get_frames_available() > 0:
		if pending_offset >= pending.size():
			pending = PackedVector2Array()
			pending_offset = 0
			if end_of_channel or decoded >= maximum_sectors:
				break
			var result: Dictionary = worker.take() if worker != null else reader.read_sector()
			if result.is_empty(): break # Producer is still preparing the next packet.
			if result.has("fault"):
				stream_fault = str(result.fault)
				return result
			if bool(result.get("end",false)):
				end_of_channel = true
				if bool(result.get("cue_boundary",false)):packet_receipts.append({"boundary":true})
				break
			if interpolator != null and worker == null:
				var source_sector := int(result.source_sector)
				result = interpolator.process_pcm(result.pcm,int(result.rate))
				if result.has("fault"):
					stream_fault = str(result.fault)
					return result
				result.source_sector = source_sector
			decoded_tail = {"source_sector":int(result.source_sector),"predictor_history":result.get("predictor_history",reader.history_snapshot()).duplicate(true)}
			packet_receipts.append({"boundary":false})
			if interpolator != null:
				decoded_tail.interpolation_state = result.get("interpolation_state",interpolator.snapshot()).duplicate(true)
			pending.resize(int(result.frames))
			for frame in range(pending.size()):
				var left := int(result.pcm.decode_s16(frame*4))
				var right := int(result.pcm.decode_s16(frame*4+2))
				pending[frame] = Vector2(left,right)/32768.0
			decoded += 1
		var amount := mini(playback.get_frames_available(),pending.size()-pending_offset)
		if amount <= 0: break
		if not playback.push_buffer(pending_output(amount)):
			stream_fault = "Native XA streaming buffer rejected available frames"
			return {"fault":stream_fault}
		pending_offset += amount
		queued_frames += amount
		pushed += amount
	return {"decoded_sectors":decoded,"pushed_frames":pushed,"end":end_of_channel,"pending_frames":pending.size()-pending_offset,"packet_receipts":packet_receipts}
func retain_playback() -> void:
	if playback != null and stream != null and is_instance_valid(retirement): retirement.retain(stream,playback)
func stop_stream() -> void:
	retain_playback()
	stop()
	stream_fault = ""
	if worker != null:
		worker.stop()
		worker = null
	worker_content = ""
	interpolator = null
	playback = null
	stream = null
	reader.close_channel()
	pending = PackedVector2Array()
	pending_offset = 0
	queued_frames = 0
	end_of_channel = false
	decoded_tail.clear()

extends RefCounted
const Selection = preload("res://source_music_selection.gd")
const Callback = preload("res://source_music_callback.gd")
const Stop = preload("res://source_music_stop.gd")
const Fade = preload("res://source_cd_fade.gd")
const Poll = preload("res://source_music_poll.gd")
const VM = preload("res://asl_vm.gd")
var rooms: Dictionary = {}
var previous := {"cue":0,"room":0}
var current: Dictionary = {}
var bootstrap_bounds: Array = []
func initialize_bootstrap(data: Dictionary) -> bool:
	var values: Variant = data.get("endSectorOffsets")
	if not values is Array or values.size() != 70: return false
	var bounds: Array = []
	for value in values:
		if not (value is int or value is float): return false
		if is_nan(float(value)) or is_inf(float(value)) or value < 0 or value > 4294967295: return false
		if float(value) != float(int(value)): return false
		bounds.append(int(value))
	bootstrap_bounds = bounds
	return true
func prepare_bootstrap(request: Dictionary, pairs: Array, streams: Array, mode8_channels: Array = [], enabled: bool = true) -> Dictionary:
	if not enabled: return {"ignored":true,"events":[]}
	if bootstrap_bounds.size() != 70: return {"fault":"Original EXCLUDE music bootstrap has not been initialized"}
	return prepare(request,pairs,bootstrap_bounds,streams,mode8_channels)
func prepare(request: Dictionary, pairs: Array, bounds: Array, streams: Array, mode8_channels: Array = [], enabled: bool = true) -> Dictionary:
	# Play510b0 returns before validation/cursor/bookkeeping when gp2032 is0.
	if not enabled: return {"ignored":true,"events":[]}
	var plan := Selection.plan(request,previous,rooms,pairs,bounds,streams,mode8_channels)
	if plan.has("fault"):
		return plan
	previous.cue = int(plan.cue) # Native Play records the requested cue, not XA ID.
	var room: Dictionary = rooms.get(int(plan.room),{"start":0,"variant":0})
	current = plan.duplicate(true)
	current.merge({"active":1,"cursor":int(plan.start_sector),"mode":int(request.mode),"room_start":int(room.start),"room_variant":int(room.variant),"seek_phase":0,"completion_pending":0,"events":[]})
	return current
func receive(reason: int, sector_step: int = 8, polled_cursor: Variant = null) -> Dictionary:
	if current.is_empty():
		return {"fault":"No original music request is prepared"}
	current = Callback.advance(current,reason,sector_step,polled_cursor)
	if current.events.has("fade_mix") and current.has("mix_counter"):
		var mix := Fade.advance_callback(int(current.mix_counter),int(current.mix_decrement),int(current.stereo_flag),int(current.active))
		current.mix_counter = int(mix.counter)
		current.active = int(mix.active)
		if bool(mix.changed): current.mix = mix.mix
	if current.events.has("restore_mix") and current.has("configured_volume"):
		initialize_mix(int(current.configured_volume),int(current.stereo_flag))
	if current.events.has("complete"):
		commit_room_state()
	return current
func receive_cd(reason: int, display_frame: int, sync_result: int, last_command: int, response: PackedByteArray) -> Dictionary:
	if current.is_empty(): return {"fault":"No original music request is prepared"}
	var polled := {"events":[],"cursor":null}
	if reason == 1 and int(current.active) not in [0,2]:
		polled = Poll.advance(display_frame,sync_result,last_command,response)
		if polled.has("fault"): return polled
	var result := receive(reason,8,polled.cursor)
	# Poll50be8 runs after the sector increment and before end/fade decisions.
	for index in range(polled.events.size()): result.events.insert(index+1,polled.events[index])
	return result
func initialize_mix(volume: int, stereo_flag: int) -> Dictionary:
	if current.is_empty():
		return {"fault":"No original music request is prepared"}
	var restored := Fade.restore(volume,stereo_flag)
	current.merge({"configured_volume":volume,"mix_counter":int(restored.counter),"mix_decrement":int(restored.decrement),"stereo_flag":stereo_flag,"mix":restored.mix},true)
	return current
func configure_mix(counter: int, decrement: int, stereo_flag: int) -> Dictionary:
	if current.is_empty():
		return {"fault":"No original music request is prepared"}
	current.merge({"mix_counter":counter,"mix_decrement":decrement,"stereo_flag":stereo_flag},true)
	return current
func adjust_volume(delta: int) -> Dictionary:
	if not current.has("configured_volume"):
		return {"fault":"Original music volume has not been initialized"}
	var adjusted := Fade.adjust(int(current.configured_volume),delta,int(current.stereo_flag))
	return initialize_mix(int(adjusted.volume),int(current.stereo_flag))
func acknowledge_read(accepted: bool) -> Dictionary:
	if current.is_empty():
		return {"fault":"No original music read request is prepared"}
	# Read51f64..51fbc: only accepted CD command updates cursor and seek phase.
	if accepted:
		current.cursor = int(current.start_sector)
		current.seek_phase = VM.signed32(int(current.seek_phase)+1)
	return {"accepted":accepted,"cursor":int(current.cursor),"seek_phase":int(current.seek_phase)}
func stop_music(enabled: bool) -> Dictionary:
	if current.is_empty():
		return {"fault":"No original music request is prepared"}
	current = Stop.apply(current,enabled)
	if enabled:
		commit_room_state()
	return current
func commit_room_state() -> void:
	if int(current.mode) != 4:
		return
	rooms[int(current.room)] = {"start":int(current.room_start),"variant":int(current.room_variant)}
	if current.has("last_room"):
		previous.room = int(current.last_room)

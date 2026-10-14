extends Node
const Session = preload("res://source_music_session.gd")
const Player = preload("res://source_xa_stream_player.gd")
var session := Session.new()
var player := Player.new()
var pending_start_read := false
static func validate_options_mix(option_volume: int, stereo_flag: int, mix_state: Dictionary) -> Dictionary:
	if option_volume < 0 or option_volume > 127 or stereo_flag not in [0,1,2] or not mix_state.has_all(["counter","decrement","mix"]):
		return {"fault":"Invalid Options CD mix state"}
	var expected := preload("res://source_cd_fade.gd").restore(int(mix_state.counter),stereo_flag)
	if int(mix_state.counter) < 0 or int(mix_state.counter) > 127 or int(mix_state.decrement) != int(expected.decrement) or mix_state.mix != expected.mix:
		return {"fault":"Options CD mix differs from original helper state"}
	return {"valid":true}
func apply_options_events(events: Array) -> Dictionary:
	if events.is_empty(): return {"applied":0}
	if session.current.is_empty(): return {"fault":"No original music request is prepared"}
	for event in events:
		if not event is Dictionary or not event.has_all(["option_volume","stereo_flag"]): return {"fault":"Incomplete Options mix event"}
		var valid := validate_options_mix(int(event.option_volume),int(event.stereo_flag),event)
		if valid.has("fault"): return valid
	for event in events:
		var applied := apply_options_mix(int(event.option_volume),int(event.stereo_flag),event)
		if applied.has("fault"): return applied
	return {"applied":events.size()}
func apply_options_mix(option_volume: int, stereo_flag: int, mix_state: Dictionary) -> Dictionary:
	if session.current.is_empty(): return {"fault":"No original music request is prepared"}
	var valid := validate_options_mix(option_volume,stereo_flag,mix_state)
	if valid.has("fault"): return valid
	if not player.set_cd_mix(mix_state.mix): return {"fault":"Options CD mix application failed"}
	# Retain the displayed option separately from pre-rounding helper mix.
	# Update routing without seeking, restarting or discarding queued decoding.
	session.current.merge({"configured_volume":option_volume,"mix_counter":int(mix_state.counter),"mix_decrement":int(mix_state.decrement),"stereo_flag":stereo_flag,"mix":mix_state.mix.duplicate()},true)
	return {"applied":true,"mix":player.cd_mix.duplicate()}
func _init() -> void:
	add_child(player)
func _exit_tree() -> void:
	player.stop_stream()
func start_read(content: String, predictor_history: Array, interpolation_state: Dictionary) -> Dictionary:
	if session.current.is_empty(): return {"fault":"No original music request is prepared"}
	if not session.current.has("mix"): return {"fault":"Original CD mix is not initialized"}
	if not player.set_cd_mix(session.current.mix): return {"fault":"Invalid original CD mix"}
	var accepted := player.start_stream(content,session.current.stream,int(session.current.start_sector),predictor_history,interpolation_state,true)
	if accepted: pending_start_read = false
	return session.acknowledge_read(accepted)
func seek_read(predictor_history: Array, interpolation_state: Dictionary) -> Dictionary:
	if session.current.is_empty(): return {"fault":"No original music request is prepared"}
	var result := player.seek_stream(int(session.current.start_sector),predictor_history,interpolation_state)
	var acknowledgment := session.acknowledge_read(not result.has("fault"))
	if not result.has("fault"): pending_start_read = false
	if result.has("fault"): acknowledgment.fault = result.fault
	return acknowledgment
func stop_music(enabled: bool) -> Dictionary:
	var result := session.stop_music(enabled)
	if not result.has("fault") and result.events.has("pause"):
		pending_start_read = false
		player.stop_stream()
	return result
func receive(reason: int, sector_step: int = 8, polled_cursor: Variant = null) -> Dictionary:
	return apply_callback(session.receive(reason,sector_step,polled_cursor))
func receive_cd(reason: int, display_frame: int, sync_result: int, last_command: int, response: PackedByteArray) -> Dictionary:
	return apply_callback(session.receive_cd(reason,display_frame,sync_result,last_command,response))
func apply_callback(result: Dictionary) -> Dictionary:
	if result.has("fault"): return result
	if result.events.has("pause"):
		pending_start_read = false
		player.stop_stream()
	if result.events.has("read_start") or result.events.has("read_start_retry"):
		pending_start_read = true
	if (result.events.has("fade_mix") or result.events.has("restore_mix")) and result.has("mix"):
		if not player.set_cd_mix(result.mix): return {"fault":"Invalid callback CD mix"}
	# Read-start events require the caller's explicit predictor/filter history.
	# They are never acknowledged from a decoded-tail guess.
	return result
func service_start_read(predictor_history: Array, interpolation_state: Dictionary) -> Dictionary:
	if not pending_start_read: return {"ignored":true}
	return seek_read(predictor_history,interpolation_state)

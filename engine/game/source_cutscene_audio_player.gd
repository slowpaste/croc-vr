extends Node
const Reader = preload("res://source_xa_channel_reader.gd")
var stream := preload("res://source_xa_stream_player.gd").new()
var content := ""
var record: Dictionary = {}
var history: Array = []
var interpolation: Dictionary = {}
var threaded := true
var configured := false
var started := false
var ended := false
func _init() -> void: add_child(stream)
func configure(root_path: String, channel: Dictionary, mix: Array, predictor_history: Array, filter_state: Dictionary, use_thread: bool) -> bool:
	if started or not Reader.valid_history(predictor_history) or not channel.has_all(["sourceLba","firstSector","sectors","compressedFile"]): return false
	if not filter_state.is_empty() and not preload("res://source_xa_zigzag.gd").valid_snapshot(filter_state): return false
	if not stream.set_cd_mix(mix): return false
	content = root_path
	record = channel.duplicate(true)
	history = predictor_history.duplicate(true)
	interpolation = filter_state.duplicate(true)
	threaded = use_thread
	configured = true
	ended = false
	return true
func receive(timeline: Dictionary) -> Dictionary:
	if not configured: return {"fault":"Cutscene audio is not configured"}
	if not timeline.has_all(["complete","paused","audio_frames"]): return {"fault":"Invalid cutscene audio timeline"}
	if bool(timeline.complete):
		stream.stop_stream(); started = false; ended = true
		return {"stopped":true}
	if ended: return {"stopped":true}
	stream.stream_paused = bool(timeline.paused)
	if bool(timeline.paused): return {"paused":true,"started":started}
	if not started:
		if int(timeline.audio_frames) < 2016: return {"waiting":true}
		if not stream.start_stream(content,record,int(record.sourceLba)+int(record.firstSector),history,interpolation,threaded): return {"fault":"Original cutscene audio stream start failed"}
		started = true
	return stream.pump(4)
func _exit_tree() -> void: stream.stop_stream()

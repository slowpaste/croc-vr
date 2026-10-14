extends AudioStreamPlayer
# Diagnostic/native PCM transport. Source filtering and CD callbacks are separate.
var channel_record: Dictionary = {}
func _exit_tree() -> void:
	stop_channel()
func load_channel(content_root: String, record: Dictionary) -> bool:
	stop_channel()
	var file := str(record.get("file",""))
	if file.is_empty() or file.contains("..") or file.is_absolute_path():
		return false
	var decoded := AudioStreamWAV.load_from_file(content_root.path_join(file))
	if decoded == null or decoded.mix_rate != int(record.get("sampleRate",0)) or not decoded.stereo:
		return false
	decoded.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream = decoded
	channel_record = record.duplicate(true)
	return true
func start_channel(at_seconds: float = 0.0) -> bool:
	if stream == null or channel_record.is_empty():
		return false
	play(maxf(at_seconds,0.0))
	return true
func source_sector_for_frame(frame: int) -> int:
	if channel_record.is_empty():
		return -1
	return int(channel_record.sourceLba)+int(channel_record.firstSector)+int(maxi(frame,0)/2016)*8
func frame_for_source_sector(sector: int) -> Dictionary:
	if channel_record.is_empty():
		return {"fault":"No original XA channel is loaded"}
	var first := int(channel_record.sourceLba)+int(channel_record.firstSector)
	var distance := maxi(sector-first,0)
	var frame := int((distance+7)/8)*2016
	if frame >= int(channel_record.frames):
		return {"fault":"Requested XA sector is beyond the decoded channel"}
	return {"frame":frame,"requested_sector":sector,"audio_sector":source_sector_for_frame(frame)}
func start_source_sector(sector: int) -> Dictionary:
	var mapped := frame_for_source_sector(sector)
	if mapped.has("fault"):
		return mapped
	if not start_channel(float(mapped.frame)/float(channel_record.sampleRate)):
		return {"fault":"Original XA PCM transport failed to start"}
	return mapped
func stop_channel() -> void:
	stop()
	stream = null
	channel_record.clear()

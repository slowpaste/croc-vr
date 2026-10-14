extends RefCounted
const Decoder = preload("res://source_xa_decoder.gd")
var decoder := Decoder.new()
var file: FileAccess = null
var record: Dictionary = {}
var sector_index := 0
var fault := ""
func open_channel(content_root: String, channel: Dictionary) -> bool:
	close_channel()
	var relative := str(channel.get("compressedFile",""))
	if relative.is_empty() or relative.contains("..") or relative.is_absolute_path():
		return false
	if channel.has("end_sector_limit") and (not channel.end_sector_limit is int or int(channel.end_sector_limit)<int(channel.sourceLba)):
		return false
	file = FileAccess.open(content_root.path_join(relative),FileAccess.READ)
	if file == null or file.get_length() != int(channel.sectors)*2352:
		close_channel()
		return false
	record = channel.duplicate(true)
	decoder.reset()
	return true
static func valid_history(predictor_history: Array) -> bool:
	if predictor_history.size() != 2: return false
	for pair in predictor_history:
		if not pair is Array or pair.size() != 2: return false
		for sample in pair:
			if not sample is int or sample < -32768 or sample > 32767: return false
	return true
func seek_sector(sector: int, predictor_history: Array) -> Dictionary:
	if file == null or not valid_history(predictor_history):
		return {"fault":"Missing XA channel or explicit predictor history"}
	var first := int(record.sourceLba)+int(record.firstSector)
	var candidate := int((maxi(sector-first,0)+7)/8)
	if candidate >= int(record.sectors):
		return {"fault":"XA compressed seek exceeds channel"}
	sector_index = candidate
	fault = ""
	decoder.history = predictor_history.duplicate(true)
	file.seek(sector_index*2352)
	return {"requested_sector":sector,"audio_sector":first+sector_index*8,"frame":sector_index*2016}
func read_sector() -> Dictionary:
	if file == null:
		return {"fault":"No XA compressed channel open"}
	if not fault.is_empty(): return {"fault":fault}
	if sector_index >= int(record.sectors):
		return {"end":true}
	var source_sector := int(record.sourceLba)+int(record.firstSector)+sector_index*8
	# Original completion uses cursor > end, so the packet at end is allowed.
	if record.has("end_sector_limit") and source_sector>int(record.end_sector_limit):
		return {"end":true,"source_sector":source_sector,"cue_boundary":true}
	var original_position := file.get_position()
	var original_history := decoder.history.duplicate(true)
	var raw := file.get_buffer(2352)
	if raw.size() != 2352 or int(raw[16]) != 1 or int(raw[17]) != int(record.channel) or int(raw[19]) != int(record.coding):
		fault = "XA sector does not match selected channel"
		file.seek(original_position)
		return {"fault":fault}
	var result := decoder.decode(raw)
	if result.has("fault"):
		fault = str(result.fault)
		decoder.history = original_history
		file.seek(original_position)
		return result
	result.source_sector = source_sector
	sector_index += 1
	return result
func history_snapshot() -> Array:
	return decoder.history.duplicate(true)
func close_channel() -> void:
	file = null
	record.clear()
	sector_index = 0
	fault = ""
	decoder.reset()

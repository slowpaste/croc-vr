extends SceneTree
const Reader = preload("res://source_xa_channel_reader.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var arguments := OS.get_cmdline_user_args()
	var option := arguments.find("--content")
	if option < 0 or option+1 >= arguments.size(): quit(1); return
	var content := str(arguments[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[0]
	var reader := Reader.new()
	if not reader.open_channel(content,record): quit(1); return
	var first := int(record.sourceLba)+int(record.firstSector)
	reader.read_sector()
	var history := reader.history_snapshot()
	var original_position := reader.file.get_position()
	for invalid in [[[0,0],null],[[0,0],[32768,0]],[[0,0],[-32769,0]],[[0,0],[1.5,0]],[[0,0],["0",0]]]:
		if not reader.seek_sector(first,invalid).has("fault") or reader.sector_index != 1 or reader.file.get_position() != original_position or reader.history_snapshot() != history:
			push_error("Malformed XA history changed reader state or was accepted")
			quit(1)
			return
	if not reader.seek_sector(int(record.sourceLba)+int(record.lastSector)+8,[[0,0],[0,0]]).has("fault") or reader.sector_index != 1 or reader.file.get_position() != original_position or reader.history_snapshot() != history:
		push_error("Rejected compressed seek changed source reader state")
		quit(1)
		return
	var sequential := reader.read_sector()
	var mapped := reader.seek_sector(first+1,history)
	if mapped.audio_sector != first+8 or reader.read_sector().pcm != sequential.pcm:
		push_error("Explicit XA history seek changed sequential PCM")
		quit(1)
		return
	reader.seek_sector(first+8,[[0,0],[0,0]])
	var reset := reader.read_sector()
	var raw := FileAccess.open(content.path_join(record.compressedFile),FileAccess.READ)
	raw.seek(2352)
	var reference := preload("res://source_xa_decoder.gd").new().decode(raw.get_buffer(2352))
	if reset.pcm != reference.pcm:
		quit(1)
		return
	reader.seek_sector(int(record.sourceLba)+int(record.lastSector),[[0,0],[0,0]])
	if reader.read_sector().has("fault") or reader.read_sector() != {"end":true}:
		quit(1)
		return
	reader.close_channel()
	if reader.file != null or not reader.record.is_empty(): quit(1); return
	print("PASS: native compressed XA reader, interleaved seek, explicit retained/reset history, end and close")
	quit(0)

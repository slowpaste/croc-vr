extends SceneTree
const Player = preload("res://source_music_player.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var arguments := OS.get_cmdline_user_args()
	var option := arguments.find("--content")
	if option < 0 or option+1 >= arguments.size():
		quit(1)
		return
	var content := str(arguments[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[63]
	var player := Player.new()
	root.add_child(player)
	if not player.load_channel(content,record) or player.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED or player.source_sector_for_frame(0) != int(record.sourceLba)+int(record.firstSector) or player.source_sector_for_frame(2016) != int(record.sourceLba)+int(record.firstSector)+8:
		quit(1)
		return
	if not player.start_channel():
		quit(1)
		return
	var first := int(record.sourceLba)+int(record.firstSector)
	var mapping := player.frame_for_source_sector(first+1)
	if mapping.frame != 2016 or mapping.requested_sector != first+1 or mapping.audio_sector != first+8:
		push_error("XA seek did not advance to the selected channel's next sector")
		quit(1)
		return
	if player.frame_for_source_sector(first+8).frame != 2016 or player.frame_for_source_sector(int(record.sourceLba)).frame != 0 or not player.frame_for_source_sector(first+int(record.sectors)*8).has("fault"):
		quit(1)
		return
	if player.start_source_sector(first+8).get("frame",-1) != 2016:
		quit(1)
		return
	await process_frame
	var replacement: Dictionary = index.streams[0]
	if not player.load_channel(content,replacement) or player.channel_record.logical != 1 or not player.start_channel(0.1):
		push_error("Music transport failed to replace the active source stream")
		quit(1)
		return
	await process_frame
	player.stop_channel()
	# Stop is consumed asynchronously by AudioServer; allow its mixer to drain.
	await create_timer(0.05).timeout
	if player.stream != null or not player.channel_record.is_empty():
		quit(1)
		return
	if not player.load_channel(content,record) or not player.start_channel():
		quit(1)
		return
	root.remove_child(player)
	if player.stream != null or not player.channel_record.is_empty():
		push_error("Scene exit retained the music stream")
		quit(1)
		return
	player.free()
	await create_timer(0.05).timeout
	await process_frame
	print("PASS: XA PCM transport switching, scene-exit cleanup, mixer drain and source-sector frame mapping")
	quit(0)

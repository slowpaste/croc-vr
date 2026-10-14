extends SceneTree
const Player = preload("res://source_xa_stream_player.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[0]
	var player := Player.new()
	root.add_child(player)
	player.pending = PackedVector2Array([Vector2(1000,3000)/32768.0,Vector2(-1000,2000)/32768.0])
	player.pending_offset = 1
	player.set_cd_mix([128,128,0,0])
	if player.pending_output(1) != PackedVector2Array([Vector2(-1000,2000)/32768.0]): quit(1); return
	player.set_cd_mix([0,0,0,0])
	if player.pending_output(1) != PackedVector2Array([Vector2.ZERO]) or player.pending[1] != Vector2(-1000,2000)/32768.0 or player.pending_offset != 1:
		push_error("Changed routing did not affect waiting PCM or mutated its source/position")
		quit(1)
		return
	if not player.set_cd_mix([0,0,0,0]) or player.set_cd_mix([256,0,0,0]) or player.cd_mix != [0,0,0,0]:
		push_error("Invalid CD mix changed active routing")
		quit(1)
		return
	if not player.start_stream(content,record,int(record.sourceLba),[[0,0],[0,0]]): quit(1); return
	var result := player.pump(1)
	if result.has("fault") or result.decoded_sectors != 1 or result.pushed_frames != 2016 or player.queued_frames != 2016 or player.reader.sector_index != 1:
		push_error("Native streaming pump did not queue exactly one decoded XA sector")
		quit(1)
		return
	for repeat in range(20):
		result = player.pump(1)
		if result.has("fault") or result.decoded_sectors > 1 or player.pending.size() > 2016:
			quit(1)
			return
	if player.reader.sector_index > 10:
		push_error("Streaming reader decoded beyond bounded audio-buffer pressure")
		quit(1)
		return
	var old_playback := player.playback.get_instance_id()
	var old_index := player.reader.sector_index
	var old_frames := player.queued_frames
	var invalid := player.seek_stream(int(record.sourceLba)+int(record.lastSector)+8,[[0,0],[0,0]])
	if not invalid.has("fault") or player.reader.sector_index != old_index or player.queued_frames != old_frames or player.playback.get_instance_id() != old_playback:
		push_error("Rejected stream seek changed queued playback")
		quit(1)
		return
	var first := int(record.sourceLba)+int(record.firstSector)
	player.set_cd_mix([128,128,0,0])
	var mapped := player.seek_stream(first+1,[[0,0],[0,0]])
	if mapped.has("fault") or mapped.audio_sector != first+8 or player.reader.sector_index != 1 or player.queued_frames != 0 or player.pending.size() != 0 or player.playback.get_instance_id() == old_playback:
		push_error("Accepted stream seek retained stale audio/FIFO state")
		quit(1)
		return
	result = player.pump(1)
	if result.has("fault") or result.pushed_frames != 2016 or player.reader.sector_index != 2:
		quit(1)
		return
	var reference := FileAccess.open(content.path_join(record.compressedFile),FileAccess.READ)
	reference.seek(2352)
	# This seek explicitly resets predictor history, so compare against a fresh
	# decoder at sector1, not a sequential WAV with sector0's retained history.
	var decoder := preload("res://source_xa_decoder.gd").new()
	var decoded := decoder.decode(reference.get_buffer(2352))
	if decoded.has("fault"): quit(1); return
	var pcm: PackedByteArray = decoded.pcm
	for frame in range(player.pending.size()):
		var expected := Vector2(pcm.decode_s16(frame*4),pcm.decode_s16(frame*4+2))/32768.0
		if player.pending[frame] != expected:
			push_error("Configured unity CD routing changed source stream PCM")
			quit(1)
			return
	player.stop_stream()
	await create_timer(0.05).timeout
	var filter := preload("res://source_xa_zigzag.gd").new()
	var initial := filter.snapshot()
	if not player.start_stream(content,record,int(record.sourceLba),[[0,0],[0,0]],initial): quit(1); return
	result = player.pump(1)
	if result.has("fault") or result.pushed_frames != 2352 or player.stream.mix_rate != 44100.0:
		push_error("Interpolated stream did not queue 44100Hz source audio")
		quit(1)
		return
	old_index = player.reader.sector_index
	old_frames = player.queued_frames
	var filter_before: Dictionary = player.interpolator.snapshot()
	invalid = player.seek_stream(first,[[0,0],[0,0]])
	if not invalid.has("fault") or player.reader.sector_index != old_index or player.queued_frames != old_frames or player.interpolator.snapshot() != filter_before:
		push_error("Seek without explicit interpolation history changed playback")
		quit(1)
		return
	var retained_history := player.reader.history_snapshot()
	var expected_reader := preload("res://source_xa_channel_reader.gd").new()
	expected_reader.open_channel(content,record)
	expected_reader.seek_sector(first+8,retained_history)
	var next_sector := expected_reader.read_sector()
	filter.restore(filter_before)
	var expected_pcm: PackedByteArray = filter.process_pcm(next_sector.pcm,37800).pcm
	await create_timer(0.05).timeout
	mapped = player.seek_stream(first+8,retained_history,filter_before)
	result = player.pump(1)
	if mapped.has("fault") or result.has("fault") or result.pushed_frames != 2352: quit(1); return
	for frame in range(player.pending.size()):
		if player.pending[frame] != Vector2(expected_pcm.decode_s16(frame*4),expected_pcm.decode_s16(frame*4+2))/32768.0:
			push_error("Interpolated retained-history seek changed output PCM")
			quit(1)
			return
	expected_reader.close_channel()
	expected_reader = null
	filter = null
	player.stop_stream()
	await create_timer(0.05).timeout
	if player.playback != null or player.stream != null or player.reader.file != null or player.pending.size() != 0:
		quit(1)
		return
	player.queue_free()
	await process_frame
	print("PASS: native incremental XA streaming, sector work limit, bounded pending buffer and stop cleanup")
	quit(0)

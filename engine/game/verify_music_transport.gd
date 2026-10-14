extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func location_response(sector: int) -> PackedByteArray:
	var absolute := sector+150
	var values := [int(absolute/4500),int(absolute/75)%60,absolute%75]
	var response := PackedByteArray([0,0,0,0,0,0,0,0])
	for index in range(3):
		var value := int(values[index])
		response[5+index] = (int(value/10)<<4)|(value%10)
	return response
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var streams: Array = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.musicIndex))).streams
	var transport := preload("res://source_music_transport.gd").new()
	root.add_child(transport)
	transport.session.initialize_bootstrap(JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.bootstrapMusic.file))))
	transport.session.prepare_bootstrap({"cue":64,"mode":4,"room":0,"style":0,"loop":false},tables.musicCues.pairs,streams)
	var filter := preload("res://source_xa_zigzag.gd").new()
	var state := filter.snapshot()
	filter = null
	if not transport.start_read(content,[[0,0],[0,0]],state).has("fault") or transport.session.current.seek_phase != 0: quit(1); return
	transport.session.initialize_mix(100,1)
	var result := transport.start_read(content,[[0,0],[0,0]],state)
	if not result.accepted or result.seek_phase != 1: quit(1); return
	await create_timer(0.05).timeout
	transport.player.pump(1)
	var old_frames: int = transport.player.queued_frames
	var old_playback: int = transport.player.playback.get_instance_id()
	transport.session.current.cursor += 8
	var old_cursor: int = transport.session.current.cursor
	var option_mix := preload("res://source_cd_fade.gd").restore(119,1)
	var applied := transport.apply_options_mix(120,1,option_mix)
	if applied.has("fault") or transport.session.current.configured_volume!=120 or transport.player.cd_mix!=[119,119,0,0] or transport.session.current.cursor!=old_cursor or transport.session.current.seek_phase!=1 or transport.player.playback.get_instance_id()!=old_playback or transport.player.queued_frames!=old_frames:
		push_error("Options mix restarted or altered live transport position");quit(1);return
	var saved_session: Dictionary = transport.session.current.duplicate(true)
	var options := preload("res://source_options_session.gd").initialize({"music":120,"effects":127,"mode":1})
	options.page = 3;options.navigation = preload("res://source_main_menu.gd").initialize(2,3)
	options = preload("res://source_options_session.gd").advance(options,0,0xa0000)
	var broken_events: Array = options.cd_mix_events.duplicate(true)
	broken_events[1].mix = [120,120,0,1]
	if not transport.apply_options_events(broken_events).has("fault") or transport.session.current!=saved_session or transport.player.cd_mix!=[119,119,0,0]:
		push_error("Rejected Options event batch applied a partial update");quit(1);return
	if transport.apply_options_events(options.cd_mix_events).get("applied",0)!=2 or transport.player.cd_mix!=[120,120,0,0] or transport.session.current.stereo_flag!=1:
		push_error("Ordered Options mode events failed on live transport");quit(1);return
	if transport.apply_options_mix(120,1,option_mix).has("fault"):quit(1);return
	saved_session = transport.session.current.duplicate(true)
	if not transport.apply_options_mix(120,1,{"counter":119,"decrement":14,"mix":[120,120,0,0]}).has("fault") or transport.session.current!=saved_session or transport.player.cd_mix!=[119,119,0,0]:
		push_error("Invalid Options mix changed live transport");quit(1);return
	if transport.apply_options_mix(0,1,preload("res://source_cd_fade.gd").restore(0,1)).has("fault"):quit(1);return
	# Controlled pending sample tests the actual player's submission mixer;
	# the running decoder/playback and its pending buffer are retained.
	var saved_pending: PackedVector2Array = transport.player.pending
	var saved_offset: int = transport.player.pending_offset
	transport.player.pending = PackedVector2Array([Vector2(0.5,-0.25)])
	transport.player.pending_offset = 0
	if transport.player.pending_output(1)!=PackedVector2Array([Vector2.ZERO]):push_error("Options mute did not reach submission mixer");quit(1);return
	transport.player.pending = saved_pending;transport.player.pending_offset = saved_offset
	if transport.apply_options_mix(100,1,preload("res://source_cd_fade.gd").restore(100,1)).has("fault"):quit(1);return
	for invalid_history in [[[0,0],null],[[0,0],[-32769,0]],[[0,0],[1.5,0]]]:
		result = transport.seek_read(invalid_history,state)
		if result.accepted or result.cursor != old_cursor or result.seek_phase != 1 or transport.player.playback.get_instance_id() != old_playback or transport.player.queued_frames != old_frames:
			push_error("Malformed predictor history changed transport playback/bookkeeping")
			quit(1)
			return
	result = transport.seek_read([[0,0],[0,0]],{})
	if result.accepted or result.cursor != old_cursor or result.seek_phase != 1 or transport.player.queued_frames != old_frames or transport.player.playback.get_instance_id() != old_playback:
		push_error("Rejected transport read changed source cursor/phase or queued playback")
		quit(1)
		return
	result = transport.seek_read([[0,0],[0,0]],state)
	if not result.accepted or result.cursor != transport.session.current.start_sector or result.seek_phase != 2 or transport.player.queued_frames != 0: quit(1); return
	await create_timer(0.05).timeout
	transport.player.pump(1)
	old_playback = transport.player.playback.get_instance_id()
	old_frames = transport.player.queued_frames
	result = transport.stop_music(false)
	if result.has("fault") or transport.player.playback.get_instance_id() != old_playback or transport.player.queued_frames != old_frames or transport.session.current.active != 1 or not transport.session.rooms.is_empty():
		push_error("Disabled source stop interrupted streamed audio or committed a bookmark")
		quit(1)
		return
	transport.session.receive(1)
	result = transport.stop_music(true)
	if result.has("fault") or result.active != 0 or transport.player.worker != null or transport.player.playback != null or transport.player.reader.file != null or transport.session.rooms[0].start != 0 or transport.session.rooms[0].variant != 1:
		push_error("Enabled source stop failed to stop/join playback and commit near-end room variant")
		quit(1)
		return
	await create_timer(0.1).timeout
	var prepared := transport.session.prepare_bootstrap({"cue":64,"mode":4,"room":1,"style":0,"loop":false},tables.musicCues.pairs,streams)
	transport.session.initialize_mix(100,1)
	result = transport.start_read(content,[[0,0],[0,0]],state)
	if not result.accepted: quit(1); return
	await create_timer(0.05).timeout
	transport.player.pump(1)
	var response := location_response(int(prepared.end_sector)+1)
	old_playback = transport.player.playback.get_instance_id()
	result = transport.receive_cd(1,1,2,17,response)
	if result.active != 1 or result.events.has("sync") or transport.player.playback.get_instance_id() != old_playback:
		push_error("Off-gate CD response completed transport audio prematurely")
		quit(1)
		return
	result = transport.receive_cd(1,7,2,17,response)
	if result.active != 0 or result.completion_pending != 1 or transport.player.worker != null or transport.player.playback != null or transport.session.rooms[1].variant != 1:
		push_error("Source completion callback did not stop actual stream and commit room state")
		quit(1)
		return
	await create_timer(0.1).timeout
	prepared = transport.session.prepare_bootstrap({"cue":1,"mode":4,"room":2,"style":0,"loop":true},tables.musicCues.pairs,streams)
	transport.session.initialize_mix(100,1)
	if not transport.start_read(content,[[0,0],[0,0]],state).accepted: quit(1); return
	await create_timer(0.05).timeout
	transport.player.pump(1)
	old_playback = transport.player.playback.get_instance_id()
	old_frames = transport.player.queued_frames
	result = transport.receive(1,0,int(prepared.fade_sector))
	if result.events.has("fade_mix") or transport.player.cd_mix != [100,100,0,0]: quit(1); return
	result = transport.receive(1,0,int(prepared.fade_sector)+1)
	if not result.events.has("fade_mix") or result.active != 3 or transport.player.cd_mix != [88,88,0,0] or transport.player.queued_frames != old_frames or transport.player.playback.get_instance_id() != old_playback:
		push_error("Original fade callback did not reach pending CD mix or interrupted playback")
		quit(1)
		return
	result = transport.receive(1,0,int(prepared.end_sector)+1)
	if not result.events.has("read_start") or not transport.pending_start_read or result.seek_phase != 1 or transport.player.playback.get_instance_id() != old_playback or transport.player.cd_mix != [100,100,0,0]:
		push_error("Loop callback restarted/acknowledged audio before explicit history was supplied")
		quit(1)
		return
	result = transport.service_start_read([[0,0],[0,0]],{})
	if result.accepted or not transport.pending_start_read or result.seek_phase != 1: quit(1); return
	result = transport.service_start_read([[0,0],[0,0]],state)
	if not result.accepted or transport.pending_start_read or result.seek_phase != 2 or result.cursor != prepared.start_sector or transport.player.queued_frames != 0: quit(1); return
	if not transport.service_start_read([],{}).get("ignored",false) or transport.session.current.seek_phase != 2: quit(1); return
	transport.stop_music(true)
	await create_timer(0.1).timeout
	var bookmark := int(streams[0].sourceLba)+400
	transport.session.rooms[2] = {"start":bookmark,"variant":0}
	prepared = transport.session.prepare_bootstrap({"cue":1,"mode":4,"room":2,"style":0,"loop":true,"seek_mode":128},tables.musicCues.pairs,streams)
	transport.session.initialize_mix(100,1)
	if prepared.start_sector != bookmark or not transport.start_read(content,[[0,0],[0,0]],state).accepted: quit(1); return
	await create_timer(0.05).timeout
	transport.player.pump(1)
	old_playback = transport.player.playback.get_instance_id()
	result = transport.receive(3)
	if not result.events.has("read_start_retry") or result.seek_phase != 2 or result.start_sector != prepared.pack_start or result.cursor != bookmark or not transport.pending_start_read: quit(1); return
	result = transport.service_start_read([[0,0],[0,0]],{})
	if result.accepted or result.seek_phase != 2 or result.cursor != bookmark or transport.player.playback.get_instance_id() != old_playback: quit(1); return
	result = transport.receive(3)
	if result.seek_phase != 2: quit(1); return
	result = transport.service_start_read([[0,0],[0,0]],state)
	if not result.accepted or result.seek_phase != 3 or result.cursor != prepared.pack_start or transport.pending_start_read:
		push_error("Source retry failed to retain rejected state or acknowledge accepted pack-start read once")
		quit(1)
		return
	transport.stop_music(true)
	await create_timer(0.1).timeout
	prepared = transport.session.prepare_bootstrap({"cue":64,"mode":4,"room":3,"style":0,"loop":true},tables.musicCues.pairs,streams)
	transport.session.initialize_mix(75,1)
	if not transport.start_read(content,[[0,0],[0,0]],state).accepted: quit(1); return
	if transport.apply_options_mix(120,1,preload("res://source_cd_fade.gd").restore(119,1)).has("fault"):quit(1);return
	await create_timer(0.05).timeout
	result = transport.receive(1,0,int(prepared.fade_sector)+1)
	if result.events.has("fade_mix") or transport.player.cd_mix != [119,119,0,0]: quit(1); return
	result = transport.receive(1,0,int(prepared.end_sector)+1)
	if result.active != 0 or result.completion_pending != 0 or result.events.has("read_start") or not result.events.has("restore_mix") or transport.pending_start_read or transport.player.worker != null or transport.player.cd_mix != [120,120,0,0]:
		push_error("Results cue64 loop path did not pause and restore original mix without requesting another loop")
		quit(1)
		return
	await create_timer(0.1).timeout
	transport.queue_free()
	await process_frame
	print("PASS: source music read acknowledgments follow real threaded stream acceptance and rejected seek preserves playback/cursor")
	quit(0)

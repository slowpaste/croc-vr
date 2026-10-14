extends SceneTree
const Session = preload("res://source_music_session.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var pairs: Array = world.runtime_tables.musicCues.pairs
	var streams: Array = world.read_json(world.manifest.musicIndex).streams
	var session := Session.new()
	if not session.prepare_bootstrap({},[],[],[],false).get("ignored",false) or not session.current.is_empty() or session.previous.cue != 0:
		push_error("Disabled Play required bootstrap/data or wrote initial bookkeeping")
		quit(1)
		return
	var request := {"cue":12,"mode":4,"room":1,"style":0,"loop":false}
	if not session.prepare_bootstrap(request,pairs,streams).has("fault") or not session.initialize_bootstrap(world.read_json(world.manifest.bootstrapMusic.file)):
		quit(1)
		return
	var original_bounds := session.bootstrap_bounds.duplicate()
	if session.initialize_bootstrap({"endSectorOffsets":[0]}) or session.bootstrap_bounds != original_bounds:
		quit(1)
		return
	var invalid := original_bounds.duplicate()
	invalid[0] = 1.5
	if session.initialize_bootstrap({"endSectorOffsets":invalid}) or session.bootstrap_bounds != original_bounds: quit(1); return
	for invalid_value in [-1,4294967296,NAN,INF]:
		invalid[0] = invalid_value
		if session.initialize_bootstrap({"endSectorOffsets":invalid}) or session.bootstrap_bounds != original_bounds: quit(1); return
	var prepared := session.prepare_bootstrap(request,pairs,streams)
	if prepared.has("fault"):
		quit(1)
		return
	var active_before: Dictionary = session.current.duplicate(true)
	var previous_before: Dictionary = session.previous.duplicate(true)
	var rooms_before: Dictionary = session.rooms.duplicate(true)
	if not session.prepare({},[],[],[],[],false).get("ignored",false) or session.current != active_before or session.previous != previous_before or session.rooms != rooms_before:
		push_error("Disabled Play changed existing music/session state")
		quit(1)
		return
	var acknowledgment := session.acknowledge_read(false)
	var response := PackedByteArray([0,0,0,0,0,0,2,1])
	var polled := session.receive_cd(1,1,2,17,response)
	if polled.cursor != int(prepared.start_sector)+8 or polled.events != ["poll"]:
		push_error("Off-gate CD callback did not retain sector-step cursor")
		quit(1)
		return
	polled = session.receive_cd(1,7,2,17,response)
	if polled.cursor != 1 or polled.events != ["poll","sync","get_location"]:
		push_error("Gated CD poll did not replace cursor before callback decisions")
		quit(1)
		return
	if acknowledgment.seek_phase != 0:
		quit(1)
		return
	acknowledgment = session.acknowledge_read(true)
	if acknowledgment.seek_phase != 1 or acknowledgment.cursor != prepared.start_sector:
		quit(1)
		return
	session.stop_music(false)
	if not session.rooms.is_empty() or session.current.active != 1:
		push_error("Disabled source stop wrote room state")
		quit(1)
		return
	var saved := int(prepared.start_sector)+500
	session.receive(1,500)
	if not session.rooms.is_empty():
		push_error("Ordinary source callback wrote completion bookkeeping")
		quit(1)
		return
	session.stop_music(true)
	if session.rooms[1].start != saved or session.previous.room != 1:
		quit(1)
		return
	request.room = 2
	prepared = session.prepare_bootstrap(request,pairs,streams)
	if prepared.start_sector != saved or prepared.seek_mode != 2:
		push_error("Source stop bookmark did not feed subsequent room request")
		quit(1)
		return
	session.receive(1,0,int(prepared.end_sector)+1)
	if session.rooms[2].start != 0 or session.rooms[2].variant != 1 or session.previous.room != 2:
		quit(1)
		return
	request.room = 3
	prepared = session.prepare_bootstrap(request,pairs,streams)
	if prepared.logical != 25 or prepared.variant != 1 or prepared.start_sector != prepared.pack_start:
		push_error("Source completion variant did not feed subsequent room request")
		quit(1)
		return
	session.configure_mix(100,7,1)
	var faded := session.receive(1,0,int(prepared.fade_sector)+1)
	if faded.active != 3 or faded.mix_counter != 93 or faded.mix != [93,93,0,0]:
		push_error("Original fade callback did not update configured music mix/state")
		quit(1)
		return
	faded = session.receive(1,0,int(prepared.end_sector)+1)
	if faded.active != 0 or faded.mix_counter != 93 or not faded.events.has("complete"):
		push_error("Fading music failed to complete without another mix decrement")
		quit(1)
		return
	request.loop = true
	prepared = session.prepare_bootstrap(request,pairs,streams)
	session.initialize_mix(100,1)
	faded = session.receive(1,0,int(prepared.fade_sector)+1)
	if faded.mix_counter != 88 or faded.mix_decrement != 12:
		quit(1)
		return
	faded = session.receive(1,0,int(prepared.end_sector)+1)
	if faded.mix_counter != 100 or faded.mix != [100,100,0,0] or faded.active != 3 or not faded.events.has("read_start"):
		push_error("Source looping callback did not restore configured mix without changing active")
		quit(1)
		return
	var adjusted := session.adjust_volume(40)
	if adjusted.configured_volume != 127 or adjusted.mix_counter != 127 or adjusted.mix_decrement != 15 or adjusted.mix != [127,127,0,0]:
		push_error("Live option adjustment failed to update callback mix state")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: original music request/stop/callback session carries room bookmarks and completion variants into later requests")
	quit(0)

extends Node
var transport := preload("res://source_music_transport.gd").new()
var fault := ""
var running := false
var owner_world: WeakRef = null
var completed_frame := -1
var automatic := false
func _init() -> void:
	add_child(transport)
func _process(_delta: float) -> void:
	if not automatic or owner_world==null:return
	var world=owner_world.get_ref()
	if world==null:return
	transport.player.stream_paused=not world.xr_gameplay_is_focused()
	if transport.player.stream_paused:return
	if running:pump()
	elif completed_frame>=0 and int(world.source_frame_clock.counter)>completed_frame+1500 and int(transport.session.current.get("cue",0))!=64:
		var restarted := start_room(world)
		if restarted.has("fault"):fault=str(restarted.fault)
func start_room(world: Node) -> Dictionary:
	var data: Dictionary=world.room_data
	if not data.has_all(["musicTrack","flags","style"]):return {"fault":"Missing original map music fields"}
	return start_request(world,int(data.musicTrack),false,int(data.flags)&0x80)
func start_request(world: Node, cue: int, looping: bool = false, seek_mode: int = 0) -> Dictionary:
	if cue==0:
		stop_room();return {"silent":true}
	if cue<1 or cue>64:return {"fault":"Invalid original map music cue"}
	if running:stop_room()
	owner_world=weakref(world);completed_frame=-1
	var bootstrap: Dictionary=world.read_shared_content(world.manifest.bootstrapMusic.file) if world.has_method("read_shared_content") else world.read_json(world.manifest.bootstrapMusic.file)
	if not transport.session.initialize_bootstrap(bootstrap):return {"fault":"Invalid original music bootstrap"}
	var streams: Array=(world.read_shared_content(world.manifest.musicIndex) if world.has_method("read_shared_content") else world.read_json(world.manifest.musicIndex)).streams
	# Main139f0..13a08: map word20, loop0, map word16 &128.
	var planned := transport.session.prepare_bootstrap({"cue":cue,"mode":4,"room":int(world.map_name.substr(6,2)),"style":int(world.room_data.style),"loop":looping,"seek_mode":seek_mode},world.runtime_tables.musicCues.pairs,streams)
	if planned.has("fault"):return planned
	var mixed := transport.session.initialize_mix(int(world.source_music_volume),int(world.source_cd_stereo_flag))
	if mixed.has("fault"):return mixed
	var filter := preload("res://source_xa_zigzag.gd").new()
	var started := transport.start_read(world.content_root,[[0,0],[0,0]],filter.snapshot())
	if started.has("fault") or not bool(started.get("accepted",false)):return {"fault":str(started.get("fault","Gameplay music stream did not start"))}
	running=true;fault=""
	return {"playing":true,"cue":cue,"logical":int(planned.logical),"seek_mode":int(planned.seek_mode),"loop":bool(planned.loop)}
func pump() -> Dictionary:
	if not running:return {"idle":true}
	var result := transport.player.pump()
	if result.has("fault"):
		fault=str(result.fault);stop_room()
		return result
	# These are local transport receipt events, not producer checkpoints or
	# an invented GetlocP response. Each selected XA packet spans eight sectors.
	for receipt in result.get("packet_receipts",[]):
		var event := transport.receive(1,8)
		if event.has("fault"):fault=str(event.fault);stop_room();return event
		if event.events.has("complete"):
			running=false
			var world=owner_world.get_ref() if owner_world!=null else null
			completed_frame=int(world.source_frame_clock.counter) if world!=null else -1
			break
		if event.events.has("read_start"):
			var tail: Dictionary=transport.player.decoded_tail.duplicate(true)
			var restarted := transport.service_start_read(tail.get("predictor_history",[[0,0],[0,0]]),tail.get("interpolation_state",{}))
			if restarted.has("fault"):fault=str(restarted.fault);stop_room();return restarted
			break
	return result
func stop_room() -> void:
	if not transport.session.current.is_empty():transport.stop_music(true)
	transport.player.stop_stream();running=false;completed_frame=-1
func reset_rooms() -> void:
	# Original loader2dad4 skips reset50ec0 only for same-level return2.
	stop_room();transport.session.rooms.clear();transport.session.current.clear()
	transport.session.previous={"cue":0,"room":0}
func _exit_tree() -> void:
	stop_room()

extends Node
var transport := preload("res://source_music_transport.gd").new()
var playback_state := 0 # Original stopped0/playing1/paused2.
var track := 1
var fault := ""
var owner_world: WeakRef = null
var pending_track_changes: Array[int]=[]
func _init() -> void:add_child(transport)
func _process(_delta: float) -> void:
	if playback_state!=1:return
	var world=owner_world.get_ref() if owner_world!=null else null
	if world==null:return
	transport.player.stream_paused=not world.xr_gameplay_is_focused()
	if transport.player.stream_paused:return
	var result := transport.player.pump()
	if result.has("fault"):fault=str(result.fault);stop_track();return
	for receipt in result.get("packet_receipts",[]):
		var event := transport.receive(1,8)
		if event.has("fault"):fault=str(event.fault);stop_track();return
		if event.events.has("complete"):
			# Main51a58..51a94 advances the mode8 cue and wraps64 to1.
			var next_track := 1 if track==64 else track+1
			var played := play_track(world,next_track,true,false)
			if played.has("fault"):fault=str(played.fault);stop_track();return
			pending_track_changes.append(next_track)
			break
		if event.events.has("read_start"):
			var tail: Dictionary=transport.player.decoded_tail.duplicate(true)
			var restarted := transport.service_start_read(tail.get("predictor_history",[[0,0],[0,0]]),tail.get("interpolation_state",{}))
			if restarted.has("fault"):fault=str(restarted.fault);stop_track();return
			break
func play_track(world: Node, selected_track: int, direct_channels: bool = true, looping: bool = false, source_mode: int = 8) -> Dictionary:
	if selected_track<1 or selected_track>64:return {"fault":"Invalid original Music Player track"}
	owner_world=weakref(world)
	var bootstrap: Dictionary=world.read_json(world.manifest.bootstrapMusic.file)
	if not transport.session.initialize_bootstrap(bootstrap):return {"fault":"Invalid original music bootstrap"}
	var streams: Array=world.read_json(world.manifest.musicIndex).streams
	var cues: Dictionary=world.runtime_tables.musicCues
	var planned := transport.session.prepare_bootstrap({"cue":selected_track,"mode":source_mode,"room":0,"style":0,"mode8_flag":int(direct_channels),"loop":looping},cues.pairs,streams,cues.mode8.channels)
	if planned.has("fault"):return planned
	var mixed := transport.session.initialize_mix(int(world.source_music_volume),int(world.source_cd_stereo_flag))
	if mixed.has("fault"):return mixed
	var filter := preload("res://source_xa_zigzag.gd").new()
	var started := transport.start_read(world.content_root,[[0,0],[0,0]],filter.snapshot())
	if started.has("fault") or not bool(started.get("accepted",false)):return {"fault":str(started.get("fault","Original music stream did not start"))}
	playback_state=1;track=selected_track;fault=""
	return {"playing":true,"track":track,"logical":int(transport.session.current.stream.logical)}
func pause_track() -> Dictionary:
	if playback_state!=1:return {"fault":"Music Player has no playing stream to pause"}
	transport.player.stream_paused=true;playback_state=2;return {"paused":true}
func resume_track() -> Dictionary:
	if playback_state!=2:return {"fault":"Music Player has no paused stream to resume"}
	transport.player.stream_paused=false;playback_state=1;return {"playing":true}
func stop_track() -> Dictionary:
	if not transport.session.current.is_empty():
		var stopped := transport.stop_music(true)
		if stopped.has("fault"):return stopped
	transport.player.stop_stream();playback_state=0;return {"stopped":true}
func execute(world: Node, selected_track: int, commands: Array) -> Dictionary:
	for command in commands:
		if command not in ["play","pause","resume","stop","menu_music"]:return {"fault":"Unknown Music Player command"}
	if not commands.is_empty():pending_track_changes.clear()
	for command in commands:
		var result: Dictionary
		match str(command):
			"play":result=play_track(world,selected_track)
			"pause":result=pause_track()
			"resume":result=resume_track()
			"stop":result=stop_track()
			"menu_music":result=play_track(world,11,false,true)
		if result.has("fault"):return result
	return {"applied":commands.size(),"state":playback_state,"track":track}

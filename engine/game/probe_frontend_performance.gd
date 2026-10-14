extends Node3D
func _ready() -> void:call_deferred("followups" if OS.get_cmdline_user_args().has("--followups-profile") else "profile")
func followups() -> void:
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var state:Dictionary={"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}
	var result:Dictionary={"duck_scene":18,"samples":30}
	for prepared in [false,true]:
		var metadata:=manifest.duplicate()
		if not prepared:metadata.erase("cutsceneSequencePortalCaches")
		var session=preload("res://source_sequence_portal_session.gd").new();add_child(session)
		if not session.setup(content,metadata,tables,18,state):push_error(session.fault);get_tree().quit(2);return
		if bool(session.portal_performance.prepared)!=prepared:push_error("Requested cinematic cache was not loaded");get_tree().quit(6);return
		session.audio.stream.stop_stream()
		var started:=Time.get_ticks_usec()
		for frame in range(30):
			if not session.present_frame(0,frame*4):get_tree().quit(3);return
		result["prepared_us" if prepared else "legacy_us"]=Time.get_ticks_usec()-started
		session.queue_free();await get_tree().process_frame
	var sad=preload("res://source_sad_portal_session.gd").new();add_child(sad)
	if not sad.setup_sad(content,manifest,tables,state):push_error(sad.fault);get_tree().quit(4);return
	if not sad.portal_performance.prepared:push_error("SAD cache was not loaded");get_tree().quit(7);return
	sad.audio.stream.stop_stream()
	var started:=Time.get_ticks_usec()
	for frame in range(60):
		if not sad.present_portal(frame):get_tree().quit(5);return
	result.sad_60_frames_us=Time.get_ticks_usec()-started
	result.scope="CPU/headless, GPU cost excluded"
	var file:=FileAccess.open("user://visual-followups-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("VISUAL_FOLLOWUPS_PERFORMANCE: ",JSON.stringify(result))
	sad.queue_free();await get_tree().process_frame;get_tree().quit(0)
func profile() -> void:
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var world=load("res://imported.tscn").instantiate();get_tree().root.add_child(world);await get_tree().process_frame
	world.set_process(false);world.set_physics_process(false)
	world.xr_active=true
	if not world.enter_source_title_options():get_tree().quit(1);return
	world.source_options_state.page=2;world.source_options_state.navigation=preload("res://source_main_menu.gd").initialize(0,3)
	var started:=Time.get_ticks_usec()
	for frame in range(60):
		if not world.process_source_options(0,0):get_tree().quit(2);return
	var result:Dictionary={"controller_menu":{"frames":60,"total_us":Time.get_ticks_usec()-started,"legacy_compositor":world.source_options_screen.panel.preview.compositor!=null}}
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	if args.has("--legacy-portal-profile"):manifest.erase("cutsceneSequencePortalCaches")
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var session=preload("res://source_sequence_portal_session.gd").new();add_child(session)
	if not session.setup(content,manifest,tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}):push_error(session.fault);get_tree().quit(3);return
	session.audio.stream.stop_stream()
	result.portal_parts=[]
	for part in [0,1,2]:
		started=Time.get_ticks_usec()
		for index in [1,30,60,90,120,150,180,210]:
			if not session.present_frame(part,index):push_error(session.fault);get_tree().quit(4);return
		result.portal_parts.append({"part":part,"frames":8,"total_us":Time.get_ticks_usec()-started})
	result.portal=session.portal_performance
	var file:=FileAccess.open("user://frontend-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("FRONTEND_PERFORMANCE: ",JSON.stringify(result))
	session.queue_free();world.queue_free();await get_tree().process_frame;get_tree().quit(0)

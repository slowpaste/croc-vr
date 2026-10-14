extends Node3D
func _ready() -> void:call_deferred("profile")
func profile() -> void:
	var world=load("res://imported.tscn").instantiate();get_tree().root.add_child(world)
	await get_tree().process_frame
	world.set_process(false);world.set_physics_process(false)
	var player=world.source_player_actor
	if not is_instance_valid(player):get_tree().quit(1);return
	for actor in world.source_actors:actor.set_process(false)
	var results:Dictionary={"renderer":RenderingServer.get_video_adapter_name(),"cases":{}}
	var handles:Array=[]
	for i in range(player.handles.size()):
		if str(player.handles[i].get("name","")) in ["CROCJMP3.ANI","CROCATK2.ANI","CROCSMP1.ANI","CROCVICT.ANI"]:handles.append(i)
	if handles.is_empty():get_tree().quit(2);return
	var started:=Time.get_ticks_usec()
	var worst:=0
	for i in range(40):
		var sample:=Time.get_ticks_usec()
		if not player.select_animation(handles[i%handles.size()],true):get_tree().quit(3);return
		worst=maxi(worst,Time.get_ticks_usec()-sample)
	results.cases.animation_restart={"count":40,"total_us":Time.get_ticks_usec()-started,"worst_us":worst}
	started=Time.get_ticks_usec()
	var spawn_us:=0;var tick_us:=0
	for i in range(3):
		var previous:Array=world.source_actors.duplicate()
		world.source_pickup_counts[1]=10
		var spawn_start:=Time.get_ticks_usec()
		if not world.lose_source_pickups():get_tree().quit(4);return
		spawn_us+=Time.get_ticks_usec()-spawn_start
		var tick_start:=Time.get_ticks_usec()
		for tick in range(3):world.tick_source_actors()
		tick_us+=Time.get_ticks_usec()-tick_start
		for actor in world.source_actors.duplicate():
			if not previous.has(actor):world.remove_source_actor(actor)
	results.cases.pickup_scatter={"count":3,"total_us":Time.get_ticks_usec()-started,"spawn_us":spawn_us,"tick_us":tick_us}
	var pcm:=PackedByteArray();pcm.resize(2048)
	for i in range(1024):pcm.encode_s16(i*2,(i*137)%65536-32768)
	started=Time.get_ticks_usec()
	for i in range(100):preload("res://source_spu_voice_mix.gd").mono16_block(pcm,0,1024,250,-250)
	results.cases.sound_mix={"blocks":100,"frames_per_block":1024,"total_us":Time.get_ticks_usec()-started}
	var path:=OS.get_user_data_dir().path_join("interaction-performance.json")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(results));file.close()
	print("INTERACTION_PERFORMANCE: ",JSON.stringify(results))
	world.queue_free();await get_tree().process_frame;get_tree().quit(0)

extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var path := "user://campaign-save-test-"+str(OS.get_process_id())+".bin"
	assert(not FileAccess.file_exists(path))
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=path
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_menu_progress_flags={0:0x8006,4:0x8006,43:0x8000,45:0x8000}
	world.source_stage_pickup_slots=[1,0,0,1,0,0,0,1]
	world.source_menu_announcement_history=[1,2,3,4,5,6,7,8]
	world.source_menu_state.selected_index=12;world.source_pickup_counts[3]=27
	assert(world.write_source_campaign().written)
	var stored := preload("res://source_save_store.gd").new(path).read_record()
	var decoded := preload("res://source_campaign_save.gd").decode(stored.record)
	assert(decoded.level==10 and decoded.room==3 and decoded.selection==12 and decoded.lives==27 and decoded.percentage==13)
	assert(decoded.flags[0]==0x8006 and decoded.flags[4]==0x8006 and decoded.flags[43]==0x8000 and decoded.flags[45]==0x8000)
	assert(decoded.pickups==[128,0,0,16,0,0,0,1] and decoded.announcement_history==[1,2,3,4,5,6,7,8])
	# An Options write preserves every saved campaign word.
	var options=preload("res://source_options_session.gd").initialize({"music":40,"effects":119,"mode":0})
	options.scheme=2
	assert(world.write_source_options(options).written)
	var changed := preload("res://source_save_store.gd").new(path).read_record()
	for word in range(63):
		if word not in preload("res://source_save_record.gd").SETTINGS_WORDS:assert(changed.record.decode_u32(word*4)==stored.record.decode_u32(word*4))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(path)==OK)
	print("PASS: live campaign state persists room/progress/lives/pickups/history, subsequent Options write preserves campaign")
	quit(0)

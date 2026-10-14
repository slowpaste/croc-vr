extends SceneTree
const Record=preload("res://source_save_record.gd")
const Store=preload("res://source_save_store.gd")
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var path := "user://live-options-write-test-"+str(OS.get_process_id())+".bin"
	assert(not FileAccess.file_exists(path))
	var world=load("res://imported.tscn").instantiate()
	world.source_options_save_path=path
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	assert(world.enter_source_title_options())
	world.source_options_state.navigation.selected=2
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==4)
	world.source_options_state.scheme=2;world.source_options_state.screen_offset=Vector2i(-8,24)
	world.source_music_volume=80;world.source_effects_restore_volume=119
	world.source_options_state.effects_restore_volume=119
	world.source_options_state.navigation.selected=1
	assert(world.process_source_options(0,0x800000))
	assert(world.source_options_state.pending_action=="" and world.source_options_state.write_notice_ticks==30)
	var persisted := Store.new(path).read_record()
	assert(not persisted.has("fault"))
	var options := Record.options(persisted.record)
	assert(options.music==80 and options.effects==119 and options.scheme==2 and options.screen_x== -8 and options.screen_y==24)
	for tick in range(30):
		assert(world.process_source_options(0,0) and world.source_options_screen.panel.notice.visible)
	assert(world.process_source_options(0,0) and not world.source_options_screen.panel.notice.visible)
	# Corrupt both copies: menu reports failure and remains responsive.
	var corrupt: PackedByteArray=persisted.record+persisted.record;corrupt[12]^=1;corrupt[268]^=1
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(corrupt);file.close()
	assert(world.process_source_options(0,0x800000))
	assert(world.source_options_state.write_notice_ticks== -30 and world.source_options_state.pending_action=="")
	assert(FileAccess.get_file_as_bytes(path)==corrupt)
	assert(world.process_source_options(0,0) and world.source_options_screen.panel.notice.visible)
	assert(world.process_source_options(0,0x100000) and world.source_options_state.page==1)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(path)==OK)
	print("PASS: live Write Options persists original records, original30-tick success notice and corrupt-save error keeps menu responsive")
	quit(0)

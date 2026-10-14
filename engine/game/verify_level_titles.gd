extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world)
	for frame in range(30):await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_fade_phase=""
	world.update_source_level_title(0)
	assert(world.source_level_title.visible)
	assert(world.source_level_title.rendered_labels[0]==world.source_level_title_names[10])
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/level-title-desktop.png")
	world.source_level_title_remaining=2.5
	world.map_name="MP010_02.MAP";world.update_source_level_title(0)
	assert(is_equal_approx(world.source_level_title_remaining,2.5),"Room changes restarted the stage title")
	world.map_name="MP011_00.MAP";world.update_source_level_title(0)
	assert(world.source_level_title.rendered_labels[0]==world.source_level_title_names[11])
	assert(is_equal_approx(world.source_level_title_remaining,6.0))
	world.update_source_level_title(6.1);world.update_source_level_title(0)
	assert(not world.source_level_title.visible,"Gameplay title did not expire")
	world.source_main_mode=5;world.source_menu_state.selected_index=0
	world.source_menu_state.save_mode=0;world.source_menu_state.dialog_mode=0
	world.update_source_level_title(30)
	assert(world.source_level_title.visible and world.source_level_title_level==10)
	world.source_menu_state.selected_index=1;world.update_source_level_title(0)
	assert(world.source_level_title_level==11)
	world.source_fade_phase="out";world.update_source_level_title(5)
	assert(not world.source_level_title.visible)
	world.source_fade_phase="";world.source_main_mode=4;world.map_name="MP010_00.MAP"
	world.xr_active=true;world.update_source_level_title(0)
	assert(world.source_level_title.visible and world.source_level_title.get_parent()==world.head)
	assert(world.source_level_title.text_material.get_shader_parameter("physical_panel"))
	assert(is_equal_approx(world.source_level_title.position.z,-4.0),"VR title is not at a readable physical distance")
	if DisplayServer.get_name()!="headless":
		world.update_camera()
		world.camera.global_transform=world.head.global_transform
		world.hud.hide()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/level-title-vr-preview.png")
	world.source_main_mode=0;world.update_source_level_title(0)
	assert(not world.source_level_title.visible)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: canonical stage names in gameplay and selector, subroom stability, timing/fade gating, VR physical panel and title-screen hiding")
	quit(0)


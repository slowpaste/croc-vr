extends SceneTree
const Hud=preload("res://source_gameplay_hud.gd")
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var input: Dictionary={"level":10,"crystals":5,"gobbos":0,"lives":3,"mask":1,"gobbo_enabled":true,"bonus_revision":0,"bonus_request":60,"life_request":240}
	var state:=Hud.step({},input,0,true)
	assert(Hud.layout(state).track.labels[0].glyphs.size()==6)
	state=Hud.step(state,input,61,true)
	assert(Hud.layout(state).track.labels[0].glyphs.is_empty())
	assert(Hud.layout(state).bonus.labels[0].glyphs.is_empty())
	input.crystals=6;state=Hud.step(state,input,62,true)
	assert(Hud.layout(state).track.labels[0].glyphs.size()==2)
	input.crystals=0;state=Hud.step(state,input,63,true);state=Hud.step(state,input,500,true)
	assert(state.crystals_time==60,"Zero-crystal health indication must remain visible")
	input.gobbos=1;state=Hud.step(state,input,501,true)
	assert(state.gobbos_time==60)
	input.bonus_revision=1;input.bonus_request=-1;input.mask=5
	state=Hud.step(state,input,502,true);state=Hud.step(state,input,1000,true)
	assert(Hud.layout(state).bonus.labels[0].glyphs.size()==2,"Collection hold did not retain exactly the collected colors")
	input.bonus_revision=2;input.bonus_request=0;state=Hud.step(state,input,1001,true)
	assert(Hud.layout(state).bonus.labels[0].glyphs.is_empty())
	input.crystals=99;state=Hud.step(state,input,1002,true);state=Hud.step(state,input,1063,true)
	input.crystals_revision=1;state=Hud.step(state,input,1064,true)
	assert(state.crystals_time==60,"Collection at the crystal cap did not reveal the counter")
	state=Hud.step(state,input,1200,true,true)
	assert(Hud.layout(state,true).track.labels[0].glyphs.size()==7)
	assert(Hud.layout(state,true).bonus.labels[0].glyphs.size()==2)
	var world=load("res://imported.tscn").instantiate();root.add_child(world)
	for frame in range(30):await process_frame
	world.set_process(false);world.set_physics_process(false);world.source_fade_phase=""
	world.source_pickup_counts={1:25,2:3,3:4};world.source_bonus_mask=5
	world.update_source_gameplay_hud();world.update_source_level_title(0)
	assert(world.source_gameplay_hud.visible and not world.hud.visible)
	assert(world.source_gameplay_hud_state.gobbo_enabled,"Ordinary levels lost the Gobbo counter")
	assert(world.source_gameplay_hud.track.previous_layout.labels[0].glyphs.any(func(g):return int(g.sprite)==11))
	assert(world.source_gameplay_hud.bonus.mesh.get_surface_count()>0)
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/gameplay-hud-desktop.png")
	world.xr_active=true;world.update_source_gameplay_hud();world.update_source_level_title(0);world.update_camera()
	assert(world.source_gameplay_hud.get_parent()==world.head and world.source_gameplay_hud.vr)
	world.source_main_mode=8;world.source_options_parent_mode=4
	world.source_level_title_remaining=0
	world.update_source_gameplay_hud();world.update_source_level_title(0)
	assert(world.source_gameplay_hud.visible and world.source_level_title.visible,"Paused gameplay lost its inventory or level name")
	world.source_main_mode=4;world.update_source_gameplay_hud();world.update_source_level_title(0)
	world.camera.global_transform=world.head.global_transform
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/gameplay-hud-vr-preview.png")
	world.source_main_mode=0;world.update_source_gameplay_hud()
	assert(not world.source_gameplay_hud.visible)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: original HUD sprites, temporary counters, zero-crystal warning, collected-color hold/off, capped pickup cue, pause inventory, VR placement and frontend hiding")
	quit(0)

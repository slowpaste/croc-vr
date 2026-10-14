extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.tick_source_actors()
	var player=world.source_player_actor
	world.camera.global_position=player.global_position+Vector3(1.3,1.8,2)
	world.camera.look_at(player.global_position+Vector3(0,0.15,0))
	world.camera.current=true
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	before.save_png(ProjectSettings.globalize_path("res://../build/contact-shadows.png"))
	for actor in world.source_actors:
		if is_instance_valid(actor.contact_shadow):actor.contact_shadow.hide()
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image()
	var darkened:=0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if b.get_luminance()-a.get_luminance()>0.02:darkened+=1
	assert(darkened>100,"Original contact shadows did not darken the rendered ground")
	print("PASS: real room shadows darken ground; affected pixels=",darkened)
	world.queue_free();await process_frame;quit(0)

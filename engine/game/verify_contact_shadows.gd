extends SceneTree
const Shadow = preload("res://source_contact_shadow.gd")
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	assert(Shadow.radius_units(4096,65536,0)==1536)
	assert(Shadow.radius_units(4096,32768,0)==768)
	assert(Shadow.radius_units(4096,65536,1024)==1152)
	assert(Shadow.radius_units(4096,65536,8192)==768)
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.tick_source_actors()
	var count := 0
	for actor in world.source_actors:
		if is_instance_valid(actor.contact_shadow) and actor.contact_shadow.visible:
			count+=1
			assert(is_equal_approx(actor.contact_shadow.global_position.y,actor.source_ground.height_units*world.CELL_METERS/4096.0+0.002))
	assert(count>0)
	var bank:String="TK%02d_ENM.BIN" % int(world.room_data.style)
	assert(world.active_texture_animations.has(bank))
	var before:PackedByteArray=world.active_texture_animations[bank].bitmap.get_data()
	for tick in range(6):world.active_texture_animations[bank].advance()
	assert(before!=world.active_texture_animations[bank].bitmap.get_data())
	var player=world.source_player_actor
	var original_flags:int=player.primary_flags
	player.primary_flags|=0x20;player.refresh_source_render_pose()
	assert(player.contact_shadow.visible)
	var original_mesh=player.contact_shadow.mesh
	player.source_ground.height_units+=2048;player.refresh_source_render_pose()
	assert(player.contact_shadow.mesh==original_mesh)
	player.primary_flags|=0x80000;player.refresh_source_render_pose();assert(not player.contact_shadow.visible)
	player.primary_flags=original_flags&~0x20;player.refresh_source_render_pose();assert(not player.contact_shadow.visible)
	world.queue_free();await process_frame
	print("PASS: native shadow size/height, live casters, platform ground, shared geometry, hidden/disabled flags; casters=",count)
	quit(0)

extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var scene := load("res://imported.tscn") as PackedScene
	if scene == null: quit(1); return
	var world = scene.instantiate()
	root.add_child(world)
	await process_frame
	assert(world.source_music_volume == 80 and world.source_effects_volume == 127 and world.source_cd_stereo_flag == 1)
	assert(world.source_cd_fade_counter == 80 and world.source_cd_mix_state.mix == [80,80,0,0] and world.source_cd_mix_state.decrement == 10)
	assert(world.load_room("MP010_01.MAP"))
	assert(world.source_cd_mix_state.mix == [80,80,0,0] and world.source_music_volume == 80)
	world.queue_free(); await process_frame
	print("PASS: original startup music80/effects127/stereo1, CD restore80/decrement10 and retained room-load options")
	quit(0)

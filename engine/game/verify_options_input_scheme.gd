extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.vr_controls.layout="classic";world.source_main_mode=4
	for scheme in range(3):
		world.source_options_state.scheme=scheme
		for sample in [{"actions":["move_forward"],"raw":65535&~0x10},{"actions":["move_back"],"raw":65535&~0x40},{"actions":["jump"],"raw":65535&~0x4000},{"actions":["attack"],"raw":65535&~0x8000},{"actions":["attack","move_forward"],"raw":65535&~0x8010},{"actions":["attack","jump"],"raw":65535&~0xc000}]:
			world.update_source_input(0,0)
			for action in sample.actions:Input.action_press(action)
			world.sample_source_player_controls()
			for action in sample.actions:Input.action_release(action)
			var expected: int=preload("res://source_input.gd").digital_pad(int(sample.raw),scheme,4)
			if world.source_input_held_mask!=expected or world.source_input_pressed_mask!=expected:push_error("Live scheme%d held/pressed masks differ for%s"%[scheme,str(sample.actions)]);quit(1);return
			world.sample_source_player_controls()
			if world.source_input_held_mask!=0 or world.source_input_pressed_mask!=0 or world.source_input_released_mask!=expected:push_error("Classic scheme release edge differs");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS:18 live classic scheme/action combinations match original held and pressed masks, including scheme2 modifiers")
	quit(0)

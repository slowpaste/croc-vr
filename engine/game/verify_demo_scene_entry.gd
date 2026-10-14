extends SceneTree
class EntryWorld extends "res://imported_main.gd":
	var factory_entry: Dictionary = {}
	func create_source_player() -> Node3D:
		factory_entry={"motion":source_player_movement_state.motion,"magnitude":source_player_movement_state.magnitude,"field456":source_player_movement_state.field456,"suppression":source_input_suppression_count}
		return super.create_source_player()
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	world.set_script(EntryWorld)
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	for pair in world.runtime_tables.attractDemos.destinations:
		world.source_player_movement_state.motion = Vector2i(100,-100)
		world.source_input_suppression_count = 7
		if not world.initialize_source_demo_scene({"level":int(pair[0]),"room":int(pair[1])}) or world.source_main_mode != 3 or world.source_player_actor == null or world.source_demo_frames.size() != 900:
			push_error(world.source_transition_fault)
			quit(1)
			return
		# Outer13034 resets movement before the factory. The imported startup
		# may then move Croc through a door (30/1 does), or PausePlayer8093.
		if world.factory_entry != {"motion":Vector2i.ZERO,"magnitude":0,"field456":0,"suppression":0} or world.source_input_suppression_count not in [0,1] or world.source_controller_enabled or world.visual.visible or world.source_input_held_mask != 0:
			push_error("Original demo scene entry state/reset differs: "+str({"motion":world.source_player_movement_state.motion,"suppression":world.source_input_suppression_count,"enabled":world.source_controller_enabled,"visible":world.visual.visible,"held":world.source_input_held_mask}))
			quit(1)
			return
		for tick in range(120):
			if not world.sample_source_demo_controls(tick):
				quit(1)
				return
			world.tick_source_actors()
		var expected := 0
		for entity in world.room_data.entities:
			if entity.name == "Crystal": expected += 1
		var crystals := 0
		for node in world.source_actors:
			if node.source_name == "Crystal": crystals += 1
		if not world.source_runtime_enabled or not world.pickups.is_empty() or (expected > 0 and crystals == 0):
			push_error("Attract scene substituted provisional crystal pickups"); quit(1); return
		for node in world.source_actors:
			if node.vm.fault != "":
				push_error(world.map_name+" "+node.source_name+" "+node.vm.fault)
				quit(1)
				return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	print("PASS: all five original demo scene entries, initial arrivals, native player, recording and motion/input reset")
	quit(0)

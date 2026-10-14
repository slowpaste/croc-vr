extends SceneTree
func expression(value: int) -> Array: return [{"op":4,"value":value},{"op":18}]
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world)
	await process_frame;world.set_physics_process(false)
	var caller = world.source_player_actor
	if caller == null: push_error("Missing original controller");quit(1);return
	world.source_exit_door_id = 7
	assert(caller.asl_command({"op":168,"args":[]},caller.vm) == "continue")
	assert(world.source_input_suppression_count == 1)
	assert(caller.asl_command({"op":197,"args":[expression(1<<16)]},caller.vm) == "continue")
	assert(world.source_transition_state == 2 and world.source_pending_exit.origin.id == 0)
	assert(world.source_pending_exit.origin.level == 10 and world.source_pending_exit.origin.room == 0)
	for tick in range(100):
		assert(world.process_source_exit())
		if world.map_name == "MP010_01.MAP" and world.source_fade_phase == "": break
	assert(world.map_name == "MP010_01.MAP" and world.source_transition_state == 0 and world.source_fade_phase == "")
	assert(world.source_player_actor != null and world.source_player_actor.vm.fault.is_empty())
	assert(world.source_input_suppression_count == 0)
	caller = world.source_player_actor;world.source_exit_door_id = 7
	assert(caller.asl_command({"op":96,"args":[expression(11<<16),expression(0)]},caller.vm) == "continue")
	assert(world.source_transition_state == 5 and world.source_pending_exit.origin.id == 7)
	assert(world.source_pending_exit.destination == "MP011_00.MAP")
	var previous: Dictionary = world.source_pending_exit.duplicate(true)
	assert(caller.asl_command({"op":197,"args":[expression(-65536)]},caller.vm) == "unsupported")
	assert(world.source_pending_exit == previous and world.source_transition_state == 5)
	world.source_pickup_counts = {1:7,2:2,3:8}
	world.source_extended_globals[250] = -12345
	for tick in range(100):
		assert(world.process_source_exit())
		if world.map_name == "MP011_00.MAP" and world.source_fade_phase == "": break
	assert(world.map_name == "MP011_00.MAP" and world.source_transition_state == 0 and world.source_fade_phase == "")
	assert(world.source_pickup_counts == {1:7,2:2,3:8} and world.source_extended_globals[250] == -12345)
	assert(world.source_player_actor != null and world.source_player_actor.vm.fault.is_empty())
	world.stop_imported_audio();world.queue_free();await process_frame;await create_timer(0.25).timeout
	print("PASS: forced door and cross-level requests complete fades/arrival, preserve inventory/globals and reject missing rooms without replacing pending data")
	quit(0)

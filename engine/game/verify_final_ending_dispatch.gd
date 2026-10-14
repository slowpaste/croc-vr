extends SceneTree
class EndingWorld extends "res://imported_main.gd":
	var scenes: Array = []
	var credits: Array = []
	func enter_source_sequence(scene_id: int) -> bool:
		scenes.append(scene_id)
		if is_instance_valid(source_cutscene_screen): source_cutscene_screen.free()
		source_cutscene_screen = Node3D.new(); add_child(source_cutscene_screen)
		source_fade_state.clear(); source_fade_phase = ""
		return true
	func enter_source_credits(variant: int, available: bool, return_mode: int = 0) -> bool:
		credits = [variant,available,return_mode]; return true
func _initialize() -> void:
	for level in [47,54]:
		for next_level in [false,true]:
			var world := EndingWorld.new()
			world.map_name = "MP%03d_00.MAP"%level
			world.source_pending_exit = {"source_level":level,"target_level":0}
			assert(world.apply_source_next_level_return() if next_level else world.apply_source_stage_return())
			var sequence := 15 if level == 47 else 16
			assert(world.scenes == [sequence] and world.source_ending_root == sequence)
			assert(world.source_pending_exit.is_empty())
			assert(world.advance_source_ending_route(sequence))
			if level == 47:
				assert(world.scenes == [15,19] and world.credits.is_empty())
				assert(world.advance_source_ending_route(19))
			assert(world.credits == ([0,true,5] if level == 47 else [1,false,0]))
			world.free()
	for transition in [3,4]:
		var world := EndingWorld.new()
		world.map_name = "MP047_00.MAP"
		world.source_transition_state = transition
		world.source_pending_exit = {"source_level":47,"target_level":0}
		world.source_stage_stats_state = {"busy":1}
		world.source_fade_state = {"active":true,"ready":true}
		assert(world.process_source_exit())
		assert(world.scenes == [15] and world.source_fade_state.is_empty() and world.source_fade_phase.is_empty())
		world.free()
	print("PASS: both stage-exit paths dispatch normal15->OUTRO19->credits0 and true16->credits1")
	quit(0)

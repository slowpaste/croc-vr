extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world := preload("res://imported_main.gd").new()
	var stats := Node3D.new(); root.add_child(stats)
	world.source_stage_stats_renderer = stats
	world.source_stage_stats_state = {"busy":1}
	world.source_stage_stats_bindings = {"old":true}
	var text := MeshInstance3D.new(); root.add_child(text); world.source_main_menu_text = text
	var fade := preload("res://source_fade_overlay.gd").new(); root.add_child(fade)
	fade.set_source_white_level(255); world.source_fade_overlay = fade
	world.hide_source_cinematic_world()
	assert(not stats.visible and stats.is_queued_for_deletion())
	assert(world.source_stage_stats_renderer == null and world.source_stage_stats_state.is_empty() and world.source_stage_stats_bindings.is_empty())
	assert(not text.visible and not fade.visible)
	world.free(); text.queue_free(); fade.queue_free(); await process_frame
	print("PASS: cinematic entry retires stage results and hides menu text and inherited white/black overlays")
	quit(0)

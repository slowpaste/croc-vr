extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutscenePoses[0].file)))
	var availability = preload("res://source_cutscene_availability.gd")
	var state: Dictionary = availability.initialize(data.frames,0)
	state = availability.consume_ready(state,4,4)
	assert(state.ready_indices.is_empty() and state.cursor == 0)
	state = availability.consume_ready(state,5,4)
	assert(state.ready_indices == [0] and state.cursor == 1)
	state = availability.consume_ready(state,5,4)
	assert(state.ready_indices.is_empty())
	assert(availability.consume_ready(state,4,4).has("fault"))
	var total := 1
	for batch in range(5):
		state = availability.consume_ready(state,1455,64)
		total += state.ready_indices.size()
	assert(total == 291 and state.complete and state.cursor == 291)
	assert(availability.consume_ready(state,1455,64).ready_indices.is_empty())
	assert(availability.consume_ready(state,1455,0).has("fault"))
	print("PASS: original AN2 record sector boundaries, no early/duplicate reads, bounded draining and291-record completion")
	quit(0)

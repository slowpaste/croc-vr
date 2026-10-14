extends SceneTree
func _initialize() -> void:
	var layout := preload("res://source_spu_layout.gd").new()
	# Same numeric allocation observations as the independent stage50 trace.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-spu-layout-stage50.json"))
	for observation in fixture.observations:
		var sample := layout.append_sample("fixture","",int(observation.size))
		assert(sample.address == int(observation.address))
	var retained_end: int = int(fixture.observations[7].address)+int(fixture.observations[7].size)
	var result := layout.retire_after(7)
	assert(result.retained == 8 and result.released.size() == fixture.observations.size()-8)
	assert(result.cursor == retained_end)
	for index in range(8,fixture.observations.size()):
		var observation: Dictionary = fixture.observations[index]
		assert(layout.append_sample("reload","",int(observation.size)).address == int(observation.address))
	assert(layout.retire_after(-1).has("fault"))
	assert(layout.retire_after(layout.resident_samples.size()).has("fault"))
	assert(layout.retire_after(0).retained == 0 and layout.cursor == 4160)
	assert(layout.append_sample("first","",16).address == 4160)
	print("PASS: native sound-bank boundary retirement preserves retained addresses, reuses released space and handles the zero-boundary reset")
	quit(0)

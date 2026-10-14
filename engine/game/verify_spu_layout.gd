extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0: quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-spu-layout-stage50.json"))
	assert(fixture.sourceSha256 == manifest.sourceSha256)
	var layout := preload("res://source_spu_layout.gd").fresh_stage(content,manifest,"MP050_00.MAP")
	assert(not layout.has("fault") and layout.samples.size() == fixture.observations.size())
	for index in range(layout.samples.size()):
		var sample: Dictionary = layout.samples[index];var original: Dictionary = fixture.observations[index]
		assert(sample.address == int(original.address) and sample.address == int(original.hint) and sample.size == int(original.size))
	assert(preload("res://source_spu_layout.gd").fresh_stage(content,manifest,"missing").has("fault"))
	print("PASS: Godot fresh SPU layout matches all50 independent original allocation records and rejects missing stage bindings")
	quit(0)

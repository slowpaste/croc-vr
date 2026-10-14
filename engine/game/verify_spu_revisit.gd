extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0: quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var layout := preload("res://source_spu_layout.gd").new()
	# Independent protected original33/2 ->33/1 ->33/2 ready-state observations.
	for observation in [{"room":"MP033_02.MAP","count":33,"hint":0x58010},{"room":"MP033_01.MAP","count":29,"hint":0x48ac0},{"room":"MP033_02.MAP","count":33,"hint":0x58010}]:
		assert(not layout.enter_room(content,manifest,observation.room).has("fault"))
		assert(layout.permanent_boundary == 7 and layout.controller_boundary == 22)
		assert(layout.resident_samples.size() == observation.count)
		# Original allocator recorded ambience body42304 bytes after room samples.
		assert(not layout.reserve_ambience(42304).has("fault"))
		assert(layout.cursor == observation.hint)
	assert(not layout.enter_room(content,manifest,"MP050_00.MAP").has("fault"))
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-spu-layout-stage50.json"))
	assert(layout.resident_samples.size() == original.observations.size())
	for index in range(layout.resident_samples.size()):
		assert(layout.resident_samples[index].address == int(original.observations[index].address))
	assert(layout.enter_room(content,manifest,"missing").has("fault"))
	print("PASS: source room-bank lifecycle reproduces all three independently observed revisit counts, retained boundaries and post-ambience hints")
	quit(0)

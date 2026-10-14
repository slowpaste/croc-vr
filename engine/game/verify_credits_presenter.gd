extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	for variant in [0,1]:
		var presenter := preload("res://source_credits_presenter.gd").new(); root.add_child(presenter)
		if not presenter.setup(content,manifest,variant): push_error(presenter.fault); quit(1); return
		var pages := 0
		for tick in range(20000):
			var parsing := int(presenter.state.mode) == 1
			var result: Dictionary = presenter.advance()
			if result.has("fault"): push_error(str(result.fault)); quit(1); return
			if parsing:
				pages += 1
				var glyphs := 0
				for line in presenter.state.lines:
					for index in str(line.text).length():
						if str(line.text).unicode_at(index) > 32: glyphs += 1
				if glyphs > 0 and presenter.text.mesh.surface_get_array_len(0) != glyphs*6:
					push_error("Credits page lost original glyphs"); quit(1); return
			if result.complete: break
		if not presenter.state.complete or pages != (31 if variant == 0 else 34): push_error("Credits presenter ended before all pages"); quit(1); return
		presenter.queue_free(); await process_frame
	print("PASS: both complete credits variants build every original heading/body glyph and finish original page timing")
	quit(0)

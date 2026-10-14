extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	option = args.find("--scene")
	var scene := int(args[option+1]) if option >= 0 else 16
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var viewer := Camera3D.new(); root.add_child(viewer); viewer.position = Vector3(1,1.6,2)
	var display := preload("res://source_sequence_screen.gd").new(); root.add_child(display)
	if not display.setup(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":true,"prefill":0,"phase_us":6667},viewer):
		push_error(display.session.fault); quit(1); return
	var anchored := display.global_transform
	var white := preload("res://source_cutscene_flow.gd").entry_fade(scene) == 3
	if display.screen.material_override.get_shader_parameter("source_white_level") != (255 if white else 0) or display.screen.material_override.get_shader_parameter("source_black_level") != (0 if white else 255):
		push_error("Sequence screen used the wrong original entry fade"); quit(1); return
	var expected_frames: int = display.session.player.frames.size()
	for tick in range(expected_frames+160):
		viewer.position.x += 0.001; viewer.rotation.y += 0.001
		var result: Dictionary = display.advance(33334,0,1)
		if result.has("fault") or display.global_transform != anchored:
			push_error("Scenic screen fault or viewer-following movement"); quit(1); return
		if display.screen.material_override.get_shader_parameter("source_texture") != display.session.output_texture():
			push_error("Screen retained a retired compositor texture"); quit(1); return
		await process_frame
		if result.complete: break
	if not display.session.complete or display.session.player.last_index != expected_frames-1:
		push_error("Scenic screen did not finish sequence file"); quit(1); return
	display.queue_free(); viewer.queue_free(); await process_frame; await create_timer(0.2).timeout
	print("PASS: world-anchored sequence",scene," screen displays all",expected_frames," scenic frames, original entry fade and refreshed graph textures through head motion")
	quit(0)

extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var triangle := SurfaceTool.new(); triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3.ZERO,Vector3.RIGHT,Vector3.UP]: triangle.add_vertex(vertex)
	var placeholder := triangle.commit() # Timing/state test; geometry has its own gate.
	for pair in [["INTRO",0],["DANTD",15],["OUTRO",19],["CRYSD",16]]:
		var entry: Dictionary = {}
		for candidate in manifest.cutsceneSequences:
			if candidate.name == pair[0]: entry = candidate; break
		var sequence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
		sequence.scene_id = int(pair[1])
		var packs: Array = []; var cache: Array = []; var expected_parts: Array = []
		for part in sequence.parts:
			packs.append(JSON.parse_string(FileAccess.get_file_as_string(content.path_join(part.model))))
			for frame in part.frames: cache.append(placeholder); expected_parts.append(packs.size()-1)
		var binding := preload("res://source_cutscene_resources.gd").resolve(int(pair[1]),tables,manifest)
		var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(binding.texture.file)))
		var texture := ImageTexture.create_from_image(Image.load_from_file(content.path_join(binding.texture.image)))
		var player := preload("res://source_cutscene_player.gd").new(); root.add_child(player)
		if not player.setup_sequence(sequence,packs,tables,atlas,texture,0,cache): push_error("Multi-part setup failed"); quit(1); return
		var incoming := int(player.fade.kind)
		for index in range(cache.size()):
			var required := int(player.frames[index].stream.requiredSectorCount)
			var waiting: Dictionary = player.present_next(required-1,0)
			if not waiting.get("waiting",false) or player.last_index != index-1: push_error("Part record presented before its actual sector"); quit(1); return
			var result: Dictionary = player.present_next(required,0)
			if result.has("fault") or result.index != index or result.part_index != expected_parts[index] or bool(result.complete) != (index == cache.size()-1):
				push_error("Part boundary/model bank/final fade differs: "+str(pair)+" "+str(index)+" "+str(result)); quit(1); return
			if int(result.part_index) < packs.size()-1 and int(result.tag) == 13 and bool(player.flow.ending): push_error("Intermediate part started the terminal fade"); quit(1); return
		if incoming != (3 if int(pair[1]) in [15,16] else 1): push_error("Sequence used SAD's fade instead of original entry fade"); quit(1); return
		if packs.size() > 1:
			if not player.setup_sequence(sequence,packs,tables,atlas,texture,0,cache): quit(1); return
			var skip_index := -1
			for index in range(100):
				var frame: Dictionary = player.frames[index]
				var skipped: Dictionary = player.present_next(int(frame.stream.requiredSectorCount),0x800000)
				if skipped.has("fault"): push_error(str(skipped.fault)); quit(1); return
				if skipped.complete: skip_index = index; break
			if skip_index < 0 or player.current_part != 0 or not bool(player.flow.ending):
				push_error("Ready user fade did not stop the whole multi-part file"); quit(1); return
		player.queue_free(); await process_frame
		print("SEQUENCE_PLAYER: ",pair[0]," parts=",packs.size()," frames=",cache.size())
	print("PASS: opening, both ending sequences and OUTRO retain sector gates, model-bank changes, intermediate end markers, skip and final-part-only fade")
	quit(0)

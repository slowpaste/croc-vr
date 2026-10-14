extends SceneTree
# Build the same prepared VR meshes without serializing each intermediate pass.
func _initialize() -> void:
	call_deferred("bake")
func bake() -> void:
	var args := OS.get_cmdline_user_args()
	var content: String = args[args.find("--content") + 1]
	var scene := int(args[args.find("--scene") + 1])
	var manifest_path := content.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content, manifest, tables, scene, {"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"):
		push_error(str(config.fault)); quit(1); return
	var fingerprint := preload("res://source_sequence_cache_identity.gd").fingerprint(config, tables)
	var folder := "resources/sequence-%02d-portals-r1/" % scene + fingerprint
	DirAccess.make_dir_recursive_absolute(content.path_join(folder))
	var parts: Array = []
	var metadata_parts: Array = []
	for part_index in range(config.parts.size()):
		var part: Dictionary = config.parts[part_index]
		var frames: Array = []
		var metadata_frames: Array = []
		for index in range(part.data.frames.size()):
			var plan := preload("res://source_cutscene_frame_plan.gd").build(part, part.room_atlas, index)
			if plan.has("fault") or bool(plan.point_lighting_required):
				push_error("Unqualified sequence frame: " + str(plan)); quit(2); return
			var passes: Array = []
			for pass_data in plan.passes:
				if pass_data.kind == "opaque":
					var meshes := {}
					for source in ["actor", "room", "sky"]:
						var commands: Array = []
						for command in pass_data.commands:
							if command.source == source:
								commands.append(command)
						if not commands.is_empty():
							meshes[source] = preload("res://source_cutscene_passes.gd").mesh(commands, int(plan.commands))
					passes.append({"kind":"opaque", "meshes":meshes})
				else:
					passes.append({"kind":"blend", "source":pass_data.command.source, "mode":int(pass_data.mode), "mesh":preload("res://source_cutscene_passes.gd").mesh([pass_data.command], int(plan.commands))})
			var frame := {"index":index, "h":int(plan.h), "passes":passes, "commands":int(plan.commands), "blended":int(plan.blended)}
			var corrected := preload("res://source_sequence_sky_correction.gd").apply(frame, part, index)
			if corrected.has("fault"):
				push_error(str(corrected.fault)); quit(3); return
			var prepared := preload("res://source_cutscene_portal.gd").prepare(corrected)
			var saved := {}
			for key in prepared.meshes:
				var file := folder + "/%02d-%04d-%s.res" % [part_index, index, str(key).replace(":", "-")]
				if ResourceSaver.save(prepared.meshes[key], content.path_join(file), ResourceSaver.FLAG_COMPRESS) != OK:
					quit(4); return
				saved[key] = {"file":file, "sha256":FileAccess.get_sha256(content.path_join(file))}
			frames.append({"h":prepared.h, "meshes":saved, "order":prepared.order})
			metadata_frames.append({"index":index, "h":int(plan.h)})
			if index % 100 == 0:
				print("COMPACT_FRAME: scene=", scene, " part=", part_index, " frame=", index, "/", part.data.frames.size())
		parts.append({"frames":frames})
		metadata_parts.append({"frames":metadata_frames})
	var portal_file := folder + "/index.json"
	var output := FileAccess.open(content.path_join(portal_file), FileAccess.WRITE)
	output.store_string(JSON.stringify({"scene_id":scene, "revision":1, "fingerprint":fingerprint, "parts":parts})); output.close()
	var metadata_folder := "resources/sequence-%02d-compositor/" % scene + fingerprint
	DirAccess.make_dir_recursive_absolute(content.path_join(metadata_folder))
	var metadata_file := metadata_folder + "/index.json"
	output = FileAccess.open(content.path_join(metadata_file), FileAccess.WRITE)
	output.store_string(JSON.stringify({"scene_id":scene, "fingerprint":fingerprint, "parts":metadata_parts, "quest3MetadataOnly":true})); output.close()
	manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	manifest.cutsceneSequenceCaches = manifest.get("cutsceneSequenceCaches", []).filter(func(entry): return int(entry.scene_id) != scene)
	manifest.cutsceneSequenceCaches.append({"scene_id":scene, "fingerprint":fingerprint, "file":metadata_file})
	manifest.cutsceneSequencePortalCaches = manifest.get("cutsceneSequencePortalCaches", []).filter(func(entry): return int(entry.scene_id) != scene)
	manifest.cutsceneSequencePortalCaches.append({"scene_id":scene, "revision":1, "fingerprint":fingerprint, "file":portal_file})
	output = FileAccess.open(manifest_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest)); output.close()
	print("PASS: compact sequence ", scene, " prepared directly; parts=", parts.size())
	quit(0)

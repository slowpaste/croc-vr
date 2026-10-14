extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args();var directory:String=args[args.find("--bundle")+1]
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
	assert(index.target=="quest3" and index.requiresOpenXR)
	for pack in index.packs:assert(ProjectSettings.load_resource_pack(directory.path_join(str(pack.file)),false))
	var content:="res://imported_data"
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	assert(manifest.has("quest3Optimized") and manifest.cutsceneSequenceImages.is_empty())
	var state:={"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}
	var samples:=0
	for entry in manifest.cutsceneSequencePortalCaches:
		var session=preload("res://source_sequence_portal_session.gd").new();root.add_child(session)
		assert(session.setup(content,manifest,tables,int(entry.scene_id),state),session.fault)
		assert(session.portal_performance.prepared)
		session.audio.stream.stop_stream()
		for part in range(session.prepared_parts.size()):
			for frame in [0,int(session.prepared_parts[part].frames.size()/2),session.prepared_parts[part].frames.size()-1]:
				assert(session.present_frame(part,frame),session.fault);samples+=1
		session.queue_free();await process_frame
	var sad=preload("res://source_sad_portal_session.gd").new();root.add_child(sad)
	assert(sad.setup_sad(content,manifest,tables,state),sad.fault)
	sad.audio.stream.stop_stream();assert(sad.present_portal(145) and sad.present_portal(290))
	sad.queue_free();await process_frame
	var music:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.musicIndex)))
	var audio_records:Array=music.streams+manifest.cutsceneAudio+manifest.cutsceneSequenceAudio
	for record in audio_records:
		assert(not record.has("file"))
		var reader=preload("res://source_xa_channel_reader.gd").new()
		assert(reader.open_channel(content,record))
		for offset in [0,int(record.sectors)/2,int(record.sectors)-1]:
			var sector:int=int(record.sourceLba)+int(record.firstSector)+int(offset)*8
			assert(not reader.seek_sector(sector,[[0,0],[0,0]]).has("fault"))
			assert(not reader.read_sector().has("fault"))
		reader.close_channel()
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: ",samples," prepared cinematic samples across all ",manifest.cutsceneSequencePortalCaches.size()," sequences; SAD; ",audio_records.size()," compressed audio channels seek/decode without PCM copies")
	quit()

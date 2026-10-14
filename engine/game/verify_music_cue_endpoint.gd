extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	assert(option>=0 and option+1<args.size())
	var content: String=args[option+1]
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var streams: Array=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.musicIndex))).streams
	var bounds: Array=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.bootstrapMusic.file))).endSectorOffsets
	var checked := 0;var bounded := 0
	for cue in range(1,65):
		for variant in [0,1]:
			var plan: Dictionary=preload("res://source_music_selection.gd").plan({"cue":cue,"mode":4,"room":0,"style":0},{},{0:{"variant":variant}},tables.musicCues.pairs,bounds,streams)
			assert(not plan.has("fault"))
			var reader := preload("res://source_xa_channel_reader.gd").new()
			assert(reader.open_channel(content,plan.stream))
			var first := int(plan.stream.sourceLba)+int(plan.stream.firstSector)
			var last_index := mini(int((int(plan.end_sector)-first)/8),int(plan.stream.sectors)-1)
			assert(last_index>=0)
			assert(not reader.seek_sector(first+last_index*8,[[0,0],[0,0]]).has("fault"))
			var last: Dictionary=reader.read_sector()
			assert(not last.has("fault") and not last.get("end",false) and int(last.source_sector)<=int(plan.end_sector))
			var ending: Dictionary=reader.read_sector();assert(ending.get("end",false))
			if last_index+1<int(plan.stream.sectors):
				assert(ending.cue_boundary and int(ending.source_sector)>int(plan.end_sector));bounded+=1
			reader.close_channel();checked+=1
	# Exercise the worker too: its queue must carry the same cue boundary.
	var plan: Dictionary=preload("res://source_music_selection.gd").plan({"cue":64,"mode":4,"room":0,"style":0},{},{},tables.musicCues.pairs,bounds,streams)
	var first := int(plan.stream.sourceLba)+int(plan.stream.firstSector)
	var final_sector := first+int((int(plan.end_sector)-first)/8)*8
	var worker := preload("res://source_xa_worker.gd").new()
	assert(worker.start(content,plan.stream,final_sector,[[0,0],[0,0]])==OK)
	var packets: Array=[]
	for frame in range(300):
		var packet: Dictionary=worker.take()
		if not packet.is_empty():packets.append(packet)
		if packets.size()==2:break
		await process_frame
	worker.stop()
	assert(packets.size()==2 and int(packets[0].source_sector)==final_sector and packets[1].get("end",false))
	print("PASS: ",checked," original cue/variant endpoints; ",bounded," stop before physical XA lane EOF; worker obeys cue64 boundary")
	quit(0)

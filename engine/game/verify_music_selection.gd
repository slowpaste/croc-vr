extends SceneTree
const Selection = preload("res://source_music_selection.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var catalog: Array = []
	for resource in world.manifest.musicBounds:
		if resource.name == "MUSIC.BIN":
			catalog = world.read_json(resource.file).endSectorOffsets
	var pairs: Array = world.runtime_tables.musicCues.pairs
	var result := Selection.select(12,true,pairs,catalog)
	if result.logical != 25 or result.pack != 4 or result.channel != 4 or result.end_sector_offset != int(catalog[24]):
		quit(1)
		return
	result = Selection.select(64,false,pairs,catalog)
	if result.logical != 64 or result.pack != 10 or result.channel != 1 or result.end_sector_offset != 600:
		quit(1)
		return
	for cue in range(1,65):
		for alternate in [false,true]:
			if Selection.select(cue,alternate,pairs,catalog).has("fault"):
				quit(1)
				return
	var index: Dictionary = world.read_json(world.manifest.musicIndex)
	var previous_start := int(index.streams[24].sourceLba)+500
	var current_start := int(index.streams[11].sourceLba)+400
	var request := {"cue":12,"mode":4,"room":2,"style":7,"loop":false}
	var planned := Selection.plan(request,{"cue":12,"room":1},{1:{"variant":1,"start":previous_start},2:{"variant":0,"start":current_start}},pairs,catalog,index.streams)
	if planned.logical != 25 or planned.seek_mode != 2 or planned.start_sector != previous_start or not planned.loop:
		quit(1)
		return
	planned = Selection.plan(request,{"cue":1,"room":1},{2:{"variant":0,"start":current_start}},pairs,catalog,index.streams)
	if planned.logical != 12 or planned.start_sector != planned.pack_start:
		quit(1)
		return
	request.seek_mode = 128
	planned = Selection.plan(request,{},{2:{"variant":0,"start":current_start}},pairs,catalog,index.streams)
	if planned.start_sector != current_start:
		quit(1)
		return
	request.cue = 64
	planned = Selection.plan(request,{},{},pairs,catalog,index.streams)
	if planned.loop or planned.end_sector-planned.pack_start != 600 or planned.fade_sector != planned.end_sector-300:
		quit(1)
		return
	request.mode = 8
	request.cue = 1
	request.mode8_flag = 1
	var special: Array = world.runtime_tables.musicCues.mode8.channels
	planned = Selection.plan(request,{},{},pairs,catalog,index.streams,special)
	if planned.logical != 11 or planned.seek_mode != 0 or planned.start_sector != planned.pack_start:
		quit(1)
		return
	request.mode8_flag = 0
	planned = Selection.plan(request,{},{},pairs,catalog,index.streams,special)
	if planned.logical != 1:
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: all original music cue variants, XA pack/channel mapping and source sector-end catalogs")
	quit(0)

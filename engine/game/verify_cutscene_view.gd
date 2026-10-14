extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var view = preload("res://source_cutscene_view.gd")
	var rotation = preload("res://source_rotation.gd")
	var pairs: Array = tables.rotation.pairs
	assert(view.matrix(Vector3i.ZERO,pairs) == [4096,0,0,0,4096,0,0,0,4096])
	var anchored: Dictionary = view.anchored_camera({"position":[10,20,30],"angles":[0,0,0],"projectionDistance":320},Vector3i(100,200,300),1024,pairs)
	assert(anchored.position == [130,220,290] and anchored.angles == [0,1024,0] and anchored.projectionDistance == 320)
	var negative: Dictionary = view.anchored_camera({"position":[10,20,30],"angles":[0,0,0]},Vector3i.ZERO,-1024,pairs)
	assert(negative.position == [-30,20,10] and negative.angles[1] == -1024)
	var quarter: Dictionary = view.camera_view({"position":[10,20,30],"angles":[0,1024,0]},pairs)
	assert(quarter.matrix == [0,0,4096,0,4096,0,-4096,0,0] and quarter.position == [-30,-20,10])
	var angles := Vector3i(45,3050,2047)
	assert(view.matrix(angles,pairs) == [132,0,-4094,283,-4086,9,-4085,-283,-132])
	assert(view.matrix(angles,pairs) != rotation.matrix(angles,pairs))
	for asset in manifest.cutscenePoses:
		if asset.name != "SAD": continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
		for frame in data.frames:
			var result: Dictionary = view.parts_view(frame.camera,pairs)
			assert(not result.has("fault") and result.matrix.size() == 9 and result.position == [0,0,0])
	assert(view.camera_view({},pairs).has("fault"))
	print("PASS: native cutscene camera rotation order, first-frame rounding, translated view and291 parts-view resets")
	quit(0)

extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var roots: Array = tables.distanceRoot.values
	var points = preload("res://source_point_lighting.gd")
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	var light := {"position":Vector3i(0,0,4096),"rgb":[255,128,0],"inner":4096,"outer":8192}
	var full: Dictionary = points.contribution(Vector3i.ZERO,Vector3i(0,0,4096),identity,[128,128,128],light,roots)
	var half: Dictionary = points.contribution(Vector3i(0,0,-2048),Vector3i(0,0,4096),identity,[128,128,128],light,roots)
	if full.rgb != [127,64,0] or full.distance != 4096 or full.ir0 != 0 or half.rgb != [63,32,0] or half.ir0 != 2048:
		push_error("Point-light direction/falloff/NCDS integer output differs: "+str(full)+" "+str(half)); quit(1); return
	if points.contribution(Vector3i(0,0,-4096),Vector3i(0,0,4096),identity,[128,128,128],light,roots).rgb != [0,0,0] or points.contribution(Vector3i.ZERO,Vector3i(0,0,-4096),identity,[128,128,128],light,roots).rgb != [0,0,0] or points.contribution(light.position,Vector3i(0,0,4096),identity,[128,128,128],light,roots).rgb != [0,0,0]:
		push_error("Outer boundary/back-facing/zero-distance source behavior differs"); quit(1); return
	var descriptor: Dictionary = {}
	for entry in manifest.cutsceneRooms:
		if entry.name == "MP083_06.MAP": descriptor = entry; break
	var room: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(descriptor.file)))
	var decoded: Dictionary = points.decode(room.source.pointRecords)
	if decoded.has("fault") or decoded.lights.size() != 5 or decoded.lights[0] != {"position":Vector3i(24576,2457,10240),"rgb":[255,123,123],"inner":4096,"outer":8192}:
		push_error("Original CRYSD point-light bytes/units differ"); quit(1); return
	var model := {"sourceNormals":[[0,0,4096]]}; var face := {"flags":1,"material":0,"color":[0,0,0]}
	var lighting := {"textureBase":[128,128,128],"pointLights":[light,light],"distanceRoot":roots}
	if points.face_rgb(face,0,model,Vector3i.ZERO,identity,{"polygons":[{"blend":0}]},lighting,[64,64,64]).rgb != [255,192,64]:
		push_error("Point lights did not add with byte saturation"); quit(1); return
	if points.face_rgb(face,0,model,Vector3i.ZERO,identity,{"polygons":[{"blend":3}]},lighting,[64,64,64]).rgb != [64,64,64]:
		push_error("Native quarter-add textured primitive exclusion differs"); quit(1); return
	if not points.decode([[0]]).has("fault"): push_error("Malformed light record accepted"); quit(1); return
	print("PASS: original point-light records, units, SQR/root distance, direction, NCDS falloff, saturation and texture-mode exclusion")
	quit(0)

extends SceneTree
func _initialize() -> void: call_deferred("probe")
func probe() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var reports: Array = []
	for scene in [0,15,16,19]:
		var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
		if config.has("fault"): push_error(str(config.fault)); quit(1); return
		var image: Image = config.actor_mask.get_image()
		var opaque_materials := {}
		for index in range(config.atlas.polygons.size()):
			var polygon: Dictionary = config.atlas.polygons[index]
			var left := image.get_width(); var top := image.get_height(); var right := 0; var bottom := 0
			for uv in polygon.uv:
				var x := clampi(floori(float(uv[0])*image.get_width()),0,image.get_width()-1)
				var y := clampi(floori(float(uv[1])*image.get_height()),0,image.get_height()-1)
				left = mini(left,x); right = maxi(right,x); top = mini(top,y); bottom = maxi(bottom,y)
			var has_stp := false
			for y in range(top,bottom+1):
				for x in range(left,right+1):
					if image.get_pixel(x,y).r > 0.5: has_stp = true; break
				if has_stp: break
			if not has_stp: opaque_materials[index] = true
		var semi := 0; var opaque := 0; var untextured := 0
		for part in config.parts:
			for model in part.models.models:
				for face in model.faces:
					if (int(face.flags)&0x20) == 0: continue
					semi += 1
					if (int(face.flags)&1) == 0: untextured += 1
					elif opaque_materials.has(int(face.material)): opaque += 1
		var report := {"scene":scene,"model_semi_faces":semi,"textured_faces_without_stp":opaque,"untextured_semi_faces":untextured,"scope":"static imported actor mask; does not establish animated-mask safety"}
		reports.append(report); print("SEQUENCE_TRANSPARENCY: ",JSON.stringify(report))
	var output := FileAccess.open("res://../build/sequence-transparency-audit.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(reports,"\t")); output.close()
	quit(0)

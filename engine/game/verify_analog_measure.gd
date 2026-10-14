extends SceneTree
func _initialize() -> void:
	var content := str(OS.get_cmdline_user_args()[1])
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var mapper=preload("res://source_input.gd")
	for row in [[Vector2i(128,128),0,0],[Vector2i(128,0),128,0],[Vector2i(0,128),128,1024],[Vector2i(128,255),126,2048],[Vector2i(255,128),126,64512],[Vector2i(0,0),181,512]]:
		var result: Dictionary=mapper.analog_measure(row[0],Vector2i(128,128),tables.distanceRoot.values,tables.wallAngles.values)
		if result.get("magnitude",-1)!=row[1] or result.angle!=row[2]:push_error("Analog root/angle differs: "+str(result));quit(1);return
	if not mapper.analog_measure(Vector2i(-1,0),Vector2i(128,128),tables.distanceRoot.values,tables.wallAngles.values).has("fault"):quit(1);return
	print("PASS: imported-table analog neutral/cardinal/diagonal magnitude and angle; original full-handler capture pending")
	quit(0)

extends SceneTree
func _initialize() -> void:
	var content := str(OS.get_cmdline_user_args()[1])
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-analog-input.json"))
	var calibration={"center":Vector2i(128,128),"lower_midpoint":Vector2i(64,64),"upper_midpoint":Vector2i(191,191),"half_radius":63}
	var mapper=preload("res://source_input.gd")
	for row in fixture.rows:
		var c: Array=row.values
		var raw := int(c[4]);var packet := PackedByteArray([0,0x73,raw&255,raw>>8,int(c[2]),int(c[3]),int(c[0]),int(c[1])])
		var context={"player_present":true,"room_type":int(c[7]),"camera_yaw":int(c[8]),"player_yaw":int(c[9])}
		var result: Dictionary=mapper.analog_packet(packet,int(c[5]),int(c[6]),calibration,context,tables.distanceRoot.values,tables.wallAngles.values)
		if result.get("held",-1)!=int(row.output.held) or result.pad_kind!=int(row.output.kind) or result.magnitude!=int(row.output.magnitude) or result.angle!=int(row.output.angle):push_error("Original analog capture differs case"+str(row.id)+": "+str(result));quit(1);return
	print("PASS: all8 original full analog-handler captures match held/kind/magnitude/stored angle")
	quit(0)

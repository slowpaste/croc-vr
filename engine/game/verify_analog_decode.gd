extends SceneTree
func _initialize() -> void:
	var content := str(OS.get_cmdline_user_args()[1])
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var mapper=preload("res://source_input.gd")
	var calibration := preload("res://source_controller_calibration.gd").normalize(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255))
	var context={"player_present":true,"camera_yaw":0,"player_yaw":0,"room_type":0}
	var packet := PackedByteArray([0,0x73,255,255,128,128,128,0])
	var result: Dictionary=mapper.analog_packet(packet,0,4,calibration,context,tables.distanceRoot.values,tables.wallAngles.values)
	if result.get("held",-1)!=0x10001 or result.magnitude!=128 or result.angle!=0 or result.pad_kind!=2:push_error("Composed analog forward packet differs");quit(1);return
	packet[4]=255
	result=mapper.analog_packet(packet,0,4,calibration,context,tables.distanceRoot.values,tables.wallAngles.values)
	if result.held!=0x40080001 or not result.right_override:quit(1);return
	packet[0]=255
	if mapper.analog_packet(packet,0,4,calibration,context,tables.distanceRoot.values,tables.wallAngles.values).pad_kind!=0:quit(1);return
	print("PASS: composed analog packet validation, calibration/direction/measure/action/button integration; native full-handler parity pending")
	quit(0)

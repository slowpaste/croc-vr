extends SceneTree
func _initialize() -> void:
	var mapper=preload("res://source_input.gd")
	for row in [[0,1],[511,5],[512,4],[1024,4],[1536,4],[1537,6],[2048,2],[2560,8],[3072,8],[3584,8],[3585,9],[4095,1]]:
		if mapper.analog_action_sectors(row[0],0,0,0)!=row[1]:push_error("Original analog sector boundary differs at"+str(row[0]));quit(1);return
	if mapper.analog_action_sectors(0,1024,0,0)!=4 or mapper.analog_action_sectors(0,1024,0,1)!=1 or mapper.analog_action_sectors(0,1024,0,11)!=1 or mapper.analog_action_sectors(0,1024,1024,0)!=1:quit(1);return
	print("PASS: source-derived analog overlapping action sectors and room-type camera-relative exceptions; full decoder/capture pending")
	quit(0)

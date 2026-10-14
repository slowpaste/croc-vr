extends SceneTree
const Selection = preload("res://source_menu_selection.gd")
func _initialize() -> void:
	var cases := [
		[0,{},0x20000,0,{"index":0,"changes":0}],
		[5,{1:1},0x20000,0,{"index":2,"changes":1}],
		[5,{3:2},0x20000,0,{"index":4,"changes":1}],
		[0,{},0x80000,0,{"index":0,"changes":0}],
		[0,{0:1,2:0x8000},0x80000,0,{"index":3,"changes":1}],
		[39,{39:0x8000},0x80000,0,{"index":39,"changes":0}],
		[39,{39:0x8000,40:0x4000},0x80000,0,{"index":40,"changes":1}],
		[43,{44:0x8000},0x80000,0,{"index":45,"changes":1}],
		[44,{44:0x8000},0x80000,0,{"index":44,"changes":0}],
		[3,{1:1,2:0x8000},0xa0000,0,{"index":3,"changes":2}],
		[3,{1:1,2:0x8000},0xa0000,1,{"index":3,"changes":0}]
	]
	for item in cases:
		var actual := Selection.navigate(item[0],item[1],item[2],item[3])
		if actual != item[4]:
			push_error("Source menu selection mismatch: "+str(item)+" got "+str(actual))
			quit(1)
			return
	print("PASS: source menu backward/forward flags, index40 gate, upper bound, lock and simultaneous input order")
	quit(0)

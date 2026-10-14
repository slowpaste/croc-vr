extends SceneTree
func _initialize() -> void:
	var pose = preload("res://source_options_model_pose.gd")
	var prior := {"position":Vector3i(55,66,77),"angles":Vector3i(111,777,888),"scale":Vector3i(4096,4096,4096)}
	for pad in [1,2]:
		for selected in range(4):
			var result: Dictionary = pose.root_selection(prior,selected,pad)
			var slot: int = (1316 if pad==2 else 1252) if selected==0 else [1280,1284,1296][selected-1]
			if result.slot!=slot or result.position!=Vector3i(55,[50,100,0,0][selected],[2200,2000,1200,3000][selected]) or result.angles!=Vector3i(512 if selected==0 else 0,777,888) or result.scale!=prior.scale:quit(1);return
	if prior.position!=Vector3i(55,66,77) or not pose.root_selection(prior,4,2).has("fault"):quit(1);return
	var animated := prior.duplicate(true);animated.slot = 1252;animated.angles.y = 65520
	var frame: Dictionary = pose.draw_step(animated)
	if frame.draw.angles.y!=65520 or frame.next.angles.y!=32 or animated.angles.y!=65520:quit(1);return
	var selected: Dictionary = pose.root_selection(frame.next,1,2)
	if frame.draw.slot!=1252 or selected.slot!=1280 or selected.angles.y!=32:quit(1);return
	animated.slot = 0
	if not pose.draw_step(animated).draw.is_empty() or pose.draw_step(animated).next!=animated:quit(1);return
	print("PASS: all8 Options root model selections retain untouched pose words and resolve original controller/audio/misc/return slots")
	quit(0)

extends SceneTree
const Clock = preload("res://source_cd_filtered_clock.gd")
func _initialize() -> void:
	var clock := Clock.new()
	if not clock.advance(1).has("fault") or not clock.begin(1000,200,1): quit(1); return
	var result := clock.advance(100000,1)
	if result.cursor != 1015 or result.callbacks != [1001] or not result.pending: quit(1); return
	result = clock.advance(0,1)
	if result.callbacks != [1009] or result.pending: quit(1); return
	if not clock.advance(0).callbacks.is_empty(): quit(1); return
	clock.begin(1000,200,8)
	if clock.advance(53333).callbacks.size() != 0 or clock.advance(1).callbacks != [1008]: quit(1); return
	clock.begin(1000,200,1)
	var callbacks: Array = []
	result = clock.advance(1000000,4)
	callbacks.append_array(result.callbacks)
	while result.pending:
		result = clock.advance(0,4)
		callbacks.append_array(result.callbacks)
	if callbacks.size() != 19 or callbacks[0] != 1001 or callbacks[-1] != 1145 or clock.clock.cursor != 1150: quit(1); return
	clock.begin(1000,200,1)
	clock.clock.reading = false
	if not clock.advance(1000000).callbacks.is_empty() or clock.clock.cursor != 1000: quit(1); return
	clock.clock.reading = true
	if clock.advance(6667).callbacks != [1001]: quit(1); return
	var cursor := clock.clock.cursor
	if clock.begin(0,200,-1) or not clock.advance(1,0).has("fault") or clock.clock.cursor != cursor: quit(1); return
	print("PASS: explicit filtered-sector phase, eight-sector spacing, bounded catch-up, no duplicate events and pause")
	quit(0)

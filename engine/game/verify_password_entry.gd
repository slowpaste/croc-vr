extends SceneTree
func _initialize() -> void:
	var entry = preload("res://source_password_entry.gd")
	var original: Dictionary = entry.initialize()
	var state: Dictionary = original
	var masks := [0x10000,0x80000,0x40000,0x20000]
	for index in range(15): state = entry.advance(state,masks[index%4])
	assert(original.count == 0 and original.symbols[0] == 0)
	assert(state.count == 16 and not state.needs_validation and state.symbols == [1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,0])
	assert(entry.advance(state,0).needs_validation)
	assert(entry.advance(state,0x800000).count == 16)
	var empty: Dictionary = entry.advance(original,0x800000)
	assert(empty.count == 0 and empty.events == [{"sound_handle":20432,"volume":15,"pitch":0}])
	var one: Dictionary = entry.advance(original,0xf0000)
	assert(one.symbols[0] == 1)
	var removed: Dictionary = entry.advance(one,0x8f0000)
	assert(removed.count == 0 and removed.symbols[0] == 0)
	var cancel: Dictionary = entry.advance(one,0x9f0200)
	assert(cancel.return_requested and cancel.count == 1 and cancel.events[0].sound_handle == 20264)
	assert(entry.advance(one,0).events.is_empty())
	print("PASS: original15-symbol password entry, priority, backspace, return and next-tick validation gate")
	quit(0)

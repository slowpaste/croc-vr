extends SceneTree
func _initialize() -> void:
	var validation = preload("res://source_password_validation.gd")
	var entry = preload("res://source_password_entry.gd")
	var encoder = preload("res://source_password.gd")
	var flags: Array = []; flags.resize(80); flags.fill(0)
	var levels: Array = []; levels.resize(46); levels.fill(0); levels[0] = 10
	var encoded: Dictionary = encoder.encode(flags,0,[0,0,0,0,0,0,0,0])
	var state: Dictionary = entry.initialize()
	var masks := [0,0x10000,0x80000,0x40000,0x20000]
	for symbol in encoded.symbols: state = validation.advance(state,masks[int(symbol)],levels,flags)
	assert(state.count == 16 and not state.has("progress"))
	var accepted: Dictionary = validation.advance(state,0,levels,flags)
	assert(accepted.progress.accepted and accepted.return_flag == 2 and accepted.progress.level == 10)
	state.symbols[5] = ((int(state.symbols[5])-1)^1)+1
	var rejected: Dictionary = validation.advance(state,0,levels,flags)
	assert(not rejected.progress.accepted and rejected.return_flag == 1 and rejected.progress.flags.size() == 80 and rejected.progress.crystal_bank == 0)
	assert(rejected.events == [{"sound_handle":20432,"volume":15,"pitch":0}])
	assert(not validation.advance(entry.initialize(),0x100200,levels,flags).has("progress"))
	print("PASS:15-symbol entry validates next tick, success flag2 and rejection resets80 progress words/returns1")
	quit(0)

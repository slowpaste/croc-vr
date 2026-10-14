extends SceneTree
func _initialize() -> void:
	var restore = preload("res://source_password_progress.gd")
	var encoder = preload("res://source_password.gd")
	var levels: Array = []; levels.resize(46); levels.fill(0); levels[0] = 10; levels[44] = 54
	var fields := {"checksum_valid":true,"highest_completed":0,"selection_bits":0,"pickup_words":[0,0,0,0,0,0,0,0],"data":0}
	var empty: Dictionary = restore.restore(fields,levels)
	assert(empty.accepted and empty.level == 10 and empty.flags.count(0) == 80 and empty.lives == 3 and empty.return_flag == 2)
	var prior: Array = []; prior.resize(80); prior.fill(7)
	var retained: Dictionary = restore.restore(fields,levels,prior)
	assert(retained.flags[0] == 0 and retained.flags[45] == 7 and retained.flags[79] == 7 and prior[0] == 7)
	fields.highest_completed = 44; fields.selection_bits = 44; fields.pickup_words.fill(1)
	for bit in encoder.SECRET_BITS: fields.data |= 1 << bit
	var full: Dictionary = restore.restore(fields,levels)
	assert(full.accepted and full.level == 54 and full.flags[40] == 0xc000 and full.flags[44] == 0x8000)
	for slot in range(8):
		assert(full.announcements[slot] == 2)
		for index in range(slot*5,slot*5+3): assert(full.flags[index] == 0x8006)
		assert(full.flags[slot*5+3] == 0x8000 and full.flags[slot*5+4] == 0x8000)
	fields.pickup_words[0] = 0
	assert(not restore.restore(fields,levels).accepted)
	assert(restore.restore(fields,[]).get("accepted") == false)
	print("PASS: native password progress reconstruction, zero-stage special case, rescue flags, announcements and bonus unlock")
	quit(0)

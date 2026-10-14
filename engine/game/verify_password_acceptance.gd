extends SceneTree
func _initialize() -> void:
	var acceptance = preload("res://source_password_acceptance.gd")
	var encoder = preload("res://source_password.gd")
	var fields := {"checksum_valid":true,"highest_completed":0,"selection_bits":0,"pickup_words":[0,0,0,0,0,0,0,0],"data":0}
	assert(acceptance.accepts(fields))
	fields.selection_bits = 1; assert(acceptance.accepts(fields))
	fields.selection_bits = 2; assert(not acceptance.accepts(fields))
	fields.selection_bits = 0
	for slot in range(8):
		fields.pickup_words.fill(0); fields.pickup_words[slot] = 1
		fields.data = 1 << encoder.SECRET_BITS[slot]
		fields.highest_completed = 3+slot*5; assert(not acceptance.accepts(fields))
		fields.highest_completed += 1; assert(acceptance.accepts(fields))
		fields.data = 0; assert(not acceptance.accepts(fields))
	fields.pickup_words.fill(0); fields.highest_completed = 40; assert(acceptance.accepts(fields))
	fields.highest_completed = 41; assert(not acceptance.accepts(fields))
	fields.pickup_words.fill(1); fields.data = 0
	for bit in encoder.SECRET_BITS: fields.data |= 1 << bit
	assert(acceptance.accepts(fields))
	fields.highest_completed = 45; fields.selection_bits = 45; assert(acceptance.accepts(fields))
	fields.highest_completed = 46; assert(not acceptance.accepts(fields))
	fields.highest_completed = 45; fields.checksum_valid = false; assert(not acceptance.accepts(fields))
	print("PASS: native password bounds, next-selection limit, eight pickup prerequisites and late-progress gate")
	quit(0)

extends SceneTree
func _initialize() -> void:
	var encoder = preload("res://source_password.gd")
	var fields = preload("res://source_password_fields.gd")
	var progress: Array = []; progress.resize(45); progress.fill(0)
	for completed in range(45):
		progress.fill(0); progress[completed] = 0x8000
		for selected in range(45):
			var pickups: Array = []
			for slot in range(8): pickups.append((selected >> (slot%6)) & 1)
			var encoded: Dictionary = encoder.encode(progress,selected,pickups)
			var decoded: Dictionary = fields.read(encoded.symbols)
			assert(decoded.checksum_valid and decoded.highest_completed == completed and decoded.selection_bits == selected)
			for slot in range(8): assert((decoded.pickup_words[slot] != 0) == (pickups[slot] != 0))
	var empty: Dictionary = encoder.encode(progress,0,[0,0,0,0,0,0,0,0])
	var corrupt: Array = empty.symbols.duplicate()
	corrupt[5] = ((int(corrupt[5])-1) ^ 1)+1
	assert(not fields.read(corrupt).checksum_valid)
	assert(fields.read([]).has("fault"))
	corrupt[0] = 0
	assert(fields.read(corrupt).has("fault"))
	print("PASS: original password reconstruction/checksum and2025 field round trips; malformed symbol rejection")
	quit(0)

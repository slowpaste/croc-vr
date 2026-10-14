extends SceneTree
func _initialize() -> void:
	var encoder = preload("res://source_password.gd")
	var progress: Array = []; progress.resize(45); progress.fill(0)
	var pickups: Array = []; pickups.resize(8); pickups.fill(0)
	var empty: Dictionary = encoder.encode(progress,0,pickups)
	assert(empty.word == 0x45332bfc)
	assert(empty.symbols == [1,4,4,4,4,3,3,1,4,1,4,1,2,2,1])
	for bit in range(6):
		var selected: Dictionary = encoder.encode(progress,1 << bit,pickups)
		assert((int(selected.data) & ~(1 << 23 | 1 << 3)) == 1 << encoder.SELECTION_BITS[bit])
	for slot in range(8):
		pickups[slot] = -1
		var pickup: Dictionary = encoder.encode(progress,0,pickups)
		assert(pickup.data == (1 << encoder.PICKUP_BITS[slot]) | (1 << 23))
		pickups[slot] = 0
	progress[44] = 0x8000
	assert(encoder.encode(progress,0,pickups).highest_completed == 44)
	assert(encoder.encode(progress,0,[]).has("fault"))
	var display: Dictionary = encoder.display(empty,[95,59,91,92,93])
	assert(display.text.length() == 15 and display.y == 140)
	var input = preload("res://source_game_over_input.gd")
	for bit in range(32):
		var event: Dictionary = input.sample(1 << bit)
		assert(event.return_requested == (bit == 20 or bit == 23))
	assert(input.sample(0).events.is_empty())
	assert(input.sample(0x900000).events == [{"sound":"START","volume":80,"pitch":24}])
	print("PASS: native password bit placement, checksum, symbol order and invalid-state guard")
	quit(0)

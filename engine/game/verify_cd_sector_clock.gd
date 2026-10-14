extends SceneTree
const Clock = preload("res://source_cd_sector_clock.gd")
func _initialize() -> void:
	var clock := Clock.new()
	clock.begin(1000,200)
	if clock.advance(1000000).cursor != 1150: quit(1); return
	for count in [60,72,90,144]:
		clock.begin(1000,200)
		for frame in range(count):
			var end := int((frame+1)*1000000/count)
			var start := int(frame*1000000/count)
			clock.advance(end-start)
		if clock.cursor != 1150 or clock.remainder != 0: push_error("Nominal CD clock depends on display callback rate"); quit(1); return
	clock.begin(1000,72)
	if clock.advance(1000000).cursor != 1075: quit(1); return
	clock.begin(0,200)
	if clock.advance(53333).sectors != 7 or clock.remainder != 999950 or clock.advance(1).sectors != 1:
		push_error("CD clock rounded the eight-sector XA interval too early")
		quit(1)
		return
	var saved_remainder := clock.remainder
	clock.reading = false
	clock.advance(1234567)
	if clock.cursor != 8 or clock.remainder != saved_remainder: quit(1); return
	clock.reading = true
	if clock.advance(6666).cursor != 9 or clock.remainder != 0: quit(1); return
	clock.begin(0,200)
	if clock.advance(86400000000).cursor != 12960000 or clock.remainder != 0: quit(1); return
	clock.begin(1000,72)
	clock.advance(1000000)
	clock.reading = false
	if clock.advance(1000000).sectors != 0 or clock.cursor != 1075: quit(1); return
	clock.begin(2147483647,200)
	if clock.advance(6667).cursor != -2147483648: quit(1); return
	var before := clock.cursor
	var remainder := clock.remainder
	if not clock.advance(-1).has("fault") or clock.cursor != before or clock.remainder != remainder: quit(1); return
	print("PASS: nominal source CD mode/rate, frame-independent remainder, pause and signed cursor wrap")
	quit(0)

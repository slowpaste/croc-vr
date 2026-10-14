extends SceneTree
const Demo = preload("res://source_attract_demo.gd")
const Random = preload("res://source_random.gd")
func _initialize() -> void:
	var destinations: Array = [[15,0],[16,0],[20,0],[30,1],[41,0]]
	var seen: Dictionary = {}
	for frame in range(100):
		var random_source := Random.new()
		random_source.accumulator = 12345
		var expected := int((((frame*0x41c64e6d+12345)&0xffffffff)>>16)&32767)%5
		var result := Demo.select_destination(frame,destinations,random_source)
		if result.index != expected or result.level != destinations[expected][0] or result.room != destinations[expected][1] or random_source.draws != 1 or random_source.bios_seed != 0 or random_source.accumulator != 12345:
			push_error("Source attract demo selection/random reset differs")
			quit(1)
			return
		seen[result.index] = true
	if seen.size() != 5 or not Demo.select_destination(0,[],Random.new()).has("fault"):
		quit(1)
		return
	print("PASS: all five source attract destinations, frame-seeded draw, BIOS reset and accumulator preservation")
	quit(0)

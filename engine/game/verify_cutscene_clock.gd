extends SceneTree
func _initialize() -> void:
	var clock_type = preload("res://source_cutscene_clock.gd")
	var audio := {"firstSector":7,"sectors":207}
	var first = clock_type.new()
	assert(first.begin(0,6667))
	assert(first.advance(6666).processed_sectors == 0)
	assert(first.advance(1).processed_sectors == 1)
	assert(first.advance(26666).processed_sectors == 4 and first.available_audio_frames(audio) == 0)
	assert(first.advance(1).processed_sectors == 5)
	first.paused = true
	assert(first.advance(1000000).processed_sectors == 5)
	first.paused = false
	assert(first.advance(20000).processed_sectors == 8 and first.available_audio_frames(audio) == 2016)
	for partitions in [1,60,72,90,144]:
		var clock = clock_type.new()
		assert(clock.begin(0,0))
		var elapsed := 0
		for step in range(partitions):
			var end := int((step+1)*1000000/partitions)
			clock.advance(end-elapsed); elapsed = end
		assert(clock.clock.cursor == 151)
	assert(first.advance(-1).has("fault"))
	print("PASS: explicit cutscene sector phase, nominal150-sector clock, pause and first-audio availability")
	quit(0)

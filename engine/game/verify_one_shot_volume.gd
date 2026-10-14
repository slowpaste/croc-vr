extends SceneTree
const Sound = preload("res://source_audio_math.gd")
func _initialize() -> void:
	# Source-derived cases; original runtime argument/output capture pending.
	var cases := [[80,127,4096,false,10160],[80,127,0,false,11184],[80,127,8192,false,9136],[80,127,4096,true,5080],[80,127,0,true,6104],[80,127,44736,false,0],[80,127,44740,false,-1],[100,127,4096,false,12700]]
	for sample in cases:
		var result := Sound.one_shot_volume(sample[0],sample[1],sample[2],sample[3])
		if result.blocked or result.volume!=sample[4] or result.audible!=(sample[4]>0):push_error("Original one-shot volume source-derived boundary mismatch");quit(1);return
	if not Sound.one_shot_volume(80,0,0,false).blocked or not Sound.one_shot_volume(0,127,0,false).blocked:quit(1);return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-one-shot-volume.json"))
	for index in range(0,fixture.observations.size(),2):
		var before: Dictionary = fixture.observations[index]
		var after: Dictionary = fixture.observations[index+1]
		var result := Sound.one_shot_volume(int(before.base),int(before.effects),int(before.distance),int(before.quiet)!=0)
		if result.blocked or result.volume!=int(after.volume) or result.audible!=(int(after.audible)!=0):
			push_error("Original one-shot arithmetic capture mismatch");quit(1);return
	print("PASS: eight original one-shot arithmetic captures; full allocation/playback qualification pending")
	quit(0)

extends SceneTree
const Sound = preload("res://source_audio_math.gd")
func _initialize() -> void:
	var cases := [[0,1,1000,1000,1],[512,1,1500,500,1],[1024,1,2000,0,1],[2048,1,1000,1000,1],[3072,1,0,2000,1],[4096,1,1000,1000,1],[0,2,500,500,1],[1025,2,499,-500,2],[2048,2,250,-250,2],[3072,2,-500,500,2],[4096,2,1000,1000,1]]
	for sample in cases:
		var result := Sound.panning(1000,sample[0],sample[1])
		if result.left!=sample[2] or result.right!=sample[3] or result.flags!=sample[4]:push_error("Original panning source-derived case mismatch");quit(1);return
	if not Sound.panning(1000,4097,1).get("ignored",false):quit(1);return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-sound-panning.json"))
	for index in range(0,fixture.observations.size(),2):
		var before: Dictionary = fixture.observations[index]
		var after: Dictionary = fixture.observations[index+1]
		var result := Sound.panning(int(before.volume),int(before.angle),int(before.mode))
		if result.get("ignored",false):
			if int(after.left)!=111 or int(after.right)!=222 or int(after.flags)!=7:quit(1);return
		elif result.left!=int(after.left) or result.right!=int(after.right) or result.flags!=int(after.flags):
			push_error("Original panning runtime capture mismatch");quit(1);return
	print("PASS: all sixteen original stereo/surround panning output captures")
	quit(0)

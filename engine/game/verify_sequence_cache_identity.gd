extends SceneTree
func _initialize() -> void:
	var identity = preload("res://source_sequence_cache_identity.gd")
	var part := {}
	for key in ["data","models","room","anchor","track_models","room_atlas","room_lighting","atlas","sky_models","sky_atlas"]: part[key] = {}
	var config := {"parts":[part]}
	var expected: String = identity.fingerprint(config,{"rotation":1})
	assert(expected.length() == 64)
	assert(expected == identity.fingerprint(config.duplicate(true),{"rotation":1}))
	assert(expected != identity.fingerprint(config,{"rotation":2}))
	for key in part:
		var changed: Dictionary = config.duplicate(true)
		changed.parts[0][key] = {"changed":true}
		assert(expected != identity.fingerprint(changed,{"rotation":1}))
	print("PASS: sequence cache identity includes every geometry/lighting binding, runtime tables and exported renderer revision")
	quit(0)

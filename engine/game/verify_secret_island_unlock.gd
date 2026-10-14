extends SceneTree
func _initialize() -> void:
	var unlock = preload("res://source_secret_island_unlock.gd")
	var words := [1,1,1,1,1,1,1,1]
	var expected := {"play":true,"sequence":7,"selected_index":40,"level":50,"room":0,"flag":0x4000}
	assert(unlock.decide({},words) == expected)
	for missing in range(8):
		var incomplete: Array = words.duplicate(); incomplete[missing] = 0
		assert(unlock.decide({},incomplete) == {"play":false})
	words[3] = -1
	assert(unlock.decide({40:0x8000},words) == expected)
	assert(unlock.decide({40:0x4000},[]) == {"play":false})
	assert(unlock.decide({},[1,1,1]).has("fault"))
	assert(words == [1,1,1,-1,1,1,1,1])
	print("PASS: secret island requires all eight nonzero pickup words, plays JIG7 once and selects original40/level50 unlock state")
	quit(0)

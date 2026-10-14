extends SceneTree
const Selection = preload("res://source_title_selection.gd")
const Random = preload("res://source_random.gd")
class FixedRandom:
	extends RefCounted
	var bios_seed := 0
	var draws := 0
	var values: Array = [5,1,2]
	func bios_rand() -> int:
		var value: int = values[draws]
		draws += 1
		return value
func _initialize() -> void:
	var fixed := FixedRandom.new()
	var result := Selection.select_scene(0,1,123,fixed)
	if result.index != 2 or result.map != "MP092_00.MAP" or fixed.draws != 3 or fixed.bios_seed != 123:
		quit(1)
		return
	var random_source := Random.new()
	random_source.bios_seed = 88
	random_source.accumulator = 999
	result = Selection.select_scene(7,4,123,random_source)
	if result.index != 4 or result.map != "MP094_00.MAP" or random_source.draws != 0 or random_source.bios_seed != 88:
		quit(1)
		return
	var previous := -1
	var seen: Dictionary = {}
	for frame in range(100):
		result = Selection.select_scene(0,previous,frame,random_source)
		if result.index == previous or result.index < 0 or result.index > 3 or random_source.accumulator != 999:
			quit(1)
			return
		seen[result.index] = true
		previous = result.index
	if seen.size() != 4:
		quit(1)
		return
	print("PASS: source title selection, repeat rejection, all four rotating scenes and fixed mode7 without RNG changes")
	quit(0)

extends SceneTree
func _initialize() -> void:
	var planner = preload("res://source_cutscene_passes.gd")
	var room := [{"bucket":10,"serial":0,"flags":1,"blend":0},{"bucket":8,"serial":1,"flags":1,"blend":0}]
	var actors := [{"bucket":8,"serial":0,"flags":0x21,"blend":2},{"bucket":8,"serial":1,"flags":1,"blend":0},{"bucket":6,"serial":2,"flags":0x21,"blend":2}]
	var result: Dictionary = planner.plan(room,actors)
	assert(result.commands == 5 and result.blended == 2 and result.passes.size() == 4)
	assert(result.passes[0].commands[0].bucket == 10)
	assert(result.passes[0].commands[1].source == "actor" and result.passes[0].commands[1].serial == 1)
	assert(result.passes[1].kind == "blend" and result.passes[1].command.serial == 0)
	assert(result.passes[2].commands[0].source == "room")
	assert(result.passes[3].mode == 2)
	assert(room[0].get("global_serial",-1) == -1 and actors[0].get("source","").is_empty())
	var untextured: Dictionary = planner.plan(room,[{"bucket":6,"serial":0,"flags":0x20,"blend":0}])
	assert(untextured.blended == 1 and untextured.passes.back().kind == "blend" and untextured.passes.back().mode == 0)
	print("PASS: global original bucket/tie order splits opaque runs around each blended primitive without mutating inputs")
	quit(0)

extends SceneTree
const Move = preload("res://source_player_movement.gd")
const Controls = preload("res://vr_controls.gd")
const Actor = preload("res://asl_actor.gd")
const VM = preload("res://asl_vm.gd")

class ActionWorld extends Node3D:
	var source_player_actor: Node3D
	var source_camera_state: Dictionary = {"yaw":123}

func _initialize() -> void:
	var state := {"motion":Vector2i(123,-456),"magnitude":10,"mode":2,"counter":5,"turn_history":-1966080,"field456":7,"reset_pending":false,"yaw_rate":18,"timer":19,"lock":20,"forced":21}
	var stopped := Move.stop_dead(state)
	if stopped.motion != Vector2i.ZERO or stopped.magnitude != 0 or stopped.mode != 0 or stopped.counter != 0 or stopped.turn_history != 0 or state.motion != Vector2i(123,-456):
		push_error("StopDead failed to clear only shared movement state")
		quit(1)
		return
	for key in ["field456","reset_pending","yaw_rate","timer","lock","forced"]:
		if stopped[key] != state[key]:
			push_error("StopDead changed unrelated state: " + key)
			quit(1)
			return
	var c = Controls.new()
	if c.animation_buttons(0x10,2,0,2,10<<16) != 0x14 or c.animation_buttons(0x800,2,0,2,-(10<<16)) != 0x808 or c.animation_buttons(0x10,2,0,2,0) != 0x10:
		push_error("Modern turn animation query lost jump/attack bits or direction")
		quit(1)
		return
	for input in [[1,0,2],[2,1,2],[2,2,2],[2,0,0]]:
		if c.animation_buttons(0x10,input[0],input[1],input[2],10<<16) != 0x10:
			push_error("Animation adapter affected digital, moving or airborne input")
			quit(1)
			return
	c.layout = "classic"
	if c.animation_buttons(0x10,2,0,2,10<<16) != 0x10:
		quit(1)
		return
	var host := ActionWorld.new()
	var player = Actor.new()
	var lid = Actor.new()
	host.source_player_actor = player
	lid.world = host
	player.secondary_flags = 0x182
	lid.secondary_flags = 0x32
	var machine = VM.new()
	if lid.asl_command({"op":186,"args":[]},machine) != "continue" or player.secondary_flags != 0x180 or lid.secondary_flags != 0x32:
		push_error("PlayerNoStood did not preserve unrelated player/owner flags")
		quit(1)
		return
	if lid.asl_command({"op":71,"args":[[{"op":4,"value":65536},{"op":18}]]},machine) != "continue" or host.source_camera_state.yaw != 123 or host.source_camera_state.wobble_request.value != 65536:
		push_error("Slam camera request did not continue with a steady spectator view")
		quit(1)
		return
	player.free()
	lid.free()
	host.free()
	print("PASS: StopDead exact reset scope and modern idle-turn animation query gates")
	quit(0)

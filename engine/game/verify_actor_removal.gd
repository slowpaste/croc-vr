extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")

func _initialize() -> void:
	var world = World.new()
	world.source_pool.reset(128)
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	var camera_body := StaticBody3D.new()
	camera_body.collision_layer = 256
	actor.add_child(camera_body)
	actor.camera_bodies.append(camera_body)
	actor.source_pool_id = world.source_pool.allocate({"node":actor})
	world.source_actors.append(actor)
	actor.vm.configure({"instructions":[{"pc":8,"op":53,"name":"Remove","args":[],"next":9}]},8,actor)
	if actor.vm.run() != "yielded" or actor.primary_flags != 7 or not world.source_pool.slots.has(127):
		world.free()
		quit(1)
		return
	world.tick_source_actors()
	if camera_body.collision_layer != 0:
		push_error("Removed actor retained its camera collider until queued deletion")
		world.free()
		quit(1)
		return
	if not world.source_actors.is_empty() or actor.primary_flags != 0 or actor.secondary_flags != 0 or world.source_pool.slots.has(127) or not actor.is_queued_for_deletion():
		world.free()
		quit(1)
		return
	if world.source_pool.allocate({"node":null}) != 127:
		world.free()
		quit(1)
		return
	world.source_pool.release(127)
	var model_only = Actor.new(); world.add_child(model_only); model_only.world = world
	model_only.primary_flags = 0x20001; model_only.secondary_flags = 0x432
	model_only.model_data = {"models":[{"collision":{"counts":[1,0]}}]}
	var old_body := StaticBody3D.new(); old_body.collision_layer = 256; model_only.add_child(old_body); model_only.camera_bodies.append(old_body)
	if model_only.asl_command({"op":202,"args":[]},model_only.vm) != "continue" or model_only.primary_flags != 0xa0001 or model_only.secondary_flags != 0x402 or not model_only.model_data.is_empty() or old_body.collision_layer != 0:
		push_error("RemoveModel retained source or camera collision, or altered unrelated flags"); world.free(); quit(1); return
	var ended = Actor.new()
	world.add_child(ended)
	ended.world = world
	ended.source_pool_id = world.source_pool.allocate({"node":ended})
	world.source_actors.append(ended)
	ended.vm.configure({"instructions":[{"pc":8,"op":59,"name":"FileEnd","args":[],"next":9}]},8,ended)
	if ended.vm.run() != "finished" or ended.primary_flags != 7 or ended.vm.pc != 8:
		world.free()
		quit(1)
		return
	world.tick_source_actors()
	if world.source_pool.slots.has(127) or not world.source_actors.is_empty() or not ended.is_queued_for_deletion():
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: Remove and FileEnd request next-update removal with original pointer/slot lifecycle")
	quit(0)

extends SceneTree
const Actor = preload("res://asl_actor.gd")

class ClockActor extends Actor:
	func apply_root_frame() -> bool:
		return true
	func apply_pose() -> void:
		pass

func _initialize() -> void:
	var actor := ClockActor.new()
	actor.model_data = {"models":[]}
	actor.clip = {"speed":256,"frameCount":1000}
	actor.clip_playing = true
	actor.primary_flags |= 8
	actor.advance_animation()
	if actor.clip_frame != 1 or actor.clip_fraction != 0:
		actor.free()
		quit(1)
		return
	actor.clip.speed = 512
	actor.advance_animation()
	if actor.clip_frame != 3:
		actor.free()
		quit(1)
		return
	actor.clip.speed = 256
	actor.clip_speed_offset = 65408
	actor.advance_animation()
	if actor.clip_frame != 3 or actor.clip_fraction != 128:
		actor.free()
		quit(1)
		return
	actor.advance_animation()
	if actor.clip_frame != 4 or actor.clip_fraction != 0:
		actor.free()
		quit(1)
		return
	actor.clip_fraction = 65500
	actor.clip_speed_offset = 0
	actor.advance_animation()
	if actor.clip_frame != 4 or actor.clip_fraction != 220:
		actor.free()
		quit(1)
		return
	actor.clip_fraction = 0
	actor.clip_frame = 999
	actor.clip_speed_offset = 512
	actor.advance_animation()
	if actor.clip_frame != 999 or actor.clip_playing or actor.clip_fraction != 0 or (actor.primary_flags & 8) != 0:
		actor.free()
		quit(1)
		return
	actor.clip = {"speed":512,"frameCount":3,"triggers":[[0,1],[0,4],[1,16],[2,128]]}
	actor.clip_playing = true
	actor.clip_frame = 0
	actor.clip_fraction = 0
	actor.clip_speed_offset = 0
	actor.advance_animation()
	if actor.clip_frame != 2 or actor.animation_triggers != 21:
		actor.free()
		quit(1)
		return
	if not actor.animation_trigger_matches(1) or not actor.animation_trigger_matches(3) or actor.animation_trigger_matches(2) or not actor.animation_trigger_matches(33):
		actor.free()
		quit(1)
		return
	actor.advance_animation()
	if actor.clip_playing or actor.animation_triggers != 128:
		actor.free()
		quit(1)
		return
	actor.advance_animation()
	if actor.animation_triggers != 0:
		actor.free()
		quit(1)
		return
	actor.free()
	print("PASS: clip header rate, additive halfword speed offset, fractional/wrapped timing and final-frame consumption")
	quit(0)

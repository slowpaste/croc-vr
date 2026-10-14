extends SceneTree
const Facing = preload("res://source_sprite_facing.gd")

func _initialize() -> void:
	var quad := {"vertices":[[-1,0,0],[1,0,0],[1,2,0],[-1,2,0]],"faces":[{"flags":137,"indices":[1,0,2,3]}],"collision":{"counts":[0,0]}}
	if not Facing.is_image_quad(quad):
		quit(1)
		return
	var solid := quad.duplicate(true)
	solid.vertices[2][2] = 1
	var wing := quad.duplicate(true)
	for point in wing.vertices:
		point[2] = point[0]
		point[0] = 0
	var collidable := quad.duplicate(true)
	collidable.collision.counts = [1,0]
	if Facing.is_image_quad(solid) or Facing.is_image_quad(wing) or Facing.is_image_quad(collidable):
		push_error("Sprite facing selected a solid, wing or collision surface")
		quit(1)
		return
	assert(Facing.is_actor_sprite({"models":[quad,quad.duplicate(true)]},0))
	assert(not Facing.is_actor_sprite({"models":[quad,solid]},0))
	var gobbo_parts:Array=[];gobbo_parts.resize(12);gobbo_parts.fill(solid)
	gobbo_parts[8]=quad;gobbo_parts[9]=quad.duplicate(true)
	assert(Facing.is_actor_sprite({"models":gobbo_parts},8,"GOBBO.MOD"))
	assert(Facing.is_actor_sprite({"models":gobbo_parts},9,"GOBBO.MOD"))
	assert(not Facing.is_actor_sprite({"models":gobbo_parts},0,"GOBBO.MOD"))
	assert(not Facing.is_actor_sprite({"models":gobbo_parts},8,"SBFLY.MOD"))
	for camera_position in [Vector3(0,0,5),Vector3(5,0,0),Vector3(0,0,-5),Vector3(-5,2,0),Vector3(0,5,0)]:
		var basis := Facing.facing_basis(Vector3.ZERO,camera_position,Vector3(2,3,4))
		if basis.z.normalized().dot(camera_position.normalized()) < 0.99999 or not basis.get_scale().is_equal_approx(Vector3(2,3,4)) or not is_equal_approx(basis.x.normalized().dot(basis.y.normalized()),0):
			push_error("Billboard orientation, scale or overhead stability failed")
			quit(1)
			return
	print("PASS: sprite quad classification, camera orbit, scale preservation and overhead view")
	quit(0)

extends RefCounted
# Retail startup12d30..12d4c: display512x240, geometry512x384.
#160bc..160c4 sets geometric origin to half geometry dimensions.
const DISPLAY := Vector2i(512,240)
const GEOMETRY := Vector2i(512,384)
const ORIGIN := Vector2i(256,192)
static func projection(h: int) -> Dictionary:
	# Native16058 multiplies the camera halfword by geometry-height1030(gp)
	# before>>8 and SetGeomScreen. Display height240 is a separate quantity.
	return {"h":(GEOMETRY.y*(h&65535))>>8,"offset":Vector2i(ORIGIN.x<<16,ORIGIN.y<<16)}
static func vertical_offset() -> float:
	# Native GPU packet writers map geometry Y to display Y after projection.
	return 0.0
static func display_y(projected_y: int) -> int:
	var signed_y := preload("res://source_rotation.gd").halfword(projected_y)
	return (signed_y>>1)+(signed_y>>3)

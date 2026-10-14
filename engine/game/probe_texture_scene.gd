extends "res://imported_main.gd"

func geometry(data: Dictionary, texture: Dictionary = {}) -> ArrayMesh:
	if not OS.get_cmdline_user_args().has("--probe-legacy-uv") or texture.is_empty():
		return super.geometry(data, texture)
	var mapped := texture.duplicate(true)
	for polygon in mapped.polygons:
		var uv: Array = polygon.uv
		polygon.uv = [uv[2], uv[3], uv[0], uv[1]]
	return super.geometry(data, mapped)

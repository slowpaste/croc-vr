extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0: quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var model_path := ""
	for entry in manifest.models:
		if entry.name == "INTRO05.MOD": model_path = entry.file
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(model_path)))
	var image_model: Dictionary = models.models[25]
	assert(preload("res://source_sprite_facing.gd").is_image_quad(image_model))
	var part := {"matrix":[4096,0,0,0,0,4096,0,-4096,0],"position":[100,200,3000],"scale":4096}
	var view := {"matrix":[4096,0,0,0,4096,0,0,0,4096],"position":[0,0,0]}
	var transform = preload("res://source_cutscene_transform.gd")
	var facing: Dictionary = transform.vertices(part,image_model,view,true)
	for point in facing.vertices: assert(point.z == 3000)
	assert(facing.vertices[0].y != facing.vertices[2].y)
	assert(facing.vertices[0].x == 100-roundi(float(image_model.vertices[0][0])*4096))
	var image_copy := image_model.duplicate(true);image_copy.faces[0].material = 0
	var draw_part := part.duplicate(true);draw_part.id = 0
	var projection := preload("res://source_cutscene_frame.gd").projection(320)
	projection.facing_images = true;projection.ordering = true;projection.commands = true
	var emitted := preload("res://source_cutscene_mesh.gd").build({"parts":[draw_part]},[image_copy],view,{"width":1,"height":1,"polygons":[{"uv":[[0,0],[1,0],[0,1],[1,1]]}]},{},projection)
	assert(not emitted.has("fault") and emitted.commands.size() == 1)
	assert(transform.vertices(part,models.models[17],view,true) == transform.vertices(part,models.models[17],view,false))
	part.scale = 0
	for point in transform.vertices(part,image_model,view,true).vertices: assert(point == Vector3i(100,200,3000))
	print("PASS: actual King Gobbo image faces view, solid parts retain authored pose and collapsed image remains collapsed")
	quit(0)

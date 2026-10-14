extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	assert(option>=0)
	var content := str(args[option+1]);var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var codec=preload("res://source_save_icon.gd")
	var loaded := codec.load_asset(content,manifest.saveIcon);assert(not loaded.has("fault"))
	assert(loaded.image.get_size()==Vector2i(48,16))
	for frame in range(3):
		for pixel in range(256):
			var packed := int(loaded.data.frames[frame][pixel>>1])
			var index := (packed>>((pixel&1)*4))&15
			var word := int(loaded.data.palette[index]);var color: Color=loaded.image.get_pixel(frame*16+(pixel&15),pixel>>4)
			assert(roundi(color.r*255)==roundi(float(word&31)*255/31.0))
			assert(roundi(color.g*255)==roundi(float((word>>5)&31)*255/31.0))
			assert(roundi(color.b*255)==roundi(float((word>>10)&31)*255/31.0))
			assert(color.a==(0.0 if word==0 else 1.0))
	var bad: Dictionary=manifest.saveIcon.duplicate();bad.sha256="bad"
	assert(codec.load_asset(content,bad).has("fault"))
	var row := codec.layout(3,1,2)
	assert(row.labels[0].glyphs[0].position==Vector2i(211,70))
	assert(row.labels[0].glyphs[1].position==Vector2i(237,67) and row.labels[0].glyphs[1].size==Vector2i(38,23))
	assert(codec.layout(16,0,0).has("fault"))
	var fresh := codec.layout(1,1,0,true)
	assert(fresh.labels[0].glyphs.size()==1 and fresh.labels[0].glyphs[0].size==Vector2i(26,16))
	print("PASS: original icon hash/packed pixel/palette decode, transparency and native26-step centered selection geometry")
	quit(0)

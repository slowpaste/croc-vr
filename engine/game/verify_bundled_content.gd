extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args();var option:=args.find("--bundle")
	assert(option>=0);var directory:=str(args[option+1])
	var installer=preload("res://source_bundled_content.gd").new()
	var index:Dictionary=installer.read_index(directory.path_join("index.json"))
	assert(not index.is_empty() and installer.prepare_archives(index,directory))
	var worker:=Thread.new();assert(worker.start(installer.install.bind(index))==OK)
	while worker.is_alive():await process_frame
	assert(worker.wait_to_finish() and installer.status().fault.is_empty())
	assert(installer.mount(index))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://imported_data/manifest.json"))
	assert(manifest.schema==1)
	var texture:Dictionary={}
	for entry in manifest.textures:
		if entry.name=="TK00_ENM.BIN":texture=entry;break
	var image:=Image.load_from_file("res://imported_data/"+str(texture.image))
	assert(image!=null and image.get_width()==1024 and image.get_pixel(0,0)==Color.WHITE)
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("fixture.json")))
	var mesh=ResourceLoader.load("res://imported_data/"+str(fixture.mesh),"",ResourceLoader.CACHE_MODE_IGNORE)
	assert(mesh is ArrayMesh and mesh.get_surface_count()>0)
	var original:=FileAccess.open(str(fixture.original),FileAccess.READ)
	var packaged:=FileAccess.open("res://imported_data/"+str(fixture.seekFile),FileAccess.READ)
	assert(original!=null and packaged!=null and original.get_length()==packaged.get_length())
	for offset in [0,packaged.get_length()/2,maxi(0,packaged.get_length()-256)]:
		original.seek(offset);packaged.seek(offset);assert(original.get_buffer(128)==packaged.get_buffer(128))
	# Relaunch skips extraction using the verified cache, preserving its mtime.
	var pack:Dictionary=index.packs[0];var cached:String=installer.cached_path(pack)
	var modified:=FileAccess.get_modified_time(cached)
	assert(installer.install(index) and FileAccess.get_modified_time(cached)==modified)
	var bad:Dictionary=index.duplicate(true);bad.packs[0].sha256="a".repeat(64)
	assert(not installer.install(bad) and not FileAccess.file_exists(installer.cached_path(bad.packs[0])+".verified"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(installer.cached_path(bad.packs[0])+".part"))
	print("PASS: automatic bundled data install/hash validation, cache reuse, raw PNG, prepared mesh, seekable audio and corrupt-pack rejection")
	quit()

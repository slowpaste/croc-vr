extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var record: Dictionary = manifest.cutsceneAudio[0]
	var reader := preload("res://source_xa_channel_reader.gd").new()
	assert(reader.open_channel(content,record))
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	var frames := 0
	for index in range(207):
		var block: Dictionary = reader.read_sector()
		assert(not block.has("fault") and not block.get("end",false) and block.rate == 37800 and not block.emphasis)
		assert(block.source_sector == int(record.sourceLba)+7+index*8)
		hash.update(block.pcm); frames += int(block.frames)
	assert(frames == 417312 and hash.finish().hex_encode() == record.pcmSha256)
	assert(reader.read_sector().end)
	reader.close_channel()
	print("PASS: all207 original SAD audio sectors decode to the exact exported417312 stereo PCM frames")
	quit(0)

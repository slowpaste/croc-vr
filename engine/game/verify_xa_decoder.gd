extends SceneTree
const Decoder = preload("res://source_xa_decoder.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	for record in index.streams:
		var raw := FileAccess.open(content.path_join(record.compressedFile),FileAccess.READ)
		var wav := FileAccess.open(content.path_join(record.file),FileAccess.READ)
		wav.seek(44)
		var decoder := Decoder.new()
		for sector in range(mini(200,int(record.sectors))):
			var result := decoder.decode(raw.get_buffer(2352))
			if result.has("fault") or result.pcm != wav.get_buffer(8064):
				push_error("Native XA decoder differs from source-export PCM channel "+str(record.logical))
				quit(1)
				return
		decoder.reset()
		if decoder.history != [[0,0],[0,0]]:
			quit(1)
			return
	print("PASS: native XA decoder matches up to 200 consecutive source PCM sectors of all70 channels and resets predictor state")
	quit(0)

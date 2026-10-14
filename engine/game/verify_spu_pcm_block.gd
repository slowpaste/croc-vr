extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var asset: Dictionary = {}
	for candidate in manifest.linkage.rooms["MP033_02.MAP"].assets:
		if candidate.name=="NEPTTAIL":asset=candidate;break
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var wav := AudioStreamWAV.load_from_file(content.path_join(info.file))
	if wav==null or wav.stereo or wav.format!=AudioStreamWAV.FORMAT_16_BITS:quit(1);return
	var mix = preload("res://source_spu_voice_mix.gd")
	var output: Dictionary = mix.mono16_block(wav.data,0,int(info.samples),250,-250)
	if output.has("fault") or output.frames.size()!=int(info.samples):quit(1);return
	var nonzero := 0
	for index in range(output.frames.size()):
		var sample: int = wav.data.decode_s16(index*2)
		var actual: Vector2 = output.frames[index]
		if actual!=Vector2(mix.frame(sample,250,-250))/32768.0:quit(1);return
		if actual!=Vector2.ZERO:nonzero+=1
		if actual.x*actual.y>0 or absf(actual.x+actual.y)>1.0/32768.0:push_error("Decoded rear surround PCM lost opposite phase");quit(1);return
	if nonzero==0 or not mix.mono16_block(wav.data,-1,1,1,1).has("fault"):quit(1);return
	print("PASS: actual decoded NEPTTAIL mono PCM preserves signed rear channels across all samples")
	quit(0)

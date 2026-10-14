extends SceneTree
const Decoder = preload("res://source_xa_decoder.gd")
const Zigzag = preload("res://source_xa_zigzag.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var source := FileAccess.open(content.path_join(index.streams[0].compressedFile),FileAccess.READ)
	var packets: Array[PackedByteArray] = []
	for sector in range(200): packets.append(source.get_buffer(2352))
	var decoder := Decoder.new()
	var filter := Zigzag.new()
	var durations: Array[int] = []
	var filter_durations: Array[int] = []
	for packet in packets:
		var start := Time.get_ticks_usec()
		var result := decoder.decode(packet)
		durations.append(Time.get_ticks_usec()-start)
		if result.has("fault"): push_error(str(result)); quit(1); return
		start = Time.get_ticks_usec()
		var interpolated := filter.process_pcm(result.pcm,int(result.rate))
		filter_durations.append(Time.get_ticks_usec()-start)
		if interpolated.has("fault") or interpolated.frames != 2352: quit(1); return
	durations.sort()
	var total := 0
	for duration in durations: total += duration
	print("XA_DECODE_PROFILE: sectors=200 mean_us=",total/200.0," p95_us=",durations[189]," max_us=",durations.back()," source_sector_audio_ms=",2016.0/37800.0*1000.0)
	filter_durations.sort()
	var filter_total := 0
	for duration in filter_durations: filter_total += duration
	print("XA_INTERPOLATION_PROFILE: sectors=200 mean_us=",filter_total/200.0," p95_us=",filter_durations[189]," max_us=",filter_durations.back()," combined_mean_us=",(total+filter_total)/200.0)
	quit(0)

extends SceneTree
const Mix = preload("res://source_spu_voice_mix.gd")
func _initialize() -> void:
	for sample in [[0,0],[16383,16383],[16384,-16384],[32767,-1],[-250,-250],[40000,7232]]:
		if Mix.fixed_level(sample[0])!=sample[1]:push_error("Original fixed-volume mask/sign mismatch");quit(1);return
	if Mix.frame(32767,16383,-16384)!=Vector2i(32765,-32767):quit(1);return
	if Mix.frame(-32768,16383,-16384)!=Vector2i(-32766,32767):quit(1);return
	var rear := Mix.frame(10000,250,-250)
	if rear.x<=0 or rear.y>=0:push_error("Rear surround lost opposite PCM phase");quit(1);return
	var pcm:=PackedByteArray();pcm.resize(65536*2)
	for i in range(65536):pcm.encode_s16(i*2,i-32768)
	for channels in [Vector2i(16383,-16384),Vector2i(250,-250),Vector2i(40000,32767),Vector2i.ZERO]:
		var actual:Dictionary=Mix.mono16_block(pcm,0,65536,channels.x,channels.y)
		for i in range(65536):assert(actual.frames[i]==Vector2(Mix.frame(i-32768,channels.x,channels.y))/32768.0)
	print("PASS: fixed SPU attribute conversion and signed PCM phase; hardware comparison pending")
	quit(0)

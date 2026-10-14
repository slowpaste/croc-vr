extends RefCounted
const VM = preload("res://asl_vm.gd")
static func title_layout(data: Dictionary, tick: int) -> Dictionary:
	# Main140ec..1410c: blink bit4 and signed tick cutoff1050.
	if (tick&16) == 0 or tick >= 1050:
		return {"labels":[]}
	if not data.has("titlePrompt"):
		return {"fault":"Missing original title prompt"}
	var adapted := data.duplicate()
	adapted.labels = [data.titlePrompt,{"text":"","y":0},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]
	var result := layout(adapted,[65536,65536,65536,65536,65536],false)
	if not result.has("fault"):
		result.labels.resize(1)
	return result
# Centered menu text478c8..47ad4; source glyph sprite rendering is separate.
static func layout(data: Dictionary, sizes: Array, credits: bool) -> Dictionary:
	if data.get("labels",[]).size() != 5 or sizes.size() != 5 or not data.has("glyphs"):
		return {"fault":"Missing original menu text data"}
	var result: Array = []
	for index in range(5):
		var label: Dictionary = data.credits if index == 3 and credits else data.labels[index]
		var text := str(label.text)
		var size := int(sizes[index])
		var width := 0
		for character in text.length():
			var key := str(text.unicode_at(character))
			if not data.glyphs.has(key):
				return {"fault":"Missing original menu glyph metrics"}
			width = VM.signed32(width+((VM.signed32(int(data.glyphs[key].advance)*size)&0xffffffff)>>16))
		var x := VM.signed32(int(data.centerX)-((width&0xffffffff)>>1))
		var y := VM.signed32(int(label.y)+7-((VM.signed32(size*14)&0xffffffff)>>17))
		var glyphs: Array = []
		for character in text.length():
			var code := text.unicode_at(character)
			var glyph: Dictionary = data.glyphs[str(code)]
			if code > 32:
				var w := (VM.signed32(int(glyph.width)*size)&0xffffffff)>>16
				var h := (VM.signed32(int(glyph.height)*size)&0xffffffff)>>16
				glyphs.append({"sprite":int(glyph.sprite),"position":Vector2i(x,y),"size":Vector2i(w,h)})
			x = VM.signed32(x+((VM.signed32(int(glyph.advance)*size)&0xffffffff)>>16))
		result.append({"text":text,"width":width,"glyphs":glyphs})
	return {"labels":result}

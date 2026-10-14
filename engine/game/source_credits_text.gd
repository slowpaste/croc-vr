extends RefCounted
const VM = preload("res://asl_vm.gd")
static func layout(state: Dictionary, fonts: Dictionary) -> Dictionary:
	if not fonts.has_all(["small","large"]): return {"fault":"Missing original credits fonts"}
	var labels: Array = []
	for line in preload("res://source_credits_state.gd").layout(state):
		var metrics: Dictionary = fonts.large if bool(line.large) else fonts.small
		var text := str(line.text); var width := 0
		for index in range(text.length()):
			var key := str(text.unicode_at(index))
			if not metrics.has(key): return {"fault":"Missing original credits glyph"}
			width = VM.signed32(width+int(metrics[key].advance))
		var x: int = VM.signed32(256-((width&0xffffffff)>>1))
		var glyphs: Array = []
		for index in range(text.length()):
			var code := text.unicode_at(index); var glyph: Dictionary = metrics[str(code)]
			if code > 32: glyphs.append({"sprite":int(glyph.sprite),"position":Vector2i(x,int(line.y)),"size":Vector2i(int(glyph.width),int(glyph.height))})
			x = VM.signed32(x+int(glyph.advance))
		labels.append({"text":text,"width":width,"glyphs":glyphs})
	return {"labels":labels}

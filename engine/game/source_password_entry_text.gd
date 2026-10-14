extends RefCounted
static func layout(data: Dictionary, state: Dictionary) -> Dictionary:
	if not data.has_all(["passwordEntry","passwordAlphabet","glyphs","headingGlyphs"]) or not state.has("symbols") or state.symbols.size() != 16:
		return {"fault":"Missing original password-entry presentation"}
	if data.passwordAlphabet.size() != 5: return {"fault":"Invalid original password alphabet"}
	var text = preload("res://source_game_over_text.gd")
	var labels: Array = [text.centered(data.passwordEntry.heading,data.headingGlyphs)]
	for key in ["instructions","deletePrompt","cancelPrompt"]:
		labels.append(text.centered(data.passwordEntry[key],data.glyphs))
	var row := ""
	for index in range(15):
		var symbol := int(state.symbols[index])
		if symbol < 0 or symbol > 4: return {"fault":"Invalid password-entry display symbol"}
		row += String.chr(int(data.passwordAlphabet[symbol]))
	labels.append(text.centered({"text":row,"y":100},data.glyphs))
	for label in labels:
		if label.has("fault"): return label
	return {"labels":labels}

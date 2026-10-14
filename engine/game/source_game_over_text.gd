extends RefCounted
static func centered(label: Dictionary, metrics: Dictionary) -> Dictionary:
	var width := 0
	for character in str(label.text):
		var key := str(character.unicode_at(0))
		if not metrics.has(key): return {"fault":"Missing original password-screen glyph"}
		width += int(metrics[key].advance)
	var x := 256-int(width/2)
	var glyphs: Array = []
	for character in str(label.text):
		var code := character.unicode_at(0)
		var glyph: Dictionary = metrics[str(code)]
		if code > 32:
			glyphs.append({"sprite":int(glyph.sprite),"position":Vector2(x,int(label.y)),"size":Vector2(int(glyph.width),int(glyph.height))})
		x += int(glyph.advance)
	return {"text":label.text,"width":width,"glyphs":glyphs}
static func layout(data: Dictionary) -> Dictionary:
	if not data.has_all(["heading","explanation","passwordPrefix","glyphs","headingGlyphs"]): return {"fault":"Missing original password-screen labels"}
	var heading := centered(data.heading,data.headingGlyphs)
	var explanation := centered(data.explanation,data.glyphs)
	var prefix := centered(data.passwordPrefix,data.glyphs)
	for label in [heading,explanation,prefix]:
		if label.has("fault"): return label
	var labels: Array = [heading,explanation,prefix]
	if data.has("passwordConnector"):
		var connector := centered(data.passwordConnector,data.glyphs)
		if connector.has("fault"): return connector
		labels.append(connector)
	if data.has("returnPrompt"):
		var prompt := centered(data.returnPrompt,data.glyphs)
		if prompt.has("fault"): return prompt
		labels.append(prompt)
	return {"labels":labels}

static func password_row(data: Dictionary, progress: Array, selected: int, pickups: Array) -> Dictionary:
	if not data.has_all(["passwordAlphabet","glyphs"]): return {"fault":"Missing original password symbol metrics"}
	var encoder = preload("res://source_password.gd")
	var label: Dictionary = encoder.display(encoder.encode(progress,selected,pickups),data.passwordAlphabet)
	if label.has("fault"): return label
	return centered(label,data.glyphs)

static func stage_name_row(data: Dictionary, name: String) -> Dictionary:
	# Native47d4c uses the separate width/sprite tables, scale1.0 and height13.
	# '#' advances the pen but suppresses the quad, like bytes<=32.
	if not data.has("stageNameGlyphs"): return {"fault":"Missing original stage-name glyph metrics"}
	var row := centered({"text":name,"y":96},data.stageNameGlyphs)
	if row.has("fault"): return row
	var glyphs: Array = []
	var x := 256-int(int(row.width)/2)
	for character in name:
		var code := character.unicode_at(0)
		var glyph: Dictionary = data.stageNameGlyphs[str(code)]
		if code > 32 and code != 35:
			glyphs.append({"sprite":int(glyph.sprite),"position":Vector2(x,96),"size":Vector2(int(glyph.width),13)})
		x += int(glyph.advance)
	row.glyphs = glyphs
	return row

static func level_name_row(data: Dictionary, names: Array, level: int) -> Dictionary:
	if names.size() != 100 or level < 0 or level >= 100:
		return {"fault":"Invalid original level-name lookup"}
	return stage_name_row(data,str(names[level]))

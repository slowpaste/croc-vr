extends RefCounted
static func layout() -> Dictionary:
	# Source49630..496d4: row-major1920 quads,64 columns/30 rows,8px pitch.
	var glyphs: Array = []
	for row in range(30):
		for column in range(64):
			glyphs.append({"sprite":row*64+column,"position":Vector2(column*8,row*8),"size":Vector2(8,8)})
	return {"labels":[{"glyphs":glyphs}]}

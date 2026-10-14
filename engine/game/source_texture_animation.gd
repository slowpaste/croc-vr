extends RefCounted
var texture: ImageTexture
var bitmap: Image
var streams: Array = []
func setup(target: ImageTexture, image: Image, descriptors: Array, content: String) -> bool:
	texture = target; bitmap = image
	for descriptor in descriptors:
		var sheet := Image.load_from_file(content.path_join(str(descriptor.image)))
		if sheet == null or sheet.is_empty() or int(descriptor.frames) <= 0: return false
		if sheet.get_width() != int(descriptor.width) or sheet.get_height() != int(descriptor.height)*int(descriptor.frames): return false
		var state: Dictionary = descriptor.duplicate(true)
		state.sheet = sheet; state.counter = 0; state.frame = 0; state.displayed = -1
		streams.append(state)
	return true
func advance(reverse_palettes:bool=false) -> bool:
	var changed := false
	for state in streams:
		if state.get("paletteCycle",false):
			if int(state.counter)!=int(state.delay):state.counter+=1;continue
			state.counter=0;state.frame=posmod(int(state.frame)+(-1 if reverse_palettes else 1),int(state.frames))
			for rect in state.rectangles:
				bitmap.blit_rect(state.sheet,Rect2i(int(rect.x),int(rect.y)+int(state.frame)*int(state.height),int(rect.width),int(rect.height)),Vector2i(int(state.x)+int(rect.x),int(state.y)+int(rect.y)))
			state.displayed=state.frame;changed=true;continue
		# Retail25f94..26000: increment, unsigned interval test, upload then wrap.
		state.counter = (int(state.counter)+1)&0xffffffff
		if int(state.counter) < int(state.interval): continue
		state.counter = 0
		for rect in state.rectangles:
			var source := Rect2i(int(rect.x),int(rect.y)+int(state.frame)*int(state.height),int(rect.width),int(rect.height))
			bitmap.blit_rect(state.sheet,source,Vector2i(int(state.x)+int(rect.x),int(state.y)+int(rect.y)))
		state.displayed = state.frame
		state.frame = (int(state.frame)+1)%int(state.frames)
		changed = true
	if changed: texture.update(bitmap)
	return changed

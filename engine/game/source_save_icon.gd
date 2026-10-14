extends RefCounted
static func load_asset(content: String, binding: Dictionary) -> Dictionary:
	if not binding.has_all(["file","sha256","executableSha256"]):return {"fault":"Missing save-icon binding"}
	var path := content.path_join(str(binding.file))
	if FileAccess.get_sha256(path)!=str(binding.sha256):return {"fault":"Save-icon payload hash mismatch"}
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("schema",0))!=1 or data.get("executableSha256","")!=binding.executableSha256:return {"fault":"Invalid save-icon provenance"}
	if int(data.get("width",0))!=16 or int(data.get("height",0))!=16 or not data.has_all(["palette","frames"]) or data.palette.size()!=16 or data.frames.size()!=3:return {"fault":"Invalid save-icon dimensions"}
	var pixels := PackedByteArray();pixels.resize(48*16*4)
	for word in data.palette:
		if float(word)!=int(word) or int(word)<0 or int(word)>65535:return {"fault":"Invalid save-icon palette"}
	for frame in range(3):
		if data.frames[frame].size()!=128:return {"fault":"Truncated save-icon frame"}
		for byte in data.frames[frame]:
			if float(byte)!=int(byte) or int(byte)<0 or int(byte)>255:return {"fault":"Invalid packed save-icon byte"}
		for pixel in range(256):
			var index := (int(data.frames[frame][pixel>>1])>>((pixel&1)*4))&15
			var word := int(data.palette[index])
			var offset := ((pixel>>4)*48+frame*16+(pixel&15))*4
			pixels[offset]=roundi(float(word&31)*255.0/31.0)
			pixels[offset+1]=roundi(float((word>>5)&31)*255.0/31.0)
			pixels[offset+2]=roundi(float((word>>10)&31)*255.0/31.0)
			pixels[offset+3]=0 if word==0 else 255
	return {"image":Image.create_from_data(48,16,false,Image.FORMAT_RGBA8,pixels),"data":data}
static func layout(count: int, selected: int, frame: int, new_entry: bool = false) -> Dictionary:
	var total := count+int(new_entry)
	if count<0 or total>15 or selected<0 or selected>=maxi(total,1) or frame<0 or frame>2:return {"fault":"Invalid saved-icon row"}
	var sizes := [];var width := 0
	for index in range(total):
		var scale := 98303 if index==selected else 65536
		sizes.append(scale);width+=(26*scale)>>16
	var x := 256-(width>>1);var glyphs := []
	for index in range(total):
		var scale: int=sizes[index]
		var height: int=(16*int(scale))>>16
		var step: int=(26*int(scale))>>16
		if index<count:glyphs.append({"sprite":frame,"position":Vector2i(x,78-((16*int(scale))>>17)),"size":Vector2i(step,height)})
		x+=step
	return {"labels":[{"text":"","glyphs":glyphs}]}

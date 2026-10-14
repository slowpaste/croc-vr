extends RefCounted
# Preserve linear HDR framebuffer bytes exactly; no PNG/gamma quantization.
static func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	return hash.finish().hex_encode()
static func encode(image: Image) -> Dictionary:
	if image == null or image.is_empty(): return {"fault":"Missing movie image"}
	var raw := image.get_data()
	return {"bytes":raw.compress(FileAccess.COMPRESSION_ZSTD),"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"raw_size":raw.size(),"raw_sha256":digest(raw)}
static func decode(bytes: PackedByteArray, metadata: Dictionary) -> Dictionary:
	if int(metadata.get("width",0)) != 512 or int(metadata.get("height",0)) != 240 or int(metadata.get("raw_size",0)) <= 0 or int(metadata.raw_size) > 4000000:
		return {"fault":"Invalid movie image dimensions or length"}
	var format := int(metadata.get("format",-1))
	if format < 0 or format >= Image.FORMAT_MAX: return {"fault":"Invalid movie image format"}
	var raw := bytes.decompress(int(metadata.raw_size),FileAccess.COMPRESSION_ZSTD)
	if raw.size() != int(metadata.raw_size) or digest(raw) != str(metadata.get("raw_sha256","")):
		return {"fault":"Movie image data checksum differs"}
	var image := Image.create_from_data(512,240,false,format,raw)
	if image == null or image.is_empty(): return {"fault":"Movie image creation failed"}
	return {"image":image}

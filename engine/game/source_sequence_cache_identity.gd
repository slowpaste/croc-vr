extends RefCounted
# Bump whenever geometry, lighting, projection or pass planning changes. This
# remains available in exported builds, where script source files may be stripped.
const RENDERER_REVISION = "ordered-point-lighting-geometry384-display-y-facing-images-v5"
static func components(config: Dictionary, tables: Dictionary, full_precision: bool = false) -> Dictionary:
	var result := {}
	for index in range(config.parts.size()):
		for key in ["data","models","room","anchor","track_models","room_atlas","room_lighting","atlas","sky_models","sky_atlas"]:
			result[str(index)+":"+key] = JSON.stringify(config.parts[index][key],"",true,full_precision).sha256_text()
	result.tables = JSON.stringify(tables,"",true,full_precision).sha256_text()
	result.renderer = RENDERER_REVISION
	return result
static func fingerprint(config: Dictionary, tables: Dictionary, full_precision: bool = true) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for part in config.parts:
		for key in ["data","models","room","anchor","track_models","room_atlas","room_lighting","atlas","sky_models","sky_atlas"]:
			hash.update(JSON.stringify(part[key],"",true,full_precision).to_utf8_buffer())
	hash.update(JSON.stringify(tables,"",true,full_precision).to_utf8_buffer())
	hash.update(RENDERER_REVISION.to_utf8_buffer())
	return hash.finish().hex_encode()

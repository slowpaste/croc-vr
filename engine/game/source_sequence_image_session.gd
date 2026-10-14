extends "res://source_sequence_session.gd"
# Optional lossless presentation backend; inherited timeline/audio/flow remains.
var image_directory := ""
var image_descriptor: Dictionary = {}
var image_textures: Dictionary = {}
var image_lru: Array[String] = []
var current_image: Texture2D = null
var expected_image_fingerprint := ""
func setup_images(directory: String, content: String, manifest: Dictionary, tables: Dictionary, scene_id: int, cd_state: Dictionary) -> bool:
	var descriptor_path := directory.path_join("index.json")
	if not FileAccess.file_exists(descriptor_path): fault = "Movie image descriptor missing";return false
	image_descriptor = JSON.parse_string(FileAccess.get_file_as_string(descriptor_path))
	if int(image_descriptor.get("schema",0)) != 1 or int(image_descriptor.get("scene_id",-1)) != scene_id:
		fault = "Movie image descriptor identity differs";return false
	image_directory = directory;image_textures.clear();image_lru.clear();current_image = null
	var preparation:Dictionary=cd_state.get("preparation",{})
	var source:Dictionary=preparation.config if not preparation.is_empty() else preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene_id,cd_state)
	if source.has("fault"): fault = str(source.fault);return false
	expected_image_fingerprint = preparation.identity if not preparation.is_empty() else preload("res://source_sequence_cache_identity.gd").fingerprint(source,tables)
	if str(image_descriptor.get("fingerprint","")) != expected_image_fingerprint or image_descriptor.get("parts",[]).size() != source.parts.size():
		fault = "Movie image cache is stale or incomplete";return false
	for index in range(source.parts.size()):
		if image_descriptor.parts[index].frames.size() != source.parts[index].data.frames.size():
			fault = "Movie image part frame count differs";return false
	return super.setup(content,manifest,tables,scene_id,cd_state)
func present_frame(part_index: int, local_index: int) -> bool:
	if part_index < 0 or part_index >= image_descriptor.parts.size() or local_index < 0 or local_index >= image_descriptor.parts[part_index].frames.size():
		fault = "Movie image frame outside descriptor";return false
	var key := "%d:%d"%[part_index,local_index]
	if not image_textures.has(key):
		var metadata: Dictionary = image_descriptor.parts[part_index].frames[local_index]
		var file := str(metadata.get("file",""))
		if file.get_file() != file or not file.ends_with(".cfi"): fault = "Invalid movie image path";return false
		var path := image_directory.path_join(file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(metadata.get("sha256","")):
			fault = "Movie image payload missing or changed";return false
		var decoded := preload("res://source_cutscene_image_codec.gd").decode(FileAccess.get_file_as_bytes(path),metadata)
		if decoded.has("fault"): fault = str(decoded.fault);return false
		image_textures[key] = ImageTexture.create_from_image(decoded.image)
	image_lru.erase(key);image_lru.append(key)
	while image_lru.size() > 4:
		image_textures.erase(image_lru.pop_front())
	current_image = image_textures[key]
	return true
func output_texture() -> Texture2D: return current_image

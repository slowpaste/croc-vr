extends SceneTree
# Read the exported app's data using the host editor; do not execute ARM64 code.
func _initialize() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://bundled-content/index.json"))
	if not parsed is Dictionary or parsed.get("packs", []).is_empty():
		fail("Frame package has no bundled-data index"); return
	for pack in parsed.packs:
		if not ProjectSettings.load_resource_pack("res://bundled-content/" + str(pack.archive), false):
			fail("Frame bundled archive could not be mounted"); return
		var source := FileAccess.open("res://" + str(pack.file), FileAccess.READ)
		if source == null or source.get_length() != int(pack.bytes):
			fail("Frame bundled pack length differs"); return
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		while source.get_position() < source.get_length():
			var bytes := source.get_buffer(mini(1024 * 1024, source.get_length() - source.get_position()))
			if bytes.is_empty():
				fail("Frame bundled pack is truncated"); return
			hash.update(bytes)
		if hash.finish().hex_encode() != str(pack.sha256):
			fail("Frame bundled pack hash differs"); return
	print("PASS: Frame executable contains all imported packs with verified lengths and SHA-256 hashes")
	quit(0)
func fail(message: String) -> void:
	push_error(message)
	quit(1)

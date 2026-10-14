extends RefCounted
static func select_scene(mode: int, previous: int, frame_seed: int, random_source: RefCounted) -> Dictionary:
	# Loader4ac20..4ac64; mode7 skips srand/rand and forces scene4.
	var index := 4
	if mode != 7:
		random_source.bios_seed = frame_seed&0xffffffff
		index = random_source.bios_rand()&3
		while index == previous:
			index = random_source.bios_rand()&3
	return {"index":index,"level":90+index,"room":0,"map":"MP%03d_00.MAP" % (90+index)}

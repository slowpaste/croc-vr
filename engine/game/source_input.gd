extends RefCounted
const VM = preload("res://asl_vm.gd")
static func analog_packet(packet: PackedByteArray, scheme: int, game_mode: int, calibration: Dictionary, context: Dictionary, roots: Array, angles: Array) -> Dictionary:
	if packet.size()<8:return {"fault":"Incomplete original analog packet"}
	if packet[0]==255:return {"held":0,"pad_kind":0}
	if (packet[1]>>4)!=7:return {"fault":"Packet is not original analog pad type7"}
	if scheme not in [0,1,2] or not calibration.has_all(["center","lower_midpoint","upper_midpoint","half_radius"]):return {"fault":"Incomplete original analog settings"}
	var left := Vector2i(packet[6],packet[7]);var right := Vector2i(packet[4],packet[5])
	var directions := analog_directions(left,right,calibration,game_mode)
	if directions.has("fault"):return directions
	var measured := analog_measure(left,calibration.center,roots,angles)
	if measured.has("fault"):return measured
	var held := int(directions.held)|analog_buttons(int(packet[2])|(int(packet[3])<<8),scheme)
	if bool(context.get("player_present",false)) and int(measured.magnitude)>(int(calibration.half_radius)&0xffffffff):
		if not context.has_all(["camera_yaw","player_yaw","room_type"]):return {"fault":"Missing original analog player/view context"}
		held|=analog_action_sectors(int(measured.angle),int(context.camera_yaw),int(context.player_yaw),int(context.room_type))
	return {"held":VM.signed32(held),"pad_kind":2,"magnitude":measured.magnitude,"angle":measured.angle,"right_override":directions.right_override}
static func analog_buttons(active_low: int, scheme: int) -> int:
	var pressed := (~active_low)&65535
	# Native39688..396f0 d-pad;3999c..39b58 face/common buttons.
	var pairs: Array=[[0x80,0x20000],[0x20,0x80000],[0x10,0x10000],[0x40,0x40000]]
	pairs.append_array([[0x8000,0x400000],[0x4000,0x801000],[0x2000,0x200010],[0x1000,0x100800]] if scheme==2 else [[0x8000,0x400800],[0x4000,0x800010],[0x2000,0x201000],[0x1000,0x100000]])
	pairs.append_array([[0x400,0x80],[0x800,0x100],[8,0x200],[1,0x400],[0x100,0x6000],[0x200,0xa000]])
	var flags := 0
	for pair in pairs:
		if (pressed&pair[0])!=0:flags|=pair[1]
	return VM.signed32(flags)
static func analog_measure(sample: Vector2i, center: Vector2i, roots: Array, angles: Array) -> Dictionary:
	if roots.size()!=192 or angles.size()!=1025:return {"fault":"Missing original analog root/angle tables"}
	for point in [sample,center]:
		if point.x<0 or point.x>255 or point.y<0 or point.y>255:return {"fault":"Analog measurement requires unsigned pad bytes"}
	# Native3985c..398c4: calibrated difference<<6, signed low32 squares,
	# original545bc lookup root>>12 and original5558c angle.
	var delta := (center-sample)*64
	var square := VM.signed32(VM.signed32(delta.x*delta.x)+VM.signed32(delta.y*delta.y))
	var collision=preload("res://source_collision.gd")
	var direction: Dictionary=collision.wall_normal_angle(delta,angles)
	if direction.has("fault"):return direction
	return {"magnitude":collision.distance_root(square,roots)>>12,"angle":int(direction.angle)&65535}
static func analog_action_sectors(angle: int, camera_yaw: int, player_yaw: int, room_type: int) -> int:
	# Native398f4..39998: types1/11 retain stick angle; other rooms use
	# camera-relative angle minus actor yaw, sign-extended from12 bits.
	var value := angle if room_type in [1,11] else ((camera_yaw+angle)&4095)-player_yaw
	var relative := ((value&4095)^2048)-2048
	var flags := 0
	if ((relative+511)&65535)<1023:flags|=1
	if ((relative+1663)&65535)<1279:flags|=8
	if ((relative-385)&65535)<1279:flags|=4
	if ((relative+1536)&65535)>=3073:flags|=2
	return flags
static func analog_directions(left: Vector2i, right: Vector2i, calibration: Dictionary, game_mode: int) -> Dictionary:
	if not calibration.has_all(["lower_midpoint","upper_midpoint"]):return {"fault":"Missing calibrated analog midpoint bounds"}
	for point in [left,right]:
		if point.x<0 or point.x>255 or point.y<0 or point.y>255:return {"fault":"Analog direction samples must be unsigned pad bytes"}
	var low: Vector2i=calibration.lower_midpoint
	var high: Vector2i=calibration.upper_midpoint
	# Native396f4..39858 uses strict unsigned midpoint comparisons.
	var override := (right.x < (low.x&0xffffffff) or right.x > (high.x&0xffffffff) or right.y < (low.y&0xffffffff) or right.y > (high.y&0xffffffff))
	var sample: Vector2i=right if override else left
	var flags := 0x40000000 if override and game_mode==4 else 0
	if sample.x < (low.x&0xffffffff):flags|=0x20000
	if sample.x > (high.x&0xffffffff):flags|=0x80000
	if sample.y < (low.y&0xffffffff):flags|=0x10000
	if sample.y > (high.y&0xffffffff):flags|=0x40000
	return {"held":VM.signed32(flags),"right_override":override}
static func analog_thresholds(center: Vector2i, minimum: Vector2i, maximum: Vector2i) -> Dictionary:
	# Calibration0x8003922c..0x80039300 takes the unsigned minimum axis extent.
	var extent := mini((center.x-minimum.x)&0xffffffff,(maximum.x-center.x)&0xffffffff)
	extent = mini(extent,mini((center.y-minimum.y)&0xffffffff,(maximum.y-center.y)&0xffffffff))
	return {"idle_threshold":extent>>1,"run_threshold":VM.signed32(extent-4)}
static func digital_pad(active_low: int, scheme: int, game_mode: int) -> int:
	# Connected digital-pad branch 0x80039350..0x80039664, common tail39aa4.
	var pressed := (~active_low)&65535
	var modifier := 0x8000 if scheme == 2 else 0x1000
	var result := 0
	if (pressed&modifier) != 0:
		result |= (0x00400000 if scheme == 2 else 0x00100000)
		if game_mode == 4:
			result |= 0x40000000
	if (result&0x40000000) != 0:
		for pair in [[0x80,0x20000],[0x20,0x80000],[0x10,0x10000],[0x40,0x40000]]:
			if (pressed&pair[0]) != 0:
				result |= pair[1]
	else:
		var pairs := [[0x80,0x20004],[0x20,0x80008]]
		if scheme == 1:
			pairs.append_array([[0x10,0x10010],[0x40,0x41000],[0x4000,0x800001],[0x2000,0x200002]])
		else:
			pairs.append_array([[0x10,0x10001],[0x40,0x40002],[0x4000,0x801000 if scheme == 2 else 0x800010],[0x2000,0x200010 if scheme == 2 else 0x201000]])
		pairs.append([0x1000,0x100800] if scheme == 2 else [0x8000,0x400800])
		pairs.append_array([[0x400,0x80],[0x800,0x100]])
		for pair in pairs:
			if (pressed&pair[0]) != 0:
				result |= pair[1]
	for pair in [[8,0x200],[1,0x400],[0x100,0x6000],[0x200,0xa000]]:
		if (pressed&pair[0]) != 0:
			result |= pair[1]
	return VM.signed32(result)

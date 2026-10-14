extends RefCounted
const BUTTONS := ["A","B","X","Y"]
const SOURCE := {123:"A",125:"B",126:"X",124:"Y"}
const LETTERS := [
 [14,17,17,31,17,17,17],
 [30,17,17,30,17,17,30],
 [17,17,10,4,10,17,17],
 [17,17,10,4,4,4,4]]
static var atlas: ImageTexture
static func texture() -> ImageTexture:
	if atlas!=null:return atlas
	var pixels := Image.create(256,64,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for button in range(4):
		for y in range(64):
			for x in range(64):
				var radius := Vector2(x-31.5,y-31.5).length()
				if radius<=28:pixels.set_pixel(button*64+x,y,Color(0.9,0.93,0.93) if radius>25 else Color(0.06,0.08,0.08))
		for y in range(7):
			for x in range(5):
				if (int(LETTERS[button][y])&(1<<(4-x)))==0:continue
				for yy in range(4):
					for xx in range(4):pixels.set_pixel(button*64+22+x*4+xx,18+y*4+yy,Color.WHITE)
	atlas=ImageTexture.create_from_image(pixels)
	return atlas
static func uv(button: String) -> Array:
	var index := BUTTONS.find(button)
	var left := float(index)/4.0;var right := float(index+1)/4.0
	return [Vector2(left,0),Vector2(right,0),Vector2(left,1),Vector2(right,1)]

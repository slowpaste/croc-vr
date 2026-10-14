extends SceneTree
func _initialize() -> void:
	var lighting = preload("res://source_cutscene_lighting.gd")
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	var config := {"colorMatrix":identity,"ambientBytes":[0,0,0],"textureBase":[128,128,128]}
	var model := {"sourceNormals":[[4096,4096,4096,0],[2048,2048,2048,0]]}
	var face := {"flags":0,"color":[100,200,80],"sourceHeader":[1024,1024,1024,0]}
	assert(lighting.face_rgb(face,0,model,identity,config).rgb == [100,200,80])
	assert(lighting.face_rgb(face,1,model,identity,config).rgb == [50,100,40])
	face.flags = 0x40
	assert(lighting.face_rgb(face,0,model,identity,config).rgb == [25,50,20])
	face.flags = 1
	assert(lighting.face_rgb(face,1,model,identity,config).rgb == [64,64,64])
	face.flags = 0x61
	assert(lighting.face_rgb(face,0,{},identity,config).rgb == [128,128,128])
	print("PASS: native flat/Gouraud normals, original textured tint and flat-texture unlit bypass")
	quit(0)

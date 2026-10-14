extends RefCounted
# Immutable face/atlas attributes are prepared once; only positions and their
# generated normals change with a live foot-placement pose.
var arrays:Array=[]
var source_indices:Array=[]
var materials:Array=[]
func setup(template:ArrayMesh, model:Dictionary) -> void:
	arrays.clear();source_indices.clear();materials.clear()
	var groups:Array=[PackedInt32Array(),PackedInt32Array(),PackedInt32Array()]
	for face in model.faces:
		var group:=1 if (int(face.flags)&32)!=0 else 0
		for corner in [0,1,2,1,3,2] if face.indices.size()==4 else [0,1,2]:groups[group].append(int(face.indices[corner]))
	# Extra additive surface duplicates only faces whose template UV2 blend is 1.
	var blend_surface:=1 if not groups[0].is_empty() else 0
	if not groups[1].is_empty() and blend_surface<template.get_surface_count():
		var metadata:PackedVector2Array=template.surface_get_arrays(blend_surface)[Mesh.ARRAY_TEX_UV2]
		for index in range(groups[1].size()):
			if roundi(metadata[index].y)==1:groups[2].append(groups[1][index])
	var surface:=0
	for group in range(3):
		if groups[group].is_empty():continue
		arrays.append(template.surface_get_arrays(surface));materials.append(template.surface_get_material(surface));source_indices.append(groups[group]);surface+=1
func build(points:Array[Vector3]) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	for surface in range(arrays.size()):
		var data:Array=arrays[surface].duplicate()
		var positions:=PackedVector3Array();positions.resize(source_indices[surface].size())
		for index in range(positions.size()):positions[index]=points[source_indices[surface][index]]
		data[Mesh.ARRAY_VERTEX]=positions
		var builder:=SurfaceTool.new();builder.create_from_arrays(data,Mesh.PRIMITIVE_TRIANGLES);builder.generate_normals();builder.commit(mesh)
		mesh.surface_set_material(surface,materials[surface])
	return mesh

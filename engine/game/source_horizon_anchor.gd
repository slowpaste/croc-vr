extends RefCounted
static func transform(view: Transform3D, distance: float) -> Transform3D:
	var back:=Vector3(view.basis.z.x,0,view.basis.z.z)
	if back.length_squared()<0.000001:
		var right:=Vector3(view.basis.x.x,0,view.basis.x.z).normalized()
		back=right.cross(Vector3.UP)
	back=back.normalized()
	var level:=Basis(Vector3.UP.cross(back),Vector3.UP,back)
	return Transform3D(level,view.origin-back*distance)

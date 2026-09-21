class_name GardenLayout
extends RefCounted
const PLOT_COUNT:=24
const PLOT_SPACING:=1.05
const DECOR_SLOTS: Array[Vector3]=[
	Vector3(-3.3,0,-4.4),Vector3(3.3,0,-4.4),Vector3(0,0,-2.0),
	Vector3(-5.1,0,-2.4),Vector3(5.1,0,-2.4),Vector3(-5.1,0,.2),
	Vector3(5.1,0,.2),Vector3(-5.1,0,3.0),Vector3(5.1,0,3.0),
	Vector3(-2.7,0,-1.8),Vector3(2.7,0,-1.8),Vector3(0,0,5.0)]
static func plot_position(index: int) -> Vector3:
	var block:=index/6
	var inside:=index%6
	var x:=(-3.3 if block%2==0 else 1.2)+(inside%3)*PLOT_SPACING
	var z: float=(3.0 if block<2 else .25)+(inside/3)*PLOT_SPACING
	return Vector3(x,0,z)

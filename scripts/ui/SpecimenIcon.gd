extends Control
## Lightweight codex illustration. Locked entries show only a silhouette.
var family:="ocular"
var hue:=.3
var discovered:=false
func _ready() -> void:
	custom_minimum_size=Vector2(72,72);mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center:=Vector2(size.x*.5,37)
	var color:=Color.from_hsv(hue,.45,.83) if discovered else Color("52625b")
	draw_circle(center,34,Color("182f30"))
	match family:
		"fungal":
			draw_rect(Rect2(center+Vector2(-5,0),Vector2(10,24)),color)
			draw_style_box(_oval(color),Rect2(center+Vector2(-23,-20),Vector2(46,30)))
		"crystalline":
			for i: int in 3:
				var x: float=(i-1)*14
				draw_colored_polygon(PackedVector2Array([center+Vector2(x-9,18),center+Vector2(x,-26+abs(i-1)*12),center+Vector2(x+9,18)]),color)
		"tendril", "coralline", "spore":
			for i: int in 5:
				var tip:=center+Vector2(cos(i*PI/4+PI)*24,sin(i*PI/4+PI)*23)
				draw_line(center+Vector2(0,22),tip,color,5,true);draw_circle(tip,7,color)
		_:
			draw_circle(center,21,color)
			for i: int in 5:
				var pos:=center+Vector2(cos(i*TAU/5),sin(i*TAU/5))*24
				draw_circle(pos,6,color)
	if discovered:
		draw_circle(center+Vector2(3,-2),10,Color("f1e9c9"))
		draw_circle(center+Vector2(7,-2),5,Color("203b37"))
func _oval(color: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(18);return style

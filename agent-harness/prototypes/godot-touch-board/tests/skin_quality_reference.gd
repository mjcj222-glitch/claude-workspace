extends RefCounted
## Frozen f0187ccc reference for pixel-equivalence regression only. Original CC0.
const GOLD := Color("cdb583")
const LIGHT := Color("c3fff0")

static func contour(rect: Rect2, cut: float = 12.0) -> PackedVector2Array:
	var c := minf(cut,minf(rect.size.x,rect.size.y)*0.25)
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([p+Vector2(c,0),Vector2(e.x-c,p.y),Vector2(e.x,p.y+c),e-Vector2(0,c),e-Vector2(c,0),Vector2(p.x+c,e.y),Vector2(p.x,e.y-c),p+Vector2(0,c)])

static func _surface(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, cut: float = 12.0) -> void:
	var points := contour(rect,cut)
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom,(point.y-rect.position.y)/maxf(1,rect.size.y)))
	canvas.draw_polygon(points,colors)

static func frame(canvas: CanvasItem, rect: Rect2, tint: Color, ornamented: bool = false) -> void:
	_surface(canvas,Rect2(rect.position+Vector2(0,5),rect.size),Color("020709"),Color("020405"))
	_surface(canvas,rect,Color("74998e").lerp(tint,0.2),Color("243c3d"))
	_surface(canvas,rect.grow(-2),Color("1d353b"),Color("071317"))
	_surface(canvas,rect.grow(-6),Color("183239").lerp(tint,0.055),Color("09171e"))
	var inner := rect.grow(-8)
	canvas.draw_line(inner.position+Vector2(12,0),Vector2(inner.end.x-12,inner.position.y),Color("82baa9"),1.0,true)
	canvas.draw_line(Vector2(inner.position.x+12,inner.end.y),inner.end-Vector2(12,0),Color("020b10"),2.0,true)
	if ornamented:
		for x in [rect.position.x+18,rect.end.x-18]:
			canvas.draw_line(Vector2(x,rect.position.y+3),Vector2(x,rect.position.y+17),GOLD,2,true)
			canvas.draw_line(Vector2(x,rect.end.y-17),Vector2(x,rect.end.y-3),GOLD.darkened(0.35),2,true)
		var mid := rect.get_center().x
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(mid-7,rect.position.y+3),Vector2(mid,rect.position.y-2),Vector2(mid+7,rect.position.y+3),Vector2(mid,rect.position.y+8)]),GOLD)

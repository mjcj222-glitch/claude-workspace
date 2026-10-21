extends RefCounted
## Violet/gold material variant of the cached single-pass frame mesh.
## Original code artwork; no generated textures, RNG or gameplay dependencies.
const Base = preload("res://scripts/board_skin.gd")
const GOLD := Color("dfbe83")
const LIGHT := Color("e8caff")
static var _cache: Dictionary = {}

static func frame_mesh(rect: Rect2, tint: Color, pressed: bool = false, disabled: bool = false) -> ArrayMesh:
	var key: Array = [rect,tint,pressed,disabled]
	if _cache.has(key): return _cache[key]
	var arrays: Array = Base.frame_mesh(rect,Color("b786dc")).surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(colors.size()):
		var old: Color = colors[i]
		var light := maxf(old.r,maxf(old.g,old.b))
		var color: Color
		if light > 0.26:
			color = Color("8c6945").lerp(GOLD,clampf((light-0.26)*2.5,0,1))
		else:
			color = Color(light*0.9,light*0.52,light*1.4,old.a)
		if i >= colors.size()-8:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ratio := clampf((vertices[i].y-rect.position.y)/maxf(rect.size.y,1),0,1)
			color = Color("121018").lerp(Color("07060a"),ratio) if rect.size.y>500 else Color("261534").lerp(Color("100b18"),ratio)
		if pressed: color=color.darkened(0.24)
		if disabled: color=color.lerp(Color(light*0.7,light*0.65,light*0.8),0.7)
		colors[i]=color
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if _cache.size()>=64:_cache.clear()
	_cache[key]=mesh
	return mesh

static func frame(canvas: CanvasItem, rect: Rect2, tint: Color, ornamented: bool = false) -> void:
	canvas.draw_mesh(frame_mesh(rect,tint),null)
	if ornamented:
		for corner in [rect.position+Vector2(12,12),Vector2(rect.end.x-12,rect.position.y+12),rect.end-Vector2(12,12),Vector2(rect.position.x+12,rect.end.y-12)]:
			canvas.draw_colored_polygon(PackedVector2Array([corner+Vector2(0,-5),corner+Vector2(4,0),corner+Vector2(0,5),corner-Vector2(4,0)]),GOLD)

static func button(canvas: CanvasItem, rect: Rect2, tint: Color, state: String = "normal") -> void:
	canvas.draw_mesh(frame_mesh(rect,tint,state=="pressed",state=="disabled"),null)
	if state in ["selected","ready"]:
		canvas.draw_line(rect.position+Vector2(14,3),Vector2(rect.end.x-14,rect.position.y+3),LIGHT,2,true)
	elif state == "pressed":
		canvas.draw_polyline(Base.contour(rect.grow(-6)),Color("080511"),2,true)

static func glyph(canvas: CanvasItem, center: Vector2, kind: String, tint: Color, size: float = 32) -> void:
	Base.glyph(canvas,center,kind,tint,size)

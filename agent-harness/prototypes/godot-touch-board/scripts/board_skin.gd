extends RefCounted
## Original code-native material artwork, CC0. No external textures or RNG.
const GOLD := Color("cdb583")
const LIGHT := Color("c3fff0")
const FRAME_CACHE_LIMIT := 64
static var _frame_cache: Dictionary = {}

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

static func _ring(parts: Array, outer: Rect2, inner: Rect2, top: Color, bottom: Color) -> void:
	var a:=contour(outer)
	var b:=contour(inner)
	for i in range(a.size()):
		var next: int=(i+1)%a.size()
		parts.append({"points":PackedVector2Array([a[i],a[next],b[next],b[i]]),"gradient":outer,"top":top,"bottom":bottom})

static func frame_mesh(rect: Rect2,tint: Color) -> ArrayMesh:
	# The old four opaque silhouettes shaded the entire board four times.
	# Only their visible regions are needed. Keep the exact original gradients.
	var key: Array=[rect,tint]
	if _frame_cache.has(key):return _frame_cache[key]
	var parts: Array=[]
	var shadow:=Rect2(rect.position+Vector2(0,5),rect.size)
	for polygon in Geometry2D.clip_polygons(contour(shadow),contour(rect)):
		parts.append({"points":polygon,"gradient":shadow,"top":Color("020709"),"bottom":Color("020405")})
	_ring(parts,rect,rect.grow(-2),Color("74998e").lerp(tint,0.2),Color("243c3d"))
	_ring(parts,rect.grow(-2),rect.grow(-6),Color("1d353b"),Color("071317"))
	parts.append({"points":contour(rect.grow(-6)),"gradient":rect.grow(-6),"top":Color("183239").lerp(tint,0.055),"bottom":Color("09171e")})
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for part in parts:
		var base:=vertices.size()
		for point in part.points:
			vertices.append(Vector3(point.x,point.y,0))
			colors.append(part.top.lerp(part.bottom,(point.y-part.gradient.position.y)/maxf(1,part.gradient.size.y)))
		for index in Geometry2D.triangulate_polygon(part.points):indices.append(base+index)
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if _frame_cache.size()>=FRAME_CACHE_LIMIT:_frame_cache.clear()
	_frame_cache[key]=mesh
	return mesh

static func frame(canvas: CanvasItem, rect: Rect2, tint: Color, ornamented: bool = false) -> void:
	if tint.a < 1.0 or minf(rect.size.x,rect.size.y)<=36:
		# Preserve compositing for translucent or unusually tiny callers.
		_surface(canvas,Rect2(rect.position+Vector2(0,5),rect.size),Color("020709"),Color("020405"))
		_surface(canvas,rect,Color("74998e").lerp(tint,0.2),Color("243c3d"))
		_surface(canvas,rect.grow(-2),Color("1d353b"),Color("071317"))
		_surface(canvas,rect.grow(-6),Color("183239").lerp(tint,0.055),Color("09171e"))
	else:canvas.draw_mesh(frame_mesh(rect,tint),null)
	var inner := rect.grow(-8)
	canvas.draw_line(inner.position+Vector2(12,0),Vector2(inner.end.x-12,inner.position.y),Color("82baa9"),1.0,true)
	canvas.draw_line(Vector2(inner.position.x+12,inner.end.y),inner.end-Vector2(12,0),Color("020b10"),2.0,true)
	if ornamented:
		for x in [rect.position.x+18,rect.end.x-18]:
			canvas.draw_line(Vector2(x,rect.position.y+3),Vector2(x,rect.position.y+17),GOLD,2,true)
			canvas.draw_line(Vector2(x,rect.end.y-17),Vector2(x,rect.end.y-3),GOLD.darkened(0.35),2,true)
		var mid := rect.get_center().x
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(mid-7,rect.position.y+3),Vector2(mid,rect.position.y-2),Vector2(mid+7,rect.position.y+3),Vector2(mid,rect.position.y+8)]),GOLD)

static func button(canvas: CanvasItem, rect: Rect2, tint: Color, state: String = "normal") -> void:
	var disabled := state == "disabled"
	var active := state in ["ready","selected"]
	var pressed := state == "pressed"
	var accent := Color("56676b") if disabled else tint
	_surface(canvas,Rect2(rect.position+Vector2(0,4),rect.size),Color("020a0d"),Color("020609"))
	_surface(canvas,rect,accent.lerp(Color("e8dbb8"),0.35 if active else 0.12),accent.darkened(0.68))
	var top := Color("34454b") if disabled else Color("23494d").lerp(accent,0.16 if active else 0.06)
	var bottom := Color("142026") if disabled else Color("0b252d")
	if pressed: top=bottom; bottom=Color("1e4145")
	_surface(canvas,rect.grow(-3),top,bottom)
	var inside := rect.grow(-6)
	_surface(canvas,Rect2(inside.position,Vector2(inside.size.x,minf(30,inside.size.y*0.34))),Color(0.77,1,0.91,0.09 if not pressed else 0.02),Color(0.7,1,0.9,0.0),7)
	canvas.draw_line(inside.position+Vector2(9,0),Vector2(inside.end.x-9,inside.position.y),accent.lightened(0.25) if active else Color("678d87"),1.0,true)
	canvas.draw_line(Vector2(inside.position.x+9,inside.end.y),inside.end-Vector2(9,0),Color("030e15"),2.0,true)
	if pressed:
		# A recessed groove and shortened corner rails identify depression.
		canvas.draw_polyline(contour(rect.grow(-7)),Color("06151c"),2,true)
		canvas.draw_line(rect.position+Vector2(14,10),rect.position+Vector2(32,10),accent,2,true)
	if active:
		for x in [rect.position.x+2,rect.end.x-2]:
			canvas.draw_line(Vector2(x,rect.get_center().y-10),Vector2(x,rect.get_center().y+10),LIGHT,2,true)

static func glyph(canvas: CanvasItem, center: Vector2, kind: String, tint: Color, size: float = 32) -> void:
	var r := size*0.5
	if kind == "reset":
		canvas.draw_arc(center,r*0.7,-PI*0.85,PI*0.65,24,tint,2.5,true)
		canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.85,-r*.8),center+Vector2(-r*.2,-r*.7),center+Vector2(-r*.7,-r*.2)]),tint)
	elif kind in ["sound","muted"]:
		canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.8,-r*.3),center+Vector2(-r*.4,-r*.3),center+Vector2(r*.05,-r*.7),center+Vector2(r*.05,r*.7),center+Vector2(-r*.4,r*.3),center+Vector2(-r*.8,r*.3)]),tint)
		if kind == "sound":
			for radius in [r*.45,r*.8]: canvas.draw_arc(center+Vector2(r*.15,0),radius,-.8,.8,12,tint,2,true)
		else: canvas.draw_line(center+Vector2(r*.3,-r*.45),center+Vector2(r*.9,r*.45),tint,2.5,true)
	elif kind == "brush":
		canvas.draw_line(center+Vector2(r*.65,-r*.7),center+Vector2(-r*.2,r*.2),tint,5,true)
		canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.2,0),center+Vector2(r*.1,r*.3),center+Vector2(-r*.8,r*.85),center+Vector2(-r*.6,r*.2)]),tint)

static func ready_sheen(canvas: CanvasItem, rect: Rect2, age: float) -> void:
	# Pure drawing: uses main's once-per-readiness clock, never input timing.
	if age < 0: return
	var inset := rect.grow(-8)
	if age <= 0.65:
		var progress := clampf(age/0.65,0,1)
		var x := lerpf(inset.position.x+16,inset.end.x-16,progress)
		var strength := sin(progress*PI)*0.17
		var left := maxf(inset.position.x+6,x-24)
		var right := minf(inset.end.x-6,x+24)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(left+8,inset.position.y+4),Vector2(right,inset.position.y+4),Vector2(right-8,inset.end.y-4),Vector2(left,inset.end.y-4)]),Color(0.78,1.0,0.9,strength))
	else:
		var glow := 0.07+0.025*sin((age-0.65)*TAU/3.2)
		canvas.draw_line(inset.position+Vector2(18,0),Vector2(inset.end.x-18,inset.position.y),Color(0.76,1,0.88,glow),2,true)

extends SceneTree
const SkinMaterial=preload("res://scripts/board_skin.gd")
const Reference=preload("res://tests/skin_quality_reference.gd")
var failures: Array=[]
var checks:=0
var comparisons: Array=[]

class FrameCanvas extends Node2D:
	var legacy:=false
	var rect:=Rect2(24,214,672,596)
	var tint:=Color("a2f4d6")
	func _draw() -> void:
		if legacy:Reference.frame(self,rect,tint,true)
		else:SkinMaterial.frame(self,rect,tint,true)

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:call_deferred("run")

func render(legacy: bool,rect: Rect2,tint: Color) -> Image:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(720,1080)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas:=FrameCanvas.new()
	canvas.legacy=legacy
	canvas.rect=rect
	canvas.tint=tint
	viewport.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	viewport.queue_free()
	return image

func run() -> void:
	var material=SkinMaterial.new()
	check(material.has_method("frame_mesh"),"opaque frame has cached non-overlapping mesh")
	if not failures.is_empty():finish();return
	for item in [[Rect2(24,214,672,596),Color("a2f4d6")],[Rect2(27,839,136,118),Color("cdb583")],[Rect2(26,200,668,644),Color("a2f4d6")]]:
		var rect: Rect2=item[0]
		var tint: Color=item[1]
		var mesh: Mesh=material.call("frame_mesh",rect,tint)
		check(mesh==material.call("frame_mesh",rect,tint),"same frame reuses geometry")
		var arrays:=mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var area:=0.0
		for i in range(0,indices.size(),3):
			var a:=Vector2(vertices[indices[i]].x,vertices[indices[i]].y)
			var b:=Vector2(vertices[indices[i+1]].x,vertices[indices[i+1]].y)
			var c:=Vector2(vertices[indices[i+2]].x,vertices[indices[i+2]].y)
			area+=absf((b-a).cross(c-a))*0.5
		check(area<=rect.size.x*(rect.size.y+5.0)+0.1,"opaque fill area is at most one silhouette")
		var old: Image=await render(true,rect,tint)
		var current: Image=await render(false,rect,tint)
		var a:=old.get_data()
		var b:=current.get_data()
		var changed:=0
		var largest:=0
		for i in range(a.size()):
			var difference:=absi(int(a[i])-int(b[i]))
			if difference>0:changed+=1
			largest=maxi(largest,difference)
		# One channel quantization unit is permitted for equivalent interpolation.
		check(largest<=1,"pixel equivalence max channel error<=1; changed=%d max=%d"%[changed,largest])
		comparisons.append({"rect":str(rect),"tint":str(tint),"changed_channels":changed,"largest_channel_error":largest,"opaque_triangle_area":area,"silhouette_bound":rect.size.x*(rect.size.y+5.0)})
	finish()

func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures,"comparisons":comparisons}))
	quit(0 if failures.is_empty() else 1)

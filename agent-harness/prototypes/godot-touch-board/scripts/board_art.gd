extends RefCounted
const PanelView = preload("res://scripts/board_panel_view.gd")
const HERO_TEXTURE = preload("res://assets/alchemist-portrait-v1.png")
const TARGET_TEXTURE = preload("res://assets/training-jelly-golem-v1.png")
const DRAGON_TEXTURE = preload("res://assets/premium/amethyst-dragon-arena-v1.png")
const SKILL_TEXTURE = preload("res://assets/premium/skill-button-amethyst-base-v1.png")
## Original approved atlas panels with immediate-mode selection/character art.
## Opaque panel bodies match the circular contact envelope.

const PALETTE = [Color("ff4038"), Color("6ee82e"), Color("ffd13d"), Color("33b8ff"), Color("ff65b4")]
const ATLAS = preload("res://assets/pigment-atlas.png")
# Authorized original generated atlas; exact parent-provided source regions.
const REGIONS = [Rect2(37,36,360,360), Rect2(446,35,360,360), Rect2(854,36,361,359), Rect2(36,438,368,369), Rect2(446,438,366,369), Rect2(855,438,368,369), Rect2(36,827,384,382)]
# Alpha >= 220 body bounds, relative to regions. Transparent margins do not
# shrink visible contact bodies: these bounds are mapped to collision diameter.
const BODY_BOUNDS = [Rect2(5,5,350,350), Rect2(4,5,352,350), Rect2(5,4,351,351), Rect2(5,4,358,361), Rect2(4,4,357,361), Rect2(5,4,358,361), Rect2(5,4,375,374)]
const INK = Color("101527")

static func _poly(canvas: CanvasItem, points: Array, color: Color, center: Vector2, scale_value: float = 1.0) -> void:
	var p := PackedVector2Array()
	for v in points:
		p.append(center + v * scale_value)
	canvas.draw_colored_polygon(p, color)

static func _ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	canvas.draw_arc(center, radius, 0, TAU, 64, color, width, true)

static func _ellipse(canvas: CanvasItem, center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		var angle := TAU * i / 48.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	canvas.draw_colored_polygon(points, color)

static func _star(canvas: CanvasItem, center: Vector2, radius: float, color: Color, points: int = 4, rotation: float = 0.0) -> void:
	var shape := PackedVector2Array()
	for i in range(points * 2):
		var angle := rotation - PI / 2.0 + TAU * i / (points * 2.0)
		shape.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 if i % 2 == 0 else 0.32))
	canvas.draw_colored_polygon(shape, color)

static func _heart_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(64):
		var t := TAU * i / 64.0
		var x := 16 * pow(sin(t), 3)
		var y := -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
		points.append(center + Vector2(x, y) * radius / 18.0)
	return points

static func _glyph(canvas: CanvasItem, center: Vector2, size: float, color_index: int, color: Color) -> void:
	match color_index:
		0: # Ember / curved rising flame.
			_poly(canvas, [Vector2(0,-1),Vector2(0.27,-0.38),Vector2(0.67,-0.53),Vector2(0.59,0.44),Vector2(0.17,0.82),Vector2(-0.48,0.65),Vector2(-0.70,0.17),Vector2(-0.28,-0.38),Vector2(-0.25,0.10)], color, center, size)
		1: # Leaf, matching the green atlas panel.
			_poly(canvas, [Vector2(-0.65,0.65),Vector2(-0.55,-0.25),Vector2(0.35,-0.6),Vector2(0.85,-1),Vector2(0.65,0.15),Vector2(-0.2,0.7)], color, center, size)
		2: # Spark / angular bolt.
			_poly(canvas, [Vector2(0.20,-1),Vector2(-0.68,0.18),Vector2(-0.06,0.18),Vector2(-0.22,1),Vector2(0.72,-0.22),Vector2(0.11,-0.22)], color, center, size)
		3: # Tide / droplet, matching the blue atlas panel.
			_poly(canvas, [Vector2(0,-1),Vector2(0.65,-0.05),Vector2(0.61,0.48),Vector2(0,0.88),Vector2(-0.61,0.48),Vector2(-0.65,-0.05)], color, center, size)
		_: canvas.draw_colored_polygon(_heart_points(center, size), color)

static func draw_panel(canvas: CanvasItem, panel: Dictionary, time: float, emphasis: String = "", scale_factor: float = 1.0) -> void:
	var center: Vector2 = panel.pos
	var radius: float = panel.get("radius", 35.0) * scale_factor
	var color_index := clampi(int(panel.get("color", 0)), 0, 4)
	var base: Color = PALETTE[color_index]
	var kind: String = panel.get("kind", "normal")
	var core := kind == "core" or kind == "strong"
	var index := color_index
	if kind == "heart": index = 4
	elif kind == "core": index = 5
	elif kind == "strong": index = 6
	if kind in ["bomb","big_bomb"]:
		draw_bomb(canvas,center,radius,kind=="big_bomb",emphasis,color_index)
		return
	var region: Rect2 = REGIONS[index]
	var body: Rect2 = BODY_BOUNDS[index]
	var texture_scale := Vector2(radius * 2.0 / body.size.x, radius * 2.0 / body.size.y)
	var destination := Rect2(center - (body.position + body.size * 0.5) * texture_scale, region.size * texture_scale)
	canvas.draw_texture_rect_region(ATLAS, destination, region)
	if core:
		# Purple/rainbow core artwork remains unchanged. Colored collar plus a
		# matching element glyph identifies its logical attribute redundantly.
		_ring(canvas, center, radius*0.925, INK, maxf(4.0,radius*0.14))
		_ring(canvas, center, radius*0.925, base, maxf(2.0,radius*0.075))
		var badge := center + Vector2(0,radius*0.58)
		canvas.draw_circle(badge, radius*0.23, INK)
		_ring(canvas, badge, radius*0.23, base, maxf(1.0,radius*0.035))
		_glyph(canvas, badge, radius*0.17, color_index, base.lightened(0.48))
	# All selection marks remain inset inside the true circular body envelope.
	match emphasis:
		"direct":
			_ring(canvas, center, radius*0.95, Color("fffef7"), maxf(2.2,radius*0.07))
		"chain":
			for i in range(8):
				canvas.draw_arc(center, radius*0.95, i*TAU/8+0.05, (i+1)*TAU/8-0.20, 8, Color("ffe99d"), maxf(2.2,radius*0.06), true)
		"convert":
			for i in range(4):
				var a := i*PI/2 + time*0.5
				canvas.draw_arc(center, radius*0.95, a, a+PI/3, 12, Color("bfffe6"), maxf(2.2,radius*0.065), true)
			_star(canvas, center+Vector2(radius*0.54,radius*0.52), radius*0.20, Color("e4fff1"))

static func draw_bomb(canvas:CanvasItem,center:Vector2,radius:float,large:bool,emphasis:String="",color_index:int=0)->void:
	var visible:float=PanelView.visual_radius({"radius":radius,"kind":"big_bomb" if large else "bomb"})
	# Flat, original technical disc. All ink stays in the existing physical
	# envelope; rendering consumes no RNG and never edits panel/game state.
	var base:Color=PALETTE[clampi(color_index,0,3)]
	var rim:Color=base.lightened(.38)
	canvas.draw_circle(center,visible*.91,base.darkened(.12))
	_ring(canvas,center,visible*.89,rim,visible*.04)
	# Short rectangular connector, within the unchanged circular hit hull.
	var tab:=PackedVector2Array()
	for v in [Vector2(.79,-.27),Vector2(.96,-.27),Vector2(.96,.27),Vector2(.79,.27)]:
		tab.append(center+v*visible)
	canvas.draw_colored_polygon(tab,rim)
	# Fine translucent circuit lines, no spherical shading or specular gloss.
	for i in range(5):
		var x:float=(-.64+i*.11)*visible
		canvas.draw_line(center+Vector2(x,-visible*.57),center+Vector2(x,visible*.53),Color(1,1,1,.12),.65,true)
	canvas.draw_arc(center,visible*.84,.15,2.8,40,Color(1,1,1,.18),.75,true)
	_star(canvas,center+Vector2(-.43,-.13)*visible,visible*.23,Color.WHITE,10)
	var font:Font=ThemeDB.fallback_font
	var label_size:int=maxi(8,roundi(visible*.29))
	canvas.draw_string(font,center+Vector2(-.15,-.015)*visible,"BOMB",HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,Color.WHITE)
	# Technical label rules deliberately avoid unreadable imitation microtext.
	for i in range(3):
		var y:float=(.16+i*.10)*visible
		canvas.draw_line(center+Vector2(-visible*.61,y),center+Vector2(visible*(.56-i*.08),y),Color(1,1,1,.82),maxf(.7,visible*.022),true)
	_glyph(canvas,center+Vector2(.10,.66)*visible,visible*.13,color_index,Color(1,1,1,.9))
	if emphasis=="direct":
		_ring(canvas,center,visible*.94,Color("fffef7"),2.8)
	elif emphasis=="chain":
		for i in range(8):
			canvas.draw_arc(center,visible*.94,i*TAU/8+.05,(i+1)*TAU/8-.20,8,Color("ffe99d"),2.8,true)

static func draw_hero(canvas: CanvasItem, center: Vector2, time: float, active: bool) -> void:
	# Face-led portrait crops within the supplied original, not a new character.
	var portrait := Rect2(center-Vector2(65,56),Vector2(130,112))
	canvas.draw_rect(portrait,Color("1e343b"))
	canvas.draw_texture_rect_region(HERO_TEXTURE,portrait,Rect2(130,0,780,672))
	canvas.draw_rect(portrait,Color("c4b68a") if not active else Color("bffff0"),false,2.0)
	if active:
		for i in range(3):
			canvas.draw_rect(portrait.grow(3+i*3),Color(0.45,1.0,0.85,0.18/(i+1)),false,2.0)

static func draw_target(canvas: CanvasItem, center: Vector2, time: float, hit: float) -> void:
	# Crop transparent margins only; preserve the original silhouette/aspect.
	var offset := Vector2(sin(time*39)*hit*4, -hit*3)
	var size := Vector2(1131.0/974.0*166.0,166.0)
	var rect := Rect2(center-size*0.5+offset,size)
	canvas.draw_texture_rect_region(TARGET_TEXTURE,rect,Rect2(68,136,1131,974),Color.WHITE.lerp(Color("fff2d0"),hit*0.35))
	if hit>0.05:
		for i in range(5):
			var a := i*TAU/5+time
			_star(canvas,center+Vector2(cos(a)*97,sin(a)*69),4*hit,Color("fff0bb"))

static func stage_variant(encounter: int) -> String:
	return "dragon" if encounter==2 else "training"

static func impact_point(encounter:int)->Vector2:
	return Vector2(548,162) if encounter==2 else Vector2(360,185)

static var _dragon_hit_mesh:ArrayMesh=ArrayMesh.new()
static var _dragon_mesh_arrays:Array=[]
static var _dragon_mesh_rect:=Rect2()
static func _draw_dragon_hit(canvas:CanvasItem,rect:Rect2,source:Rect2,offset:Vector2,flash:float)->void:
	# A small illustrated head/neck region reacts; the surrounding arena stays
	# fixed. This is a bounded91-vertex texture deformation, not rigged wing art.
	if _dragon_mesh_arrays.is_empty() or _dragon_mesh_rect!=rect:
		_dragon_mesh_rect=rect
		var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
		for y in range(7):
			for x in range(13):
				var f:=Vector2(x/12.0,y/6.0)
				var position:=rect.position+rect.size*f
				vertices.append(Vector3(position.x,position.y,0))
				uv.append((source.position+source.size*f)/Vector2(DRAGON_TEXTURE.get_size()))
		for y in range(6):
			for x in range(12):
				var i:=y*13+x
				indices.append_array(PackedInt32Array([i,i+1,i+13,i+1,i+14,i+13]))
		_dragon_mesh_arrays.resize(Mesh.ARRAY_MAX)
		_dragon_mesh_arrays[Mesh.ARRAY_VERTEX]=vertices
		_dragon_mesh_arrays[Mesh.ARRAY_TEX_UV]=uv
		_dragon_mesh_arrays[Mesh.ARRAY_INDEX]=indices
	var arrays:=_dragon_mesh_arrays.duplicate()
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
	var colors:=PackedColorArray()
	for i in range(vertices.size()):
		var p:=Vector2(vertices[i].x,vertices[i].y)
		var mask:=1.0-smoothstep(35.0,145.0,p.distance_to(impact_point(2)))
		vertices[i]+=Vector3(offset.x,offset.y,0)*mask
		colors.append(Color(1+flash*mask*0.85,1+flash*mask*0.5,1+flash*mask*0.7,1))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	_dragon_hit_mesh.clear_surfaces()
	_dragon_hit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	canvas.draw_mesh(_dragon_hit_mesh,DRAGON_TEXTURE)

static func draw_battle_stage(view,canvas: CanvasItem,rect: Rect2) -> void:
	var encounter: int=-1 if view.sandbox else view.session.combat.encounter
	if stage_variant(encounter)=="dragon":
		# Wide portrait crop of the original illustration; no fabricated wing motion.
		var source_height:=1536.0*rect.size.y/rect.size.x
		var source:=Rect2(0,60,1536,source_height)
		if view.quality_fx.impact_remaining>0 and not view.reduced_effects:
			_draw_dragon_hit(canvas,rect,source,view.quality_fx.stage_offset(),view.quality_fx.hit_flash())
		else:canvas.draw_texture_rect_region(DRAGON_TEXTURE,rect,source)
	else:
		var points:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		canvas.draw_polygon(points,PackedColorArray([Color("20122f"),Color("291638"),Color("0b0912"),Color("0b0912")]))
		var center:=rect.get_center()+Vector2(0,110)
		_ellipse(canvas,center,Vector2(235,40),Color("17111e"))
		for ring in range(2):
			var ellipse:=PackedVector2Array()
			for i in range(49):
				var angle:=TAU*i/48.0
				ellipse.append(center+Vector2(cos(angle)*(218-ring*28),sin(angle)*(33-ring*6)))
			canvas.draw_polyline(ellipse,Color(0.62,0.39,0.73,0.24),1.2,true)
		# Same original early enemy, substantially larger than the old HUD thumbnail.
		var height:=235.0
		var size:=Vector2(1131.0/974.0*height,height)
		var offset:Vector2=view.quality_fx.stage_offset()
		var dest:=Rect2(Vector2(360,185)-size*0.5+offset,size)
		canvas.draw_texture_rect_region(TARGET_TEXTURE,dest,Rect2(68,136,1131,974),Color(1+view.quality_fx.hit_flash()*0.7,1+view.quality_fx.hit_flash()*0.5,1+view.quality_fx.hit_flash()*0.5))

static func draw_premium_hero(canvas: CanvasItem,rect: Rect2,_time: float,active: bool) -> void:
	# Explicit temporary original portrait: violet portrait's official download
	# failed twice. Preserve face colors; never represent this as the new asset.
	canvas.draw_texture_rect_region(HERO_TEXTURE,rect,Rect2(130,0,780,694))
	canvas.draw_rect(rect,Color("d5b377"),false,1.5)
	if active:canvas.draw_rect(rect.grow(2),Color(0.82,0.55,1.0,0.5),false,2)

static func skill_button_rect(control: Rect2) -> Rect2:
	var ratio:=minf(control.size.x/1983.0,control.size.y/793.0)
	var size:=Vector2(1983,793)*ratio
	return Rect2(control.get_center()-size*0.5,size)

static func skill_illumination(available: bool,age: float) -> float:
	return 0.34+0.025*sin(maxf(0,age)*TAU/3.2) if available else 0.0

static func draw_skill_button(canvas: CanvasItem,rect: Rect2,illuminated: bool,age: float) -> void:
	var fitted:=skill_button_rect(rect)
	canvas.draw_texture_rect(SKILL_TEXTURE,fitted,false,Color.WHITE if illuminated else Color(0.62,0.60,0.67,1))
	var light:=skill_illumination(illuminated,age)
	if light<=0:return
	# Local light stays inside the gemstone's dark inset; gold geometry and the
	# original transparent padding remain identical in both gameplay states.
	var center:=fitted.get_center()
	_ellipse(canvas,center,Vector2(fitted.size.x*0.37,fitted.size.y*0.23),Color(0.47,0.08,0.95,light))
	_ellipse(canvas,center,Vector2(fitted.size.x*0.30,fitted.size.y*0.16),Color(0.68,0.21,1.0,light*0.28))

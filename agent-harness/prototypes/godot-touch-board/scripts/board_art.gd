extends RefCounted
const HERO_TEXTURE = preload("res://assets/alchemist-portrait-v1.png")
const TARGET_TEXTURE = preload("res://assets/training-jelly-golem-v1.png")
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

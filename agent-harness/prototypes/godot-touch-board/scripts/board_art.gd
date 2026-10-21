extends RefCounted
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
	# Original little pigment alchemist, limited to about 90 x 96 pixels.
	var glow := 0.12 + 0.05*sin(time*2)
	if active:
		for i in range(4):
			_ring(canvas, center, 44+i*4, Color(0.40,1.0,0.86,glow*(1-i/4.0)), 2)
	_ellipse(canvas, center+Vector2(0,35), Vector2(34,9), Color(0,0,0,0.4))
	_poly(canvas, [Vector2(-25,30),Vector2(-18,2),Vector2(0,-9),Vector2(20,3),Vector2(28,31),Vector2(0,39)], Color("243b54"), center)
	_poly(canvas, [Vector2(-16,7),Vector2(0,14),Vector2(16,5),Vector2(13,32),Vector2(-13,32)], Color("67e0c0"), center)
	_poly(canvas, [Vector2(-15,9),Vector2(-3,16),Vector2(-10,25),Vector2(-21,4)], Color("d3fff0"), center)
	_poly(canvas, [Vector2(14,8),Vector2(3,16),Vector2(10,25),Vector2(21,5)], Color("a9f5e1"), center)
	canvas.draw_circle(center+Vector2(0,-13),22,Color("493659"))
	_ellipse(canvas,center+Vector2(1,-9),Vector2(16,19),Color("f5c6a1"))
	_poly(canvas,[Vector2(-20,-15),Vector2(-14,-35),Vector2(4,-39),Vector2(21,-24),Vector2(17,-8),Vector2(5,-24),Vector2(-3,-15),Vector2(-6,-26)],Color("edebfa"),center)
	_poly(canvas,[Vector2(-17,-26),Vector2(-9,-42),Vector2(11,-41),Vector2(23,-26),Vector2(15,-18),Vector2(-6,-23)],Color("33475c"),center)
	canvas.draw_arc(center+Vector2(0,-26),19,PI*1.0,PI*1.9,16,Color("94f2d3"),3,true)
	canvas.draw_circle(center+Vector2(-5,-9),1.9,Color("26344e"))
	canvas.draw_circle(center+Vector2(8,-9),1.9,Color("26344e"))
	canvas.draw_arc(center+Vector2(2,-3),5,0.3,2.5,12,Color("b37771"),1.3,true)
	canvas.draw_line(center+Vector2(23,20),center+Vector2(37,-13),Color("dab572"),5,true)
	_poly(canvas,[Vector2(32,-12),Vector2(36,-25),Vector2(43,-25),Vector2(42,-11),Vector2(36,-8)],Color("69ebd0"),center)
	canvas.draw_circle(center+Vector2(27,13),6,Color("f5c6a1"))
	for i in range(3):
		canvas.draw_circle(center+Vector2(-10+i*10,27),2.7,PALETTE[i])

static func draw_target(canvas: CanvasItem, center: Vector2, time: float, hit: float) -> void:
	# Passive lacquered training construct, no attack animation.
	var p := center + Vector2(sin(time*1.7)*2, sin(time*2.2)*3)
	var metal := Color("586a83").lerp(Color("fff1d6"),clampf(hit,0,1))
	_ellipse(canvas,center+Vector2(0,42),Vector2(34,7),Color(0,0,0,0.3))
	_poly(canvas,[Vector2(-29,3),Vector2(-23,-23),Vector2(0,-34),Vector2(23,-23),Vector2(29,3),Vector2(20,27),Vector2(0,36),Vector2(-20,27)],Color("273244"),p)
	_poly(canvas,[Vector2(-23,-2),Vector2(-18,-20),Vector2(0,-28),Vector2(18,-20),Vector2(23,-2),Vector2(17,21),Vector2(0,29),Vector2(-17,21)],metal,p)
	_poly(canvas,[Vector2(-18,-20),Vector2(0,-28),Vector2(18,-20),Vector2(0,-13)],Color("8b9db3").lerp(Color.WHITE,hit),p)
	_poly(canvas,[Vector2(0,-13),Vector2(18,-20),Vector2(23,-2),Vector2(17,21),Vector2(0,29)],Color("38485f").lerp(Color("ffe9b5"),hit),p)
	canvas.draw_circle(p+Vector2(0,2),14,Color("121c2e"))
	_ring(canvas,p+Vector2(0,2),12,Color("9be8dc"),2)
	_star(canvas,p+Vector2(0,2),8,Color("d0fff0"))
	for side in [-1,1]:
		_poly(canvas,[Vector2(side*29,-5),Vector2(side*40,0),Vector2(side*38,17),Vector2(side*30,23)],metal.darkened(0.18),p)
		canvas.draw_line(p+Vector2(side*18,23),p+Vector2(side*12,32),Color("a2b9ce"),2,true)
	if hit>0.05:
		for i in range(6):
			var a := i*TAU/6+time
			_star(canvas,p+Vector2(cos(a),sin(a))*(38+16*(1-hit)),4*hit,Color("fff0bb"))

extends SceneTree
## Pure coordinate tests using the current initial-board geometry and real input
## planner. This is neither a render nor performance/physics experiment.
const Layout = preload("res://scripts/board_layout.gd")
const Motion = preload("res://scripts/board_motion.gd")
const Rules = preload("res://scripts/board_rules.gd")
const Session = preload("res://scripts/board_session.gd")
var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)

func approx(a: Vector2,b: Vector2) -> bool:
	return a.distance_to(b)<0.001

func _init() -> void:
	var logical:=Rect2(30,290,660,530)
	var shifted:=Rect2(30,250,660,530)
	check(Layout.board_scale(logical,shifted)==Vector2.ONE,"shift keeps circles at original scale")
	check(Layout.board_to_screen(Vector2(360,555),logical,shifted)==Vector2(360,515),"same-size display shifts current point by board offset")
	check(Layout.screen_to_board(Vector2(360,515),logical,shifted)==Vector2(360,555),"shifted pointer inverse reaches original logical position")
	var half:=Rect2(15,125,330,265)
	check(Layout.board_scale(logical,half)==Vector2(0.5,0.5),"720 to360 uniform scale")
	check(Layout.board_to_screen(logical.position,logical,half)==half.position,"half-size logical origin maps to display origin")
	check(Layout.board_to_screen(logical.end,logical,half)==half.end,"half-size complete board maps without clipping")
	var tall:=Rect2(15,125,330,330)
	check(Layout.board_scale(logical,tall)==Vector2(0.5,0.5),"aspect mismatch uses uniform fit rather than stretching circles")
	check(approx(Layout.board_to_screen(logical.get_center(),logical,tall),tall.get_center()),"uniform fit centers unused vertical space")
	check(approx(Layout.board_to_screen(logical.position,logical,tall),Vector2(15,157.5)),"letterbox origin preserves entire board")
	check(Layout.screen_to_board(Vector2(10,140),logical,tall).x<logical.position.x,"outside pointer is never clamped into board")
	var original_rng:=RandomNumberGenerator.new()
	original_rng.seed=20261021
	var packed:=Motion.initial_board(logical,48,1,original_rng)
	var panels: Array=packed.panels
	var before:=panels.duplicate(true)
	var original_state: int=original_rng.state
	var natural_graph:=Rules.contact_graph(panels)
	check(panels.size()==48,"fixture uses all48 current initial-board bodies")
	var session=Session.new()
	session.bounds=logical
	session.panels=panels
	var displays: Array=[shifted,half,Rect2(16.25,135.416667,357.5,287.083333),tall]
	for display in displays:
		var scale: Vector2=Layout.board_scale(logical,display)
		check(is_equal_approx(scale.x,scale.y),"uniform display scale %s" % display)
		var drawn: Array=[]
		for panel in panels:
			var rendered: Dictionary=panel.duplicate(true)
			rendered.pos=Layout.board_to_screen(panel.pos,logical,display)
			rendered.radius=float(panel.radius)*scale.x
			drawn.append(rendered)
			var center: Vector2=Layout.screen_to_board(rendered.pos,logical,display)
			check(approx(center,panel.pos),"center roundtrip id%d display%s" % [panel.id,display.size])
			var bounds:=Rect2(rendered.pos-Vector2.ONE*rendered.radius,Vector2.ONE*rendered.radius*2.0)
			check(display.grow(0.001).encloses(bounds),"full circle stays visible id%d display%s" % [panel.id,display.size])
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				var edge: Vector2=panel.pos+direction*panel.radius
				check(approx(Layout.screen_to_board(Layout.board_to_screen(edge,logical,display),logical,display),edge),"exact silhouette-edge roundtrip id%d direction%s" % [panel.id,direction])
			# Floating boundary equality is not an input-policy change. Use a tiny
			# 0.01px inward margin for real hit tests, exact edge tested above.
			for offset in [Vector2.ZERO,Vector2.LEFT*(panel.radius-0.01),Vector2.RIGHT*(panel.radius-0.01),Vector2.UP*(panel.radius-0.01),Vector2.DOWN*(panel.radius-0.01)]:
				var point: Vector2=panel.pos+offset
				var original_hit: bool=session.begin(point,0)
				var expected: Dictionary=session.selection.duplicate(true)
				session.cancel()
				var transformed: Vector2=Layout.screen_to_board(Layout.board_to_screen(point,logical,display),logical,display)
				var mapped_hit: bool=session.begin(transformed,0)
				check(original_hit and mapped_hit and session.selection==expected,"real session hit/plan unchanged id%d offset%s display%s" % [panel.id,offset,display.size])
				if expected.get("valid",false):
					check(session.selection.direct[0]==panel.id,"same touched panel ID after inverse mapping")
				session.cancel()
		check(Rules.contact_graph(drawn,1.5*scale.x)==natural_graph,"uniform drawn geometry preserves all natural contact edges")
		var outside: Vector2=Layout.board_to_screen(logical.position-Vector2(5,5),logical,display)
		check(not session.begin(Layout.screen_to_board(outside,logical,display),0),"outside mapped input cannot select a panel")
	check(panels==before and session.panels==before,"mapping never moves or clips canonical physics panels")
	check(original_rng.state==original_state,"layout mapping consumes no gameplay RNG")
	print("PREMIUM LAYOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

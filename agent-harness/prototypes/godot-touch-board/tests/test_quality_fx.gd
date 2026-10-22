extends SceneTree
const FX = preload("res://scripts/board_quality_fx.gd")
var checks := 0
var failures := 0

class DrawProbe extends RefCounted:
	var calls := 0
	var text: Array = []
	var textures: Array = []
	func draw_colored_polygon(_points, _color): calls += 1
	func draw_line(_a,_b,_color,_width=1.0,_aa=false): calls += 1
	func draw_circle(_center,_radius,_color): calls += 1
	func draw_arc(_center,_radius,_from,_to,_points,_color,_width=1.0,_aa=false):calls+=1
	func draw_texture_rect_region(texture,dest,source,_modulate=Color.WHITE,_transpose=false,_clip=true):
		calls += 1
		textures.append({"texture":texture,"dest":dest,"source":source})
	func draw_string(_font,_pos,value,_align=HORIZONTAL_ALIGNMENT_LEFT,_width=-1,_size=16,_color=Color.WHITE):
		calls += 1
		text.append(value)
	func draw_string_outline(_font,_pos,_value,_align=HORIZONTAL_ALIGNMENT_LEFT,_width=-1,_size=16,_outline=1,_color=Color.WHITE): calls += 1

class ViewProbe extends RefCounted:
	const UI = preload("res://scripts/board_ui.gd")
	var font: Font = ThemeDB.fallback_font
	var font_body: Font = ThemeDB.fallback_font
	var font_display: Font = ThemeDB.fallback_font
	var phase := "ready"
	var actions := 7
	func board_to_screen(pos:Vector2)->Vector2: return pos-Vector2(0,40)

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)

func _init() -> void:
	var f = FX.new()
	var source: Array=[{"id":1,"kind":"normal"},{"id":2,"kind":"heart"},{"id":3,"kind":"core"},{"id":4,"kind":"normal"}]
	var plan: Dictionary={"valid":true,"mode":"clear","removed":[1,2,3,3,404],"damage":7,"base_damage":5,"weak_bonus":2,"heal_raw":6,"heal_effective":2,"heal_overflow":4}
	var original:=plan.duplicate(true)
	var original_source:=source.duplicate(true)
	f.action_started(plan,source)
	check(f.damage_amount==7 and f.heal_raw==6 and f.heal_effective==2 and f.heal_overflow==4,"totals copy exact committed damage and healing breakdown")
	check(f.total_remaining==0.0,"starting action does not prematurely show final total")
	check(f.panel_removed(1,Vector2(100,400),Color.RED,"normal"),"eligible normal event accepted")
	check(f.trails.size()==1 and f.trails[0].get("kind")=="collect","normal emits collection-bound energy trail")
	check(not f.panel_removed(1,Vector2.ZERO,Color.RED,"normal") and f.trails.size()==1,"duplicate ID cannot duplicate trail")
	check(not f.panel_removed(4,Vector2.ZERO,Color.RED,"normal") and not f.panel_removed(404,Vector2.ZERO,Color.RED,"normal"),"surviving and missing panel IDs cannot emit")
	check(f.panel_removed(2,Vector2(120,400),Color.PINK,"heart") and f.trails.size()==2 and f.trails[1].get("kind")=="heal","heart emits hero-bound healing trail")
	check(f.panel_removed(3,Vector2(140,400),Color.CYAN,"core") and f.trails.size()==3 and f.trails.back().core,"core delivers energy without duplicating existing core bursts")
	f.action_finished()
	check(f.total_remaining==FX.TOTAL_SECONDS,"finished action shows one canonical total")
	f.update(0.2)
	var remaining: float=f.total_remaining
	f.action_finished()
	check(f.total_remaining==remaining,"duplicate finish cannot restart number lifetime")
	check(not f.panel_removed(1,Vector2.ZERO,Color.RED,"normal"),"late event cannot restart finished action")
	check(plan==original and source==original_source,"visual module never mutates canonical plan or panels")
	var view=ViewProbe.new()
	var canvas=DrawProbe.new()
	f.draw_overlay(view,canvas)
	check("7" not in canvas.text and "회복 +2 · 초과 4 (전체 6)" in canvas.text,"clear shows exact heal total without premature enemy damage")
	check(f.take_impact().is_empty(),"clear cannot trigger enemy hit")
	f.release_bank(plan,3,24);f.update(FX.BANK_WINDUP)
	canvas=DrawProbe.new();f.draw_overlay(view,canvas)
	check("7" in canvas.text and f.take_impact().damage==7,"bank displays and emits exact committed total once")
	check(view.phase=="ready" and view.actions==7,"drawing leaves readiness and actions unchanged")
	f.update(2.0)
	check(f.total_remaining==0 and f.trails.is_empty(),"all clear effects expire without finish callbacks or input locks")
	f.skill_activated()
	check(f.cutin_remaining==0.5,"successful skill activation starts exactly half-second cutin")
	canvas=DrawProbe.new()
	f.draw_overlay(view,canvas)
	check(canvas.calls>0 and preload("res://scripts/board_characters.gd").definition("rio").skill in canvas.text,"cutin draws skill identity synchronously")
	check(canvas.textures.is_empty(),"cutin keeps pixel hero visible without restoring old portrait")
	check(is_equal_approx(FX.FACE_REGION.size.x/FX.FACE_REGION.size.y,230.0/160.0),"cutin crop preserves the original face aspect")
	check(FX.CUTIN_RECT.position.y>=view.UI.BOARD_SCREEN.end.y and FX.CUTIN_RECT.end.y<=1080,"cutin remains outside board and upper color targeting palette")
	check(FX.HEAL_STRIP.end.y<=view.UI.BOARD_SCREEN.position.y,"heal result stays above the playable board")
	f.update(0.49)
	check(f.cutin_remaining>0,"cutin remains active until half second")
	f.update(0.02)
	check(f.cutin_remaining==0,"cutin ends independently at half second")
	f.skill_activated()
	f.update(-1)
	check(f.cutin_remaining==0.5,"negative delta cannot extend or rewind lifetime")
	f.skill_activated()
	check(f.cutin_remaining==0.5,"another activation replaces one cutin without stacking durations")
	f.reset()
	check(f.cutin_remaining==0 and f.total_remaining==0 and f.trails.is_empty() and f.damage_amount==0 and f.heal_raw==0,"reset clears totals cutin and trails")
	f.action_finished()
	check(f.total_remaining==0 and not f.panel_removed(1,Vector2.ZERO,Color.RED,"normal"),"reset prevents stale finish or old panel from resurrecting effects")
	f.action_started({"valid":true,"mode":"skill","removed":[1],"damage":99},source)
	check(f.damage_amount==0 and not f.panel_removed(1,Vector2.ZERO,Color.RED,"normal"),"skill is not treated as damaging clear")
	f.action_started({"valid":false,"removed":[1],"damage":99},source)
	check(f.damage_amount==0 and not f.panel_removed(1,Vector2.ZERO,Color.RED,"normal"),"invalid plan cannot start effects")
	var many: Array=[]
	var ids: Array=[]
	for id in range(200):
		many.append({"id":id,"kind":"normal"})
		ids.append(id)
	seed(888)
	var expected_global:=randf()
	seed(888)
	f.action_started({"valid":true,"removed":ids,"damage":300,"heal_raw":0,"heal_effective":0,"heal_overflow":0},many)
	for id in ids: f.panel_removed(id,Vector2(id,400),Color.CYAN,"normal")
	check(f.trails.size()<=FX.TRAIL_LIMIT and f.damage_amount==300,"effect budget cannot distort canonical total")
	check(randf()==expected_global,"effects leave global gameplay randomness untouched")
	f.action_finished()
	f.update(5.0)
	check(f.trails.is_empty() and f.total_remaining==0,"large effect batches remain bounded and expire")
	print("QUALITY FX checks=",checks," failures=",failures)
	quit(1 if failures else 0)

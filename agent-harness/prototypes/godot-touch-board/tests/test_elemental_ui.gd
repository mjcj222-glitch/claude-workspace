extends SceneTree
## Contract text/space checks; OS rendering/input is verified separately.
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var ui=load("res://scripts/board_ui.gd")
	var names:Array=[]
	for method in ui.get_script_method_list():names.append(method.name)
	check("damage_line" in names and "intent_lines" in names and "preview_effect_line" in names,"UI exposes canonical damage and wrapped intent text")
	if failures:quit(1);return
	check(ui.damage_line({"damage":7,"base_damage":5,"weak_bonus":2})=="피해 7 = 기본 5 + 약점 2","damage copy distinguishes exact base and aggregate bonus")
	var slam:Dictionary={"intent":"slam","incoming_damage":10,"mitigation_success":false}
	var lines:Array=ui.intent_lines(slam)
	check(lines==["강타 10 → 4: 한 번에 약점 2개","또는 공격 패널 8개 소거"],"active slam exact copy wraps into two readable lines")
	var success:Array=ui.intent_lines({"intent":"slam","incoming_damage":4,"mitigation_success":true})
	check(success[0]=="강타 약화 · 피해4","latched slam copy shows actual four damage")
	var fallback:Array=ui.intent_lines({"intent":"plain","incoming_damage":6,"mitigation_success":false})
	check("6" in fallback[0] and "강타" not in " ".join(fallback),"fallback announces only ordinary six")
	var plan:Dictionary={"damage":7,"base_damage":5,"weak_bonus":2,"combat_context":slam.duplicate(true),"mitigates_intent":true}
	check("강타 약화" in ui.preview_effect_line(plan),"qualifying preview explicitly mitigates")
	plan.mitigates_intent=false
	check("미충족" in ui.preview_effect_line(plan),"nonqualifying preview does not promise mitigation")
	plan.combat_context.mitigation_success=true
	check("유지" in ui.preview_effect_line(plan),"already latched turn remains mitigated without another quota")
	var font:Font=load("res://assets/ChromaSans.otf")
	for line in lines+success+fallback+[ui.preview_effect_line(plan)]:
		check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<=628,"critical line fits at22px: "+line)
	check(ui.BOARD_SCREEN==Rect2(30,268,660,530) and ui.BOARD_SCREEN.end.y<799,"two-line status reserves space without cropping full board or footer")
	# Prior draw literal is the fallback until the layout exposes its actual baseline.
	var baseline: Vector2 = ui.get_script_constant_map().get("WEAKNESS_BASELINE",Vector2(529,100))
	for color in range(4):
		var copy: String = "약점 · "+ui.weakness_name(color)
		var bounds := Rect2(baseline-Vector2(0,font.get_ascent(22)),Vector2(font.get_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x,font.get_height(22)))
		check(not bounds.intersects(ui.RESET),"weakness label avoids reset target: "+copy)
	check(ui.weakness_name(0)=="불꽃" and ui.weakness_name(1)=="새잎" and ui.weakness_name(2)=="번개" and ui.weakness_name(3)=="물결","weakness names match existing palette")
	print("ELEMENTAL_UI checks=",checks," failures=",failures)
	quit(1 if failures else 0)

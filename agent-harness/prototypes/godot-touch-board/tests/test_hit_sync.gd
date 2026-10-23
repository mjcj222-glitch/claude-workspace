extends SceneTree
const FX=preload("res://scripts/board_quality_fx.gd")
var failures:=0
func check(ok:bool,text:String)->void:
	if not ok:failures+=1;printerr("FAIL "+text)
func _init()->void:
	var fx:Variant=FX.new()
	check(fx.has_method("take_impact") and fx.has_method("display_enemy_hp"),"shared impact owns one-shot hit and presented HP")
	if not fx.has_method("take_impact"):quit(1);return
	var panels:Array=[{"id":1,"kind":"normal"},{"id":2,"kind":"normal"},{"id":3,"kind":"heart"},{"id":4,"kind":"core"}]
	var plan:Dictionary={"valid":true,"mode":"clear","removed":[1,2,2,3,4],"activated":[4],"damage":9,"base_damage":8,"weak_bonus":1,"heal_raw":2,"heal_effective":1,"heal_overflow":1}
	var snapshot:=plan.duplicate(true)
	fx.action_started(plan,panels,0.25,24)
	check(fx.display_enemy_hp(24)==24,"collection preserves live HP before bank release")
	fx.panel_removed(1,Vector2.ZERO,Color.RED,"normal")
	check(not fx.panel_removed(1,Vector2.ZERO,Color.RED,"normal"),"duplicate reachability is ignored")
	fx.update(0.1)
	check(fx.take_impact().is_empty(),"flight has no early hit")
	fx.panel_removed(2,Vector2.ZERO,Color.BLUE,"normal")
	fx.panel_removed(3,Vector2.ZERO,Color.PINK,"heart")
	fx.panel_removed(4,Vector2.ZERO,Color.YELLOW,"core")
	fx.action_finished();fx.update(0.16)
	check(fx.take_impact().is_empty(),"finished clear still only collects")
	var bank=plan.duplicate(true);bank.core_activations=fx.core_activations
	fx.release_bank(bank,4,24)
	check(fx.display_enemy_hp(15)==24,"bank holds displayed HP until shared impact")
	fx.update(FX.BANK_WINDUP)
	var impact:Dictionary=fx.take_impact()
	check(impact.get("damage")==9 and impact.get("base_damage")==8 and impact.get("weak_bonus")==1 and impact.get("cores")==1,"one hit has exact committed arithmetic and core metadata")
	check(fx.take_impact().is_empty(),"impact audio/recoil cannot be duplicated")
	fx.action_finished();fx.update(0.2)
	check(fx.take_impact().is_empty() and fx.display_enemy_hp(15)==15,"duplicate finish cannot apply or display damage twice")
	check(plan==snapshot,"presentation never mutates gameplay plan")
	fx.reset();check(fx.take_impact().is_empty() and fx.display_enemy_hp(30)==30,"reset cancels old hit and HP hold")
	fx.action_started({"valid":true,"mode":"skill","removed":[1],"damage":99},panels,0.1,30);fx.action_finished();fx.update(1)
	check(fx.take_impact().is_empty(),"conversion itself never hits")
	fx.action_started({"valid":true,"mode":"clear","removed":[3],"damage":0,"heal_raw":2,"heal_effective":2},panels,0.1,24)
	fx.panel_removed(3,Vector2.ZERO,Color.PINK,"heart");fx.action_finished();fx.update(0.2)
	check(fx.take_impact().is_empty() and fx.display_enemy_hp(24)==24,"heart-only clear never hits enemy")
	fx.reset();fx.skill_activated();fx.action_started(plan,panels,0.2,24)
	check(not fx.skill_link,"unrelated skill use cannot claim a converted connection without affected IDs")
	fx.reduced_effects=true
	check(fx.stage_offset()==Vector2.ZERO,"reduced mode suppresses enemy displacement")
	fx.reset();fx.skill_activated({1:0});fx.action_started(plan,panels,0.2,24)
	check(fx.skill_link,"actually changed participating panel can identify a conversion link")
	fx.reset();fx.update(1)
	check(fx.take_impact().is_empty(),"reset prevents stale hit resurrection")
	print("HIT_SYNC failures=",failures);quit(1 if failures else 0)

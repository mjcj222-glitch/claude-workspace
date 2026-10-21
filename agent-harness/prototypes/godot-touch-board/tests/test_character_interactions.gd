extends SceneTree
const Run=preload("res://scripts/board_run_session.gd")
const Rules=preload("res://scripts/board_rules.gd")
const UI=preload("res://scripts/board_ui.gd")
const State=preload("res://scripts/board_skill_presentation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func row(colors:Array)->Array:
 var out:Array=[]
 for i in range(colors.size()):out.append({"id":i+1,"kind":"normal","color":colors[i],"pos":Vector2(120+74*i,460),"radius":37.0})
 return out
func hero(panels:Array,relics:Array=[]):
 var s=Run.new();s.initialize_board(panels,100);s.open_departure();s.select_departure("noa",s.offer_serial);s.start_departure(s.offer_serial);s.relics=relics.duplicate();return s
func plant(s,id:int)->Dictionary:
 var point:Vector2=Rules._index(s.panels)[id].pos
 s.skill_mode=true;s.begin(point,0);return s.release(point,0)
func clear(s,id:int)->Dictionary:
 var point:Vector2=Rules._index(s.panels)[id].pos
 s.begin(point,0);return s.release(point,0)
func _initialize()->void:
 var s=hero(row([0,1,0]))
 var context:Dictionary=s.combat.damage_context();var h:int=s.combat.enemy_hp
 var skill:Dictionary=plant(s,1)
 check(s.combat.damage_context()==context and s.combat.enemy_hp==h and not s.combat.mitigation_success,"plant never latches or recomputes telegraph")
 var before:Dictionary=s.plan_for(1)
 check(before.direct==[1] and before.activated==[1] and before.normal_count==2 and before.weak_count==2 and before.base_damage==2 and before.weak_bonus==1 and before.damage==3,"planted core excludes itself from weak W and normal damage; converted effective color counts")
 var result:Dictionary=clear(s,1)
 check(result.removed==before.removed and result.damage==before.damage and s.combat.enemy_hp==h-before.damage and s.actions==1,"subsequent blast is exactly the frozen clear plan")
 check(result.removed.size()==3 and result.removed.count(1)==1 and result.activated.size()==1,"planted ID counts once in destruction and activation")
 check(result.direct_normals==0 and result.spawn.is_empty() and not result.ash_reserve,"plant cannot manufacture direct normals or ash")
 s=hero(row([0,1,2,3]),["pigment"]);plant(s,1)
 check(s.panels[0].kind=="strong" and s.plan_for(1).normal_count==2,"pigment plant reaches two contact steps, not whole board")
 check(s.plan_for(1).converted.has(3) and not s.plan_for(1).converted.has(4),"strong reach boundary remains canonical")
 s=hero(row([0,1,2]));s.skill_mode=true;s.begin(s.panels[0].pos,0)
 var snapshot:Dictionary=s.selection.duplicate(true);s.relics.append("pigment")
 var cast:Dictionary=s.release(s.panels[0].pos,0)
 check(cast==snapshot and s.panels[0].kind=="core","acquisition cannot retroactively change held skill plan")
 check(UI.relic_copy("pigment",s).change=="심는 핵: 일반핵 → 강화핵","noa reward/detail/shop copy has meaningful effect")
 s=hero(row([0,0,0,0,0]),["lens","ash"])
 check(s.plan_for(1).spawn.kind=="core" and not s.plan_for(1).ash_reserve,"noa lens5 threshold does not lower ash6")
 s.panels=row([0,0,0,0,0,0]);check(s.plan_for(1).ash_reserve,"noa direct6 still arms ash")
 plant(s,1)
 check(s.charge_required==3 and s.charge==0,"without reserved ash plant requires3")
 s.panels=row([0,0]);s.skill_mode=false
 for i in range(4):
  s.phase="ready";s.panels=row([2,2]);clear(s,1)
  check(s.charge==mini(i+1,3),"normal charge cap tick "+str(i+1))
 s=hero(row([0,1]));s.ash_reserved=true;plant(s,1)
 check(s.charge_required==2 and s.charge==0 and not s.ash_reserved,"ash is consumed by actual noa skill")
 check(State.snapshot(s).charge_text=="0 / 2" and not State.snapshot(s).illuminated,"noa dock shows actual2 requirement unlit")
 s.panels=row([0,0]);s.skill_mode=false
 for i in range(3):
  s.phase="ready";s.panels=row([2,2]);clear(s,1)
  check(s.charge==mini(i+1,2),"ash charge cap tick "+str(i+1))
 # Existing second enemy condition is direct4; core secondary reach is distinct.
 s=hero(row([0,1,0,0,0]));s.combat.start_fight(1,s.panels,"safe")
 var intent:Dictionary=s.combat.damage_context();plant(s,1)
 check(s.combat.damage_context()==intent,"second-enemy intent unchanged by core installation")
 var planned:Dictionary=s.plan_for(1)
 check(planned.direct.size()==1 and not planned.mitigates_intent,"secondary core clear is not second-enemy direct4")
 # Boss condition counts removed ordinary normals, not the planted core itself.
 s=hero(row([3,1,3]));s.combat.start_fight(2,s.panels)
 s.combat.mitigation_active=true;s.combat.fallback_plain=false;s.combat.incoming_damage=10
 # Explicit edge fixture: set the same public intent used by canonical planner.
 var boss_context:Dictionary={"weakness_color":3,"intent":"slam","slam_weak_required":2,"slam_normal_required":8}
 plant(s,1)
 planned=Rules.plan(s.panels,1,30,30,[],boss_context)
 check(planned.weak_count==2 and planned.mitigates_intent,"installed blue core can satisfy boss through2 removed weak normals")
 s=hero(row([3,1]));plant(s,1);planned=Rules.plan(s.panels,1,30,30,[],boss_context)
 check(planned.weak_count==1 and not planned.mitigates_intent,"core object cannot supply missing second weak normal")
 # Heart and existing special keep their kind and cannot be installed upon.
 var b:Array=row([0,4,1]);b[1].kind="heart";s=hero(b,["pigment"]);plant(s,1)
 check(s.panels[1].kind=="heart" and s.panels[1].color==4 and s.plan_for(1).heal_raw==0,"heart excluded from core conversion and damage")
 print("CHARACTER_INTERACTIONS checks=",checks," failures=",failures);quit(1 if failures else 0)

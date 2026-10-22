extends SceneTree
const Run = preload("res://scripts/board_run_session.gd")
const Rules = preload("res://scripts/board_rules.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func panel(id:int,color:int=0,kind:String="normal")->Dictionary:
 return {"id":id,"color":color,"kind":kind,"pos":Vector2(100+(id-1)*74,450),"radius":37.0}
func board()->Array:return [panel(1,0),panel(2,1),panel(3,2),panel(4,3),panel(5,4,"heart")]
func _initialize()->void:
 var s=Run.new();s.initialize_board(board(),6)
 check(s.has_method("open_departure"),"actual run can open character departure")
 if not s.has_method("open_departure"):print("CHARACTERS checks=",checks," failures=",failures);quit(1);return
 s.open_departure()
 check(s.phase=="departure" and s.character_id=="" and s.departure_choice=="","fresh departure owns no committed hero")
 var serial:int=s.offer_serial
 check(not s.start_departure(serial) and not s.select_departure("invalid",serial),"no missing or invalid hero")
 check(s.select_departure("noa",serial),"choose nucleus character")
 check(not s.start_departure(serial),"stale card release cannot start")
 check(s.start_departure(s.offer_serial) and s.character_id=="noa" and s.phase=="ready","explicit start commits once")
 check(not s.select_departure("rio",s.offer_serial) and not s.start_departure(s.offer_serial),"hero cannot change after start")
 var before:Array=s.panels.duplicate(true);var context:Dictionary=s.combat.damage_context()
 s.skill_mode=true;s.begin(before[0].pos,-1);var preview:Dictionary=s.selection.duplicate(true)
 check(preview.valid and preview.planted=={1:"core"} and preview.converted.is_empty() and preview.targets==[1] and preview.rain_refills==2 and preview.rain_color==0,"noa plans same-color core plus two refill rain")
 s.cancel();check(s.release(before[0].pos,-1).is_empty() and s.panels==before and s.charge==3,"cancel has no installation or charge cost")
 s.begin(before[0].pos,-1);preview=s.selection.duplicate(true);var used:Dictionary=s.release(before[0].pos,-1)
 check(used==preview and s.panels[0].kind=="core","frozen skill plan commits exactly")
 var expected:Array=before.duplicate(true);expected[0].kind="core"
 check(s.panels==expected and s.next_id==6,"installation preserves ID position radius color and all other panels")
 check(s.actions==0 and s.damage_total==0 and s.hp==30 and s.phase=="ready" and s.charge==0 and s.skill_uses==1,"no action damage heal refill or free charge")
 check(s.combat.damage_context()==context and s.combat.enemy_hp==24,"skill cannot change intent mitigation or enemy HP")
 check(s.release(before[0].pos,-1).is_empty() and s.skill_uses==1,"duplicate release cannot repeat installation")
 var p:Dictionary=s.plan_for(1)
 check(p.valid and p.activated==[1] and p.normal_count==1 and p.base_damage==1,"installed core uses canonical future blast excluding core as ordinary")
 check(not s.skill_plan_for(1,0).valid and not s.skill_plan_for(5,0).valid,"hearts and existing cores invalid targets")
 s=Run.new();s.initialize_board(board(),6);s.character_id="noa";s.relics=["pigment","lens","ash"];s.ash_reserved=true
 s.skill_mode=true;s.begin(s.panels[1].pos,-1);preview=s.selection.duplicate(true)
 check(preview.planted=={2:"strong"} and preview.consume_ash and preview.recharge_required==2,"pigment upgrades only planted core and ash sets two")
 s.release(s.panels[1].pos,-1)
 check(s.panels[1].kind=="strong" and s.charge_required==2 and not s.ash_reserved,"ash reservation consumed with actual skill")
 s.relics=[];check(s.panels[1].kind=="strong","installed kind frozen at cast")
 var normals:Array=[]
 for i in range(1,7):normals.append(panel(i,0))
 s.panels=normals;s.relics=["lens","ash"]
 check(s.plan_for(1).spawn.kind=="core" and s.plan_for(1).ash_reserve,"lens and ash direct rules still apply to noa")
 s.skill_mode=false;s.begin(normals[0].pos,-1);s.release(normals[0].pos,-1)
 check(s.charge==0 and s.ash_reserved and s.rain_remaining==2,"first rain clear reserves ash without charging")
 s.phase="ready";s.panels=normals;s.begin(normals[0].pos,-1);s.release(normals[0].pos,-1)
 check(s.charge==0 and s.rain_remaining==1,"second rain clear still cannot self-charge")
 s.phase="ready";s.panels=normals;s.begin(normals[0].pos,-1);var last_rain=s.release(normals[0].pos,-1)
 check(s.charge==0 and s.rain_remaining==0 and last_rain.supply_color==1,"last rain clear supplies color but still cannot charge")
 for expected_charge in [1,2,2]:
  s.phase="ready";s.panels=normals;s.begin(normals[0].pos,-1);var normal_clear=s.release(normals[0].pos,-1)
  check(s.charge==expected_charge and normal_clear.supply_color==-1,"new clears recharge with cap after rain: "+str(expected_charge))
 # Default standalone API remains Rio; skill contract is now whole source color.
 s=Run.new();s.initialize_board(board(),6)
 check(s.phase=="ready" and s.character_id=="rio","standalone existing test API retains rio")
 var now:Dictionary=s.skill_plan_for(1,3)
 check(now.targets==[1] and now.converted=={1:3},"rio transforms every source-color normal, no unrelated neighbors")
 s.panels.append(panel(6,0));s.panels.append(panel(7,0,"core"));s.panels.append(panel(8,0,"bomb"));s.next_id=9
 now=s.skill_plan_for(1,3)
 check(now.targets==[1,6] and now.converted=={1:3,6:3},"rio reaches distant source color and preserves specials")
 check(not s.skill_plan_for(1,0).valid and not s.skill_plan_for(5,3).valid,"same-color cast and hearts are invalid")
 s.relics=["pigment"];now=s.skill_plan_for(1,3)
 check(now.targets==[1,6] and now.rain_refills==1 and now.rain_color==3,"pigment adds one target-color refill without altering target set")
 print("CHARACTERS checks=",checks," failures=",failures);quit(1 if failures else 0)

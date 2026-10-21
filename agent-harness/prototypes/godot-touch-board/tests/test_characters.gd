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
 check(preview.valid and preview.planted=={1:"core"} and preview.converted.is_empty() and preview.targets==[1],"noa plans one same-color core")
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
 check(s.charge==1 and s.ash_reserved,"manual clear charges once and reserves ash")
 s.phase="ready";s.panels=normals;s.begin(normals[0].pos,-1);s.release(normals[0].pos,-1)
 check(s.charge==2 and s.charge_required==2,"two-charge cycle reaches ready without overfill")
 # Default standalone API and original transform remain intentionally compatible.
 s=Run.new();s.initialize_board(board(),6)
 check(s.phase=="ready" and s.character_id=="rio","standalone existing test API retains rio")
 var old:Dictionary=Rules.skill_plan(s.panels,1,3,[])
 var now:Dictionary=s.skill_plan_for(1,3)
 check(now.targets==old.targets and now.converted==old.converted and now.connected==old.connected,"rio conversion stays canonical 4")
 s.relics=["pigment"];check(s.skill_plan_for(1,3).targets.size()==4,"heart blocks rio path even with pigment")
 print("CHARACTERS checks=",checks," failures=",failures);quit(1 if failures else 0)

extends SceneTree
const Rules=preload("res://scripts/board_rules.gd")
const Bombs=preload("res://scripts/board_bombs.gd")
const Session=preload("res://scripts/board_session.gd")
const Characters=preload("res://scripts/board_characters.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func p(id:int,x:float,kind:String="normal",color:int=0,y:float=500)->Dictionary:
 return {"id":id,"pos":Vector2(x,y),"radius":48.0 if kind=="big_bomb" else 37.0,"kind":kind,"color":color}
func _init()->void:
 check(preload("res://scripts/board_panel_view.gd").visual_radius(p(90,100,"bomb"))==37,"ordinary bomb visible body matches physical37 contact envelope")
 var bridge:Array=[p(1,100),p(2,174,"bomb"),p(3,248)]
 var plan:Dictionary=Rules.plan(bridge,1,20,30)
 check(plan.valid and plan.direct==[1,2,3],"same color bomb bridges direct ordinary component")
 check(Rules.plan(bridge,2,20,30).direct==[2,1,3],"bomb tap selects its same color component bidirectionally")
 bridge[1].color=1
 check(not Rules.plan(bridge,1,20,30).valid,"different color bomb cannot bridge direct chain")
 plan=Rules.plan(bridge,2,20,30)
 check(plan.valid and plan.direct==[2] and plan.activated==[2],"different color bomb keeps solo tap detonation")
 check(plan.base_damage==2 and plan.normal_count==2,"bomb object adds no intrinsic attack damage")
 bridge=[p(1,200,"big_bomb",2),p(2,285,"normal",2)]
 plan=Rules.plan(bridge,1,20,30)
 check(plan.direct==[1,2] and plan.blasts[0].radius==164,"large48 body contacts37 neighbor with same color and independent164 blast")
 check(plan.blasts[0].get("color",-1)==2,"blast snapshot preserves attribute separate from size")
 bridge[1].pos.x=287
 check(Rules.plan(bridge,1,20,30).direct==[1],"beyond physical contact is not joined even inside blast")
 var chain:Array=[p(1,120,"bomb",0),p(2,200,"bomb",1),p(3,274,"normal",1),p(4,348,"normal",1),p(5,200,"heart",4,575)]
 plan=Rules.plan(chain,1,29,30)
 check(plan.activated==[1,2] and not plan.removed.has(4),"secondary different-color blast preserves radial rule, no automatic normal-color flood")
 var direct:Dictionary=Rules.plan(chain,2,29,30)
 check(direct.direct.has(4) and direct.removed.has(4),"deliberate same-color tap reaches beyond blast through its direct chain")
 check(plan.removed.size()==4 and plan.heal_raw==2 and plan.heal_effective==1 and plan.heal_overflow==1,"overlapping blasts remove and heal each actual ID once")
 check(plan.normal_count==1 and plan.base_damage==1,"secondary bombs and heart never inflate ordinary damage")
 var line:Array=[]
 for i in range(5):line.append(p(i+1,70+i*74))
 line.append(p(6,440,"bomb"))
 plan=Rules.plan(line,1,30,30,["ash"])
 check(plan.direct.size()==6 and plan.direct_normals==5 and plan.spawn.is_empty() and not plan.ash_reserve,"five normals plus bomb do not reach six-normal core or Ash trigger")
 plan=Rules.plan(line,1,30,30,["lens"])
 check(plan.spawn.get("kind","")=="core" and plan.direct_normals==5,"lens counts five actual direct normals, not objects")
 line.append(p(7,514))
 plan=Rules.plan(line,1,30,30,["ash"],{"weakness_color":0})
 check(plan.direct_normals==6 and plan.spawn.get("kind","")=="core" and plan.ash_reserve,"six actual normals retain core and Ash trigger with bomb bridge")
 check(plan.base_damage==6 and plan.weak_count==6 and plan.damage==9,"colored bomb contributes neither weakness nor intrinsic damage")
 var supply:Array=[p(1,200,"bomb",3),p(10,274,"strong",1),p(20,126,"strong",2)]
 plan=Rules.plan(supply,1,30,30,["lens"])
 check(plan.bomb_spawn_kind=="big_bomb" and plan.get("bomb_spawn_color",-1)==1,"first activated strong core by distance then ID supplies its color")
 check(Rules.plan(supply,20,30,30).get("bomb_spawn_color",-1)==2,"starting strong core color wins before later competing cores")
 var pending:Array=[p(100,100,"heart",4),p(101,174,"normal",2)]
 if plan.get("bomb_spawn_color",-1)>=0:
  Callable(Bombs,"prepare_supply").call(pending,plan.bomb_spawn_kind,plan.bomb_spawn_color)
 check(pending[0].kind=="big_bomb" and pending[0].color==1 and pending[0].radius==48 and pending[0].id==100 and pending[1].kind=="normal","one existing pending ID gets color and physical48 independently")
 check(not plan.removed.has(100),"new supply cannot participate in current plan")
 var conversion:Array=[p(1,100,"normal",0),p(2,174,"bomb",3),p(3,248,"normal",3)]
 var skill:Dictionary=Characters.skill_plan(conversion,1,3,["pigment"],"rio")
 check(skill.targets==[1] and skill.connected==[1,2,3],"Rio cannot target/traverse bomb but resulting-color connection preview can use it")
 check(not skill.converted.has(2) and not Characters.skill_plan(conversion,2,0,[],"rio").valid,"Rio never recolors or targets bomb")
 check(not Characters.skill_plan(conversion,2,0,["pigment"],"noa").valid,"Noa never plants over bomb")
 var s=Session.new();s.panels=conversion.duplicate(true);s.character_id="rio";s.skill_mode=true;s.skill_color=3
 s.begin(conversion[0].pos,-1);var preview:Dictionary=s.selection.duplicate(true);s.release(conversion[0].pos,-1)
 check(s.actions==0 and s.panels.size()==3 and s.panels[1].color==3 and s.panels[0].color==3,"skill only converts, no bomb detonation or clear action")
 s.begin(conversion[0].pos,-1);preview=s.selection.duplicate(true);s.cancel();s.release(conversion[0].pos,-1)
 check(s.actions==0 and s.panels.size()==3,"colored chain first press cancel consumes nothing")
 s.begin(conversion[0].pos,-1);preview=s.selection.duplicate(true);var actual:Dictionary=s.release(conversion[0].pos,-1)
 check(actual==preview and actual.direct==[1,2,3] and s.actions==1,"colored direct/blast preview exactly equals committed frozen plan")
 var protected:Dictionary=actual.get("spawn",{})
 check(protected.is_empty() and s.charge==1,"bomb objects do not create free core or extra recharge")
 var core_case:Array=[p(1,100,"core",0),p(2,174,"bomb",3),p(3,248,"normal",2)]
 plan=Rules.plan(core_case,1,20,30)
 check(not plan.converted.has(2) and core_case[1].color==3 and plan.activated.has(2),"existing core triggers but never recolors bomb")
 var overlap:Array=[p(1,100),p(2,174,"bomb"),p(3,248,"bomb"),p(4,322),p(5,248,"heart",4,575)]
 var overlap_plan:Dictionary=Rules.plan(overlap,1,29,30,[],{"weakness_color":0,"intent":"direct4"})
 check(overlap_plan.direct==[1,2,3,4] and overlap_plan.activated==[2,3] and overlap_plan.removed.size()==5 and overlap_plan.heal_raw==2,"two directly joined colored bombs activate and remove overlapping IDs exactly once")
 check(overlap_plan.damage==3 and overlap_plan.weak_count==2 and overlap_plan.mitigates_intent,"existing direct4 includes legal direct IDs while damage and weakness count normals only")
 var protected_session=Session.new();protected_session.panels=line.duplicate(true)
 protected_session.panels.append(p(8,588,"strong",0));protected_session.next_id=1000
 protected_session.begin(line[0].pos,-1);preview=protected_session.selection.duplicate(true)
 actual=protected_session.release(line[0].pos,-1)
 check(actual.spawn.get("kind","")=="core" and protected_session.panels.size()==1 and protected_session.panels[0].id==1000 and not actual.removed.has(1000) and not actual.activated.has(1000),"colored chain generates one protected new core after existing effects")
 check(actual.bomb_spawn_kind=="bomb" and actual.bomb_spawn_color==0 and actual.direct_normals==6,"same action can supply one originating-color bomb without counting bomb/core as normals")
 print("COLORED_BOMBS checks=",checks," failures=",failures);quit(1 if failures else 0)

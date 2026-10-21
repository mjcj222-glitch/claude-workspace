extends SceneTree
const Rules=preload("res://scripts/board_rules.gd")
const Session=preload("res://scripts/board_session.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func panel(id:int,x:float,y:float,kind:String="normal",color:int=0)->Dictionary:
 return {"id":id,"pos":Vector2(x,y),"radius":48.0 if kind=="big_bomb" else 37.0,"kind":kind,"color":color}
func _init()->void:
 var source:Array=[panel(1,200,400,"bomb"),panel(2,275,400,"normal",1),panel(3,350,400,"normal",2),panel(4,200,475,"heart",4)]
 check("대형" in preload("res://scripts/board_ui.gd").RELIC_COPY.lens.lines[1],"actual reward/details/shop copy discloses large bombs")
 check("대형" in preload("res://scripts/board_ui.gd").RELIC_COPY.lens.change,"shop and event purchase copy disclose large bombs")
 var original:Array=source.duplicate(true)
 var a:Dictionary=Rules.plan(source,1,29,30,[],{"weakness_color":1})
 check(a.valid and a.removed==[1,2,4],"different-color neighbors still permit solo radial clear including heart")
 if not a.valid:print("BOMBS checks=",checks," failures=",failures);quit(1);return
 check(a.damage==1 and a.weak_count==1 and a.heal_raw==2 and a.heal_effective==1 and a.heal_overflow==1,"bomb object no damage; ordinary weakness and capped heart count once")
 check(a.direct_normals==0 and a.spawn.is_empty(),"bomb/secondary removals never farm direct core threshold")
 source[0].kind="big_bomb"
 source[0].radius=48.0
 var b:Dictionary=Rules.plan(source,1,29,30)
 check(b.removed.has(3) and b.removed.size()>a.removed.size(),"large bomb has strictly larger actual radial reach")
 check(a.blasts[0].radius==98 and b.blasts[0].radius==164 and source[0].radius==48,"blast98/164 remains separate from physical body48")
 source=[panel(1,200,400,"bomb"),panel(2,280,400,"bomb"),panel(3,360,400,"strong",2),panel(4,400,400,"normal",0),panel(5,280,475,"heart",4),panel(6,220,470,"normal",3)]
 var chain:Dictionary=Rules.plan(source,1,20,30,["lens"],{"weakness_color":2})
 check(chain.activated.size()==3 and chain.blasts.size()==2,"radial bomb reaches other bomb then core activation")
 check(chain.removed.size()==6 and chain.heal_raw==2 and chain.normal_count==2,"duplicate paths cannot remove/heal/damage an ID twice")
 check(chain.bomb_spawn_kind=="big_bomb","actual strong core activation prepares one lens-amplified bomb")
 check(Rules.plan(source,1,20,30).bomb_spawn_kind=="bomb","without lens strong core prepares ordinary bomb")
 check(chain.weak_count<=2 and chain.damage==chain.base_damage+chain.weak_bonus,"weakness uses effective removed ordinary colors only")
 var normals:Array=[]
 for i in range(12):normals.append(panel(i+1,100+(i%4)*74,350+(i/4)*74))
 var long_plan:Dictionary=Rules.plan(normals,1,30,30)
 check(long_plan.spawn.kind=="strong" and long_plan.bomb_spawn_kind=="","long clear retains existing core reward without duplicate bomb gift")
 normals[0].kind="strong"
 var strong:Dictionary=Rules.plan(normals,1,30,30)
 check(strong.bomb_spawn_kind=="bomb","strong activation prepares only one bomb regardless chain size")
 var s=Session.new();s.panels=source.duplicate(true);s.hp=20;s.relics=["lens"];s.next_id=20
 var pos:Vector2=source[0].pos
 s.begin(pos,-1);var preview:Dictionary=s.selection.duplicate(true);s.cancel();s.release(pos,-1)
 check(s.actions==0 and s.hp==20 and s.panels==source,"cancel first bomb press consumes nothing")
 s.begin(pos,-1);preview=s.selection.duplicate(true);var actual:Dictionary=s.release(pos,-1)
 check(actual.removed==preview.removed and actual.blasts==preview.blasts and actual.damage==preview.damage,"held full chain preview and commit use identical frozen plan")
 var pending:Array=[panel(50,100,200),panel(51,174,200)]
 var bombs=load("res://scripts/board_bombs.gd")
 check(bombs!=null,"separate bomb metadata helper")
 if bombs!=null:
  bombs.prepare_supply(pending,actual.bomb_spawn_kind)
  check(pending[0].kind=="big_bomb" and pending[1].kind=="normal" and pending[0].radius==48,"exactly one new pending panel becomes bomb with unchanged ID/count, actual large body48")
  check(not actual.removed.has(50) and not actual.activated.has(50),"newly supplied bomb cannot detonate in creating action")
 check(original[0].kind=="bomb","planning did not mutate input")
 var conversion:Array=[panel(1,200,400,"bomb"),panel(2,274,400,"core",1),panel(3,348,400,"normal",0)]
 var into:Dictionary=Rules.plan(conversion,1,30,30,[],{"weakness_color":1})
 var out:Dictionary=Rules.plan(conversion,1,30,30,[],{"weakness_color":0})
 check(into.removed.has(3) and into.converted[3]==1 and into.weak_count==1,"bomb-triggered core conversion uses final weak color")
 check(out.weak_count==0 and out.normal_count==1,"converted-away original weakness is not counted")
 for kind in ["bomb","big_bomb"]:
  var radius:float=98 if kind=="bomb" else 164
  var edge:Array=[panel(1,200,400,kind),panel(2,200+radius,400)]
  check(Rules.plan(edge,1,30,30).removed.has(2),kind+" exact geometric boundary included")
  edge[1].pos.x+=.01
  check(not Rules.plan(edge,1,30,30).removed.has(2),kind+" outside geometric boundary excluded")
 var bridge:Array=[panel(1,100,400),panel(2,174,400,"bomb"),panel(3,248,400)]
 check(Rules.plan(bridge,1,30,30).direct==[1,2,3],"colored bomb bridges its same-color group")
 print("BOMBS checks=",checks," failures=",failures);quit(1 if failures else 0)

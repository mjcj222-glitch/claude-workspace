extends SceneTree
const C=preload("res://scripts/board_characters.gd")
const R=preload("res://scripts/board_rules.gd")
const Combat=preload("res://scripts/board_combat.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _initialize():
 var ps=[]
 for i in range(10):ps.append({"id":i+1,"kind":"normal","color":0 if i<8 else 1,"pos":Vector2(80+i*70,400),"radius":37.0})
 ps.append({"id":11,"kind":"heart","color":4,"pos":Vector2(80,500),"radius":37.0})
 ps.append({"id":12,"kind":"big_bomb","color":0,"pos":Vector2(150,500),"radius":48.0})
 var before=ps.duplicate(true)
 var p=C.skill_plan(ps,1,2,[],"rio")
 check(p.valid and p.targets.size()==8,"Rio transforms all source normal color")
 check(not p.converted.has(11) and not p.converted.has(12),"heart and bomb preserved")
 check(not C.skill_plan(ps,1,0,[],"rio").valid,"same color no-op invalid")
 check(C.skill_plan(ps,1,2,["pigment"],"rio").get("rain_refills",0)==1,"Rio pigment one refill")
 var n=C.skill_plan(ps,9,2,[],"noa")
 check(n.get("rain_refills",0)==2 and n.get("rain_color",-1)==1,"Noa selected color two refills")
 check(C.skill_plan(ps,9,2,["pigment"],"noa").get("rain_refills",0)==3,"Noa pigment three refills")
 check(ps==before,"planning pure")
 var boss=Combat.new();boss.start_fight(2,ps)
 check(boss.damage_context().get("shield_hp",0)==12 and boss.damage_context().get("shield_color",-1)==0,"boss dominant-color shield12")
 var plan=R.plan(ps,1,30,30,[],{"shield_hp":4,"shield_color":0})
 check(plan.get("shield_broken",false) and plan.get("shield_bonus",0)==6,"matching chain breaks with bonus")
 var other=R.plan(ps,9,30,30,[],{"shield_hp":12,"shield_color":3})
 check(other.get("shield_damage",0)==1 and other.damage==1,"offcolor progress and half damage")
 boss.shield_hp=4;boss.shield_color=0
 var hit=R.plan(ps,1,30,30,[],boss.damage_context());var old_hp=boss.enemy_hp
 boss.record_clear(hit)
 check(boss.shield_hp==4 and boss.pending_shield==4 and boss.enemy_hp==old_hp and boss.pending_damage==hit.damage,"shield preview banks exact damage and bonus")
 check(boss.actions_in_turn==1,"shield break does not cancel or reset enemy action")
 var hearts=[{"id":21,"kind":"heart","color":4,"pos":Vector2(80,500),"radius":37.0},{"id":22,"kind":"heart","color":4,"pos":Vector2(150,500),"radius":37.0}]
 var heart=R.plan(hearts,21,20,30,["petal"],{"shield_hp":1,"shield_color":0,"intent":"slam"})
 check(heart.shield_broken and heart.damage==0 and heart.heal_raw==2,"heart breaks without inventing damage or changing petal")
 var loop=Combat.new();loop.start_fight(2,ps);loop.shield_hp=1;loop.shield_color=3
 for turn in range(4):
  for action in range(3):
   var safe=R.plan(hearts,21,30,30,[],loop.damage_context());loop.record_clear(safe)
  loop.settle_attack()
  check(loop.resolve()=="attack" and loop.take_attack()>0,"shield cannot stunlock attack cycle "+str(turn))
  loop.next_turn(ps)
  check(loop.shield_hp==0,"shield does not regenerate "+str(turn))
 print("PRISM checks=",checks," failures=",failures);quit(1 if failures else 0)

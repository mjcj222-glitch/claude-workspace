extends SceneTree
const Rules=preload("res://scripts/board_rules.gd")
const Combat=preload("res://scripts/board_combat.gd")
const Relics=preload("res://scripts/board_relics.gd")
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func hearts(n):
 var result=[]
 for i in range(n):result.append({"id":i+1,"kind":"heart","color":4,"pos":Vector2(20*i,0),"radius":10.0})
 return result
func _initialize():
 check(Relics.available([])==["pigment","lens","ash"],"initial legacy offers stay fixed")
 check("petal" in Relics.available(["pigment"]),"new alternative after first relic")
 check(Relics.available(["pigment","lens","ash"]).is_empty(),"three-slot cap preserves exhausted reward")
 for intent in ["plain","direct4","slam"]:
  var ctx={"intent":intent,"incoming_damage":10 if intent=="slam" else 7,"mitigation_success":false}
  var board=hearts(3);var before=board.duplicate(true)
  var plan=Rules.plan(board,1,20,30,["petal"],ctx)
  check(plan.heal_raw==3 and plan.heal_effective==3,"healing tradeoff "+intent)
  check(plan.mitigates_intent==(intent!="plain"),"three direct hearts qualify only conditional intent "+intent)
  check(plan.damage==0 and board==before,"hearts remain damage-free/pure "+intent)
  if intent!="plain":
   var c=Combat.new();c.intent=intent;c.mitigation_active=true;c.incoming_damage=ctx.incoming_damage
   c.record_clear(plan)
   check(c.mitigation_success and c.incoming_damage==(4 if intent=="slam" else 3),"snapshot executes petal mitigation "+intent)
   c.record_clear(plan)
   check(c.incoming_damage==(4 if intent=="slam" else 3),"petal does not stack "+intent)
  check(not Rules.plan(hearts(2),1,20,30,["petal"],ctx).mitigates_intent,"two hearts insufficient "+intent)
 var full=Rules.plan(hearts(3),1,30,30,["petal","petal"],{"intent":"slam"})
 check(full.heal_raw==3 and full.heal_effective==0 and full.heal_overflow==3 and full.mitigates_intent,"full HP permits defense; duplicate IDs cannot stack relic")
 check(Rules.plan(hearts(3),1,20,30,[],{"intent":"slam"}).heal_raw==6,"legacy healing unchanged without petal")
 var bomb=hearts(3)
 bomb.append({"id":4,"kind":"bomb","color":0,"pos":Vector2(20,30),"radius":10.0})
 var indirect=Rules.plan(bomb,4,20,30,["petal"],{"intent":"slam"})
 check(indirect.heal_raw==3 and not indirect.get("petal_guard",false),"blast hearts heal one but cannot trigger direct-heart guard")
 var c=Combat.new();c.intent="slam";c.mitigation_active=true;c.incoming_damage=10
 c.record_clear({"valid":true,"mode":"skill","petal_guard":true})
 check(c.incoming_damage==10 and c.actions_in_turn==0,"skills cannot grant free petal defense")
 for extra in ["pigment","lens","ash"]:
  var combined=Rules.plan(hearts(3),1,20,30,["petal",extra],{"intent":"slam"})
  check(combined.heal_raw==3 and combined.petal_guard and combined.spawn.is_empty() and not combined.ash_reserve,"petal interaction preserves heart/core/charge rules: "+extra)
 print("PETAL checks=",checks," failures=",failures);quit(1 if failures else 0)

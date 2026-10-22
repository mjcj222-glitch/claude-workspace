extends SceneTree
const C=preload("res://scripts/board_combat.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _initialize():
 var c=C.new();c.start_fight(0,[])
 var p={"valid":true,"mode":"clear","damage":10,"base_damage":8,"weak_bonus":2,"removed":[1,2],"direct":[1,2],"weak_count":0,"normal_count":2,"shield_damage":0}
 c.record_clear(p);c.record_clear(p)
 check(c.enemy_hp==24 and c.actions_in_turn==2,"firsttwo accumulate without HP damage")
 check(c.resolve()=="ready","firsttwo ready even accumulated damage near lethal")
 c.record_clear(p)
 check(c.enemy_hp==24 and c.resolve()=="strike","third waits for final strike")
 check(c.has_method("settle_attack"),"one-shot settlement API exists")
 if c.has_method("settle_attack"):
  c.settle_attack();check(c.enemy_hp==0 and c.resolve()=="win","one combined hit wins before retaliation")
  var n=c.enemies_defeated;c.settle_attack();c.resolve();check(c.enemies_defeated==n and c.take_attack()==0,"repeat settlement cannot repay or retaliate")
 print("BANKED checks=",checks," failures=",failures);quit(1 if failures else 0)

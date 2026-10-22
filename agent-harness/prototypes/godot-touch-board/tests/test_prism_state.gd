extends SceneTree
const S=preload("res://scripts/board_session.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _initialize():
 var s=S.new();s.character_id="noa"
 for i in range(4):s.panels.append({"id":i+1,"kind":"normal","color":1,"pos":Vector2(100+i*70,400),"radius":37.0})
 s.skill_mode=true;s.begin(Vector2(100,400),-1);var skill=s.release(Vector2(100,400),-1)
 check(skill.valid and s.get("rain_remaining")==2 and s.charge==0,"Noa arms two refills without attack")
 s.begin(Vector2(100,400),-1);var clear=s.release(Vector2(100,400),-1)
 check(clear.get("supply_color",-1)==1 and s.get("rain_remaining")==1 and s.charge==0,"first locked refill cannot recharge")
 check(s.release(Vector2(100,400),-1).is_empty() and s.get("rain_remaining")==1,"repeat release cannot consume another refill")
 check(s.actions==1,"chain descendants consume one action")
 print("PRISM_STATE checks=",checks," failures=",failures);quit(1 if failures else 0)

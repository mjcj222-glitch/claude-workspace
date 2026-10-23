extends SceneTree
const Area=preload("res://scripts/board_area_session.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func fixed(phase:String,gold:int=10,hp:int=20):
 var s=Area.new();s.phase=phase;s.current_node=phase;s.gold=gold;s.hp=hp;s.character_id="noa";s.charge=1;s.charge_required=2;s.ash_reserved=true;s.relics=["pigment","lens"];return s
func _initialize()->void:
 for phase in ["rest","event","shop"]:
  var s=fixed(phase)
  var accepted:bool=s.rest_choice("heal",s.offer_serial) if phase=="rest" else (s.event_choice("trade",s.offer_serial) if phase=="event" else s.buy_shop("heal"))
  check(accepted,"legal transaction "+phase)
  check(s.character_id=="noa" and s.charge==1 and s.charge_required==2 and s.ash_reserved and s.actions==0 and s.skill_uses==0,"noncombat carry "+phase)
 var s=fixed("event",2)
 check(not s.event_choice("trade",s.offer_serial) and s.gold==2 and s.relics.size()==2,"insufficient event unchanged")
 check(not s.event_choice("supplies",s.offer_serial+1) and s.gold==2,"stale event unchanged")
 s=fixed("event",3);check(s.event_choice("trade",s.offer_serial) and s.gold==0 and s.relics==["pigment","lens","ash"],"exact event funds")
 check(not s.event_choice("supplies",s.offer_serial) and s.gold==0,"double event cannot claim free branch")
 s=fixed("event",3);s.relics=["pigment","lens","ash"]
 check(not s.event_choice("trade",s.offer_serial) and s.gold==3,"exhausted event no fee")
 check(s.event_choice("supplies",s.offer_serial) and s.gold==5,"exhausted event free option remains")
 s=fixed("rest",3,29);check(s.rest_choice("heal",s.offer_serial) and s.gold==0 and s.hp==30,"exact rest cost capped1")
 check(not s.rest_choice("heal",s.offer_serial),"rest once")
 s=fixed("shop",8);check(s.buy_shop("relic") and s.gold==0 and s.relics.size()==3,"exact shop funds acquires third relic")
 check(not s.buy_shop("relic") and s.gold==0,"shop double purchase inert")
 check(s.leave_shop() and s.phase=="map" and not s.leave_shop(),"shop exit once")
 s=fixed("shop",0);var serial:int=s.offer_serial
 check(not s.buy_shop("heal") and not s.buy_shop("relic") and s.gold==0,"poor shop mutations rejected")
 check(s.leave_shop() and s.gold_spent==0 and s.relics.size()==2,"shop no purchase allowed")
 check(not s.select_node("shop",s.offer_serial),"shop cannot reopen after leave")
 print("AREA_TRANSACTIONS checks=",checks," failures=",failures);quit(1 if failures else 0)

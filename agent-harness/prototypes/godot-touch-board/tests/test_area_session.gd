extends SceneTree
const AreaPath="res://scripts/board_area_session.gd"
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func board()->Array:
 return [{"id":1,"kind":"normal","color":0,"radius":37.0,"pos":Vector2(150,450)},{"id":2,"kind":"normal","color":0,"radius":37.0,"pos":Vector2(224,450)}]
func settled_win(s)->void:
 # Explicit low-HP unit fixture; three real clear commits own payout timing.
 s.combat.enemy_hp=1;s.combat.shield_hp=0
 for action in range(3):
  s.panels=board();s.begin(s.panels[0].pos,0);s.release(s.panels[0].pos,0)
  s.finish_refill()
  if action<2:check(s.phase=="ready" and s.combat.enemy_hp==1,"area reward waits for third-clear attack")
  else:
   check(s.phase=="player_attack","area third clear begins player attack")
   s.finish_player_attack()
   check(s.phase=="player_impact","area reward waits for impact hold")
   s.finish_player_impact()
func _initialize()->void:
 check(ResourceLoader.exists(AreaPath),"area orchestration exists")
 if not ResourceLoader.exists(AreaPath):print("AREA checks=",checks," failures=",failures);quit(1);return
 var s=load(AreaPath).new();s.initialize_board(board(),3);s.open_departure();s.select_departure("noa",s.offer_serial);s.start_departure(s.offer_serial)
 check(s.phase=="map" and s.allowed_nodes()==["entry"],"departure opens bounded map")
 check(not s.select_node("boss",s.offer_serial),"cannot skip to boss")
 check(s.select_node("entry",s.offer_serial),"entry candidate")
 var serial:int=s.offer_serial
 check(s.enter_node(serial,board(),3) and s.phase=="ready" and s.character_id=="noa","explicit entry starts normal battle")
 check(not s.enter_node(serial,board(),3),"entry only once")
 # Explicit lethal fixture tests accounting, not normal earned-run evidence.
 settled_win(s)
 check(s.phase=="reward" and s.gold==4,"first victory pays and offers relic")
 var gold:int=s.gold;s.finish_refill();check(s.gold==gold,"duplicate completion cannot repay")
 check(s.choose_relic("pigment",s.offer_serial) and s.phase=="map","earned reward returns map")
 check(not s.select_node("entry",s.offer_serial) and s.allowed_nodes()==["rest","event"],"no backtracking")
 s.select_node("event",s.offer_serial);s.enter_node(s.offer_serial)
 var charge:int=s.charge
 check(s.event_relic()=="lens" and s.event_choice("trade",s.offer_serial),"paid event names and gives unowned relic")
 check(s.gold==1 and s.relics==["pigment","lens"] and s.charge==charge and s.phase=="map","event preserves other resources")
 check(not s.event_choice("supplies",s.offer_serial),"event choices mutually exclusive")
 check(s.has_method("reachable_nodes"),"map distinguishes future from abandoned branches")
 if s.has_method("reachable_nodes"):check("rest" not in s.reachable_nodes() and "boss" in s.reachable_nodes(),"unchosen earlier branch is closed")
 s.select_node("elite",s.offer_serial);s.enter_node(s.offer_serial,board(),3)
 check(s.combat.enemy_hp==44 and s.route=="elite" and s.character_id=="noa","elite uses unchanged pattern and carried hero")
 settled_win(s);s.choose_relic("ash",s.offer_serial)
 check(s.gold==9 and s.relics.size()==3,"second victory carry")
 s.select_node("extra",s.offer_serial);s.enter_node(s.offer_serial,board(),3)
 settled_win(s)
 check(s.phase=="spoils" and s.gold==21 and s.relic_fallbacks==1,"exhausted relic pays8+4 once")
 s.finish_refill();check(s.gold==21,"fallback cannot duplicate")
 s.confirm_spoils(s.offer_serial);check(s.phase=="map" and s.allowed_nodes()==["shop","boss"],"extra remains optional and forward")
 s.select_node("shop",s.offer_serial);s.enter_node(s.offer_serial)
 check(not s.buy_shop("relic") and s.gold==21,"no phantom fourth relic")
 s.hp=28
 check(s.buy_shop("heal") and s.hp==30 and s.gold==17,"shop capped heal exact cost")
 check(not s.buy_shop("heal"),"shop stock once")
 s.leave_shop();check(s.phase=="map" and s.allowed_nodes()==["boss"],"shop leave cannot reopen")
 s.select_node("boss",s.offer_serial);s.enter_node(s.offer_serial,board(),3)
 check(s.combat.enemy_hp==48 and s.hp==30 and s.charge==charge,"boss exact existing values and carry")
 settled_win(s);check(s.phase=="victory" and s.gold==17,"terminal boss no gold")
 # Independent rest/event boundary fixtures keep their names explicit.
 for hp in [20,28,30]:
  var a=load(AreaPath).new();a.current_node="entry";a.phase="map";a.character_id="rio";a.gold=4;a.hp=hp
  a.select_node("rest",a.offer_serial);a.enter_node(a.offer_serial)
  var accepted:bool=a.rest_choice("heal",a.offer_serial)
  check(accepted==(hp<30) and a.hp==mini(30,hp+8) and a.gold==(1 if hp<30 else 4),"rest cap/no-charge at HP"+str(hp))
  if not accepted:check(a.rest_choice("leave",a.offer_serial),"full HP can leave free")
 var a=load(AreaPath).new();a.current_node="entry";a.phase="map";a.gold=0;a.hp=12
 a.select_node("rest",a.offer_serial);a.enter_node(a.offer_serial)
 check(not a.rest_choice("heal",a.offer_serial) and a.hp==12 and a.gold==0,"no funds cannot mutate rest")
 check(a.rest_choice("leave",a.offer_serial),"poor player can leave")
 a=load(AreaPath).new();a.current_node="entry";a.phase="map";a.gold=4
 a.select_node("event",a.offer_serial);a.enter_node(a.offer_serial)
 check(a.event_choice("supplies",a.offer_serial) and a.gold==6 and a.relics.is_empty(),"free event branch pays2 instead of relic")
 print("AREA checks=",checks," failures=",failures);quit(1 if failures else 0)

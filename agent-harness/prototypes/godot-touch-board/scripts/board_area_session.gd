extends "res://scripts/board_run_session.gd"
## One forward-only area. Existing combat/rules/charge own every puzzle action.
const NODES={
 "entry":{"name":"입구 표적","kind":"fight","fight":0,"gold":4},
 "rest":{"name":"휴식","kind":"rest"},
 "event":{"name":"촉매 거래","kind":"event"},
 "safe":{"name":"안전 전투","kind":"fight","fight":1,"route":"safe","gold":4},
 "elite":{"name":"정예 전투","kind":"fight","fight":1,"route":"elite","gold":8},
 "extra":{"name":"추가 정예","kind":"fight","fight":1,"route":"elite","gold":8},
 "shop":{"name":"작은 상점","kind":"shop"},
 "boss":{"name":"결정룡","kind":"fight","fight":2,"gold":0},
}
const EDGES={"start":["entry"],"entry":["rest","event"],"rest":["safe","elite"],"event":["safe","elite"],"safe":["shop","extra","boss"],"elite":["shop","extra","boss"],"extra":["shop","boss"],"shop":["boss"]}
var area_mode:=true
var current_node:="start"
var selected_node:=""
var visited:Dictionary={}
var history:Array=[]
var paid_nodes:Dictionary={}
var relic_fallbacks:=0
var reward_notice:=""
var battles_entered:=0

func start_departure(serial:int)->bool:
 if not super.start_departure(serial):return false
 phase="map"
 return true

func allowed_nodes()->Array:
 var result:Array=[]
 if phase!="map":return result
 for id in EDGES.get(current_node,[]):
  if not visited.has(id):result.append(id)
 return result

func select_node(id:String,serial:int)->bool:
 if serial!=offer_serial or id not in allowed_nodes():return false
 selected_node=id;cancel();offer_serial+=1
 return true

func enter_node(serial:int,fresh_panels:Array=[],fresh_next_id:int=0)->bool:
 if serial!=offer_serial or selected_node not in allowed_nodes():return false
 var id:=selected_node
 var node:Dictionary=NODES[id]
 if node.kind=="fight" and fresh_panels.is_empty():return false
 current_node=id;selected_node="";visited[id]=true;history.append(id)
 cancel();skill_mode=false;offer_serial+=1
 if node.kind=="fight":
  panels=fresh_panels.duplicate(true);next_id=fresh_next_id
  if id in ["safe","elite"]:route=id
  combat.start_fight(node.fight,panels,node.get("route","safe"))
  if id=="extra":combat.enemy_name="추가 정예 수호자"
  battles_entered+=1;phase="ready"
 else:phase=node.kind
 return true

func _complete_node()->void:
 cancel();skill_mode=false;selected_node="";phase="map";offer_serial+=1

func finish_refill()->void:
 if phase!="busy":return
 cancel();skill_mode=false
 var outcome:String=combat.resolve()
 if outcome=="win":
  if current_node=="boss":phase="victory";return
  if paid_nodes.has(current_node):_complete_node();return
  paid_nodes[current_node]=true
  gold+=int(NODES[current_node].gold)
  reward_options=Relics.available(relics)
  offer_serial+=1
  if reward_options.is_empty():
   gold+=4;relic_fallbacks+=1;reward_notice="유물 칸 가득 · 대체 보상 +4 G";phase="spoils"
  else:
   reward_round+=1;phase="reward"
 elif outcome=="attack":
  hp=maxi(0,hp-combat.take_attack());phase="enemy_attack"
 else:phase="ready"

func choose_relic(id:String,serial:int)->bool:
 if phase!="reward" or serial!=offer_serial or id not in reward_options or id in relics:return false
 relics.append(id);rewards_taken+=1;reward_options=[];_complete_node();return true

func confirm_spoils(serial:int)->bool:
 if phase!="spoils" or serial!=offer_serial:return false
 _complete_node();return true

func rest_gain()->int:return mini(8,maxi(0,max_hp-hp))

func rest_choice(id:String,serial:int)->bool:
 if phase!="rest" or serial!=offer_serial:return false
 if id=="heal":
  if gold<3 or rest_gain()==0:return false
  gold-=3;gold_spent+=3;hp+=rest_gain()
 elif id!="leave":return false
 _complete_node();return true

func event_relic()->String:
 var available:Array=Relics.available(relics)
 return String(available[0]) if not available.is_empty() else ""

func event_choice(id:String,serial:int)->bool:
 if phase!="event" or serial!=offer_serial:return false
 if id=="trade":
  var relic:=event_relic()
  if gold<3 or relic=="":return false
  gold-=3;gold_spent+=3;relics.append(relic)
 elif id=="supplies":gold+=2
 else:return false
 _complete_node();return true

func leave_shop()->bool:
 if not super.leave_shop():return false
 _complete_node();return true

func choose_route(_id:String)->bool:return false
func begin_next_fight(_fresh:Array,_next:int)->bool:return false

func route_summary()->String:
 var names:Array[String]=[]
 for id in history:
  if id not in ["entry","boss"]:names.append(NODES[id].name)
 return " · ".join(names)

func reachable_nodes()->Array:
 var found:Array=[]
 var pending:Array=[current_node]
 while not pending.is_empty():
  var source:String=pending.pop_front()
  for id in EDGES.get(source,[]):
   if id not in found and not visited.has(id):found.append(id);pending.append(id)
 return found

extends RefCounted
## Local-only, explicit schema. Objects are never deserialized.
const Area=preload("res://scripts/board_area_session.gd")
const VERSION=1
const LIMIT=2097152
const STABLE=["ready","map","reward","rest","event","shop","spoils"]
const FIELDS=["character_id","skill_uses","panels","hp","max_hp","damage_total","actions","charge","charge_required","ash_reserved","relics","reward_options","reward_round","rewards_taken","offer_serial","summary_shown","stats","phase","skill_color","next_id","route","gold","gold_spent","shop_heal_sold","shop_relic_sold","shop_closed","_paid_encounters","departure_choice","departure_started","current_node","selected_node","visited","history","paid_nodes","relic_fallbacks","reward_notice","battles_entered"]
const COMBAT=["route","encounter","enemy_hp","enemy_max_hp","enemy_name","turn","actions_in_turn","incoming_damage","mitigation_active","mitigation_success","fallback_plain","enemies_defeated","last_attack_damage","attacks_total","_turn_prepared","_attack_taken","_victory_counted","weak_color","intent","intent_serial"]
var directory:String
var error:=""
func _init(path:String="user://chroma-checkpoint"):
 directory=ProjectSettings.globalize_path(path)
static func capture(view)->Dictionary:
 var s={};var c={}
 for key in FIELDS:s[key]=view.session.get(key)
 for key in COMBAT:c[key]=view.session.combat.get(key)
 return {"seed":view.run_seed,"rng":view.rng.state,"particle_rng":view.particle_rng.state,"session":s.duplicate(true),"combat":c,"muted":view.sound.muted,"reduced":view.reduced_effects}
static func safe_tree(value,depth:int=0)->bool:
 if depth>12:return false
 match typeof(value):
  TYPE_NIL,TYPE_BOOL,TYPE_INT:return true
  TYPE_FLOAT:return is_finite(value)
  TYPE_STRING,TYPE_STRING_NAME:return String(value).length()<4096
  TYPE_VECTOR2:return value.is_finite()
  TYPE_ARRAY:
   if value.size()>512:return false
   for item in value:
    if not safe_tree(item,depth+1):return false
   return true
  TYPE_DICTIONARY:
   if value.size()>512:return false
   for key in value:
    if typeof(key) not in [TYPE_INT,TYPE_STRING,TYPE_STRING_NAME] or not safe_tree(value[key],depth+1):return false
   return true
 return false
static func fields_valid(data:Dictionary,keys:Array,defaults)->bool:
 if data.size()!=keys.size():return false
 for key in keys:
  if not data.has(key) or typeof(data[key])!=typeof(defaults.get(key)):return false
 return true
static func valid(data)->bool:
 if not data is Dictionary or data.size()!=7 or not safe_tree(data):return false
 for k in ["seed","rng","particle_rng"]:
  if typeof(data.get(k))!=TYPE_INT:return false
 for k in ["muted","reduced"]:
  if typeof(data.get(k))!=TYPE_BOOL:return false
 if not data.get("session") is Dictionary or not data.get("combat") is Dictionary:return false
 var s:Dictionary=data.session;var c:Dictionary=data.combat;var defaults=Area.new()
 if not fields_valid(s,FIELDS,defaults) or not fields_valid(c,COMBAT,defaults.combat):return false
 if s.phase not in STABLE or s.character_id not in ["rio","noa"] or s.departure_choice!=s.character_id or not s.departure_started:return false
 if s.max_hp!=30 or s.hp<1 or s.hp>30 or s.charge_required not in [2,3] or s.charge<0 or s.charge>s.charge_required or s.skill_color not in range(4):return false
 for k in ["skill_uses","damage_total","actions","reward_round","rewards_taken","offer_serial","gold","gold_spent","relic_fallbacks","battles_entered"]:
  if s[k]<0 or s[k]>1000000:return false
 if s.next_id<1 or s.next_id>10000000 or s.rewards_taken>3 or s.relics.size()>3 or s.reward_options.size()>3:return false
 for list in [s.relics,s.reward_options]:
  var unique={}
  for id in list:
   if id not in ["pigment","lens","ash"] or unique.has(id):return false
   unique[id]=true
 if s.phase=="reward":
  if s.reward_options!=defaults.Relics.available(s.relics) or s.reward_options.is_empty():return false
 elif not s.reward_options.is_empty():return false
 if s.stats.size()!=3:return false
 for stat in s.stats:
  if not stat is Dictionary or stat.size()!=3:return false
  for key in ["actions","removed","cores"]:
   if typeof(stat.get(key))!=TYPE_INT or stat[key]<0 or stat[key]>1000000:return false
 if s.panels.size()!=48:return false
 var ids={}
 for p in s.panels:
  if not p is Dictionary:return false
  for key in p:
   if key not in ["id","kind","color","pos","radius","from","vel","anchored","contact_count"]:return false
  if typeof(p.get("id"))!=TYPE_INT or p.id<1 or p.id>=s.next_id or ids.has(p.id):return false
  ids[p.id]=true
  if typeof(p.get("color"))!=TYPE_INT or p.get("kind") not in ["normal","heart","core","strong","bomb","big_bomb"]:return false
  if (p.kind=="heart" and p.color!=4) or (p.kind!="heart" and p.color not in range(4)):return false
  if typeof(p.get("pos"))!=TYPE_VECTOR2 or not Rect2(29,289,662,532).has_point(p.pos):return false
  if typeof(p.get("radius")) not in [TYPE_FLOAT,TYPE_INT] or p.radius!=(48.0 if p.kind=="big_bomb" else 37.0):return false
  for k in ["from","vel"]:
   if p.has(k) and typeof(p[k])!=TYPE_VECTOR2:return false
  if p.has("anchored") and typeof(p.anchored)!=TYPE_BOOL:return false
  if p.has("contact_count") and (typeof(p.contact_count)!=TYPE_INT or p.contact_count<0):return false
 if s.route not in ["","safe","elite"] or not s._paid_encounters.is_empty():return false
 var node="start";var visited={}
 for id in s.history:
  if not id is String or id not in defaults.EDGES.get(node,[]) or visited.has(id):return false
  visited[id]=true;node=id
 if s.current_node!=node or s.visited!=visited:return false
 var fights=0
 for id in s.history:
  if defaults.NODES[id].kind=="fight":fights+=1
 if s.battles_entered!=fights or s.rewards_taken>s.relics.size():return false
 if s.reward_round!=s.rewards_taken+(1 if s.phase=="reward" else 0):return false
 if s.selected_node!="" and (s.phase!="map" or s.selected_node not in defaults.EDGES.get(node,[])):return false
 for id in s.paid_nodes:
  if not visited.has(id) or defaults.NODES[id].kind!="fight" or id=="boss" or s.paid_nodes[id]!=true:return false
 if s.phase in ["ready","reward","spoils"] and (node=="start" or defaults.NODES[node].kind!="fight"):return false
 if s.phase in ["rest","event","shop"] and (node=="start" or defaults.NODES[node].kind!=s.phase):return false
 if s.phase in ["reward","spoils"] and (not s.paid_nodes.has(node) or c.enemy_hp!=0 or not c._victory_counted):return false
 if s.phase=="spoils" and s.relics.size()!=3:return false
 if s.phase=="ready" and c.encounter!=defaults.NODES[node].fight:return false
 if c.route not in ["safe","elite"] or c.encounter not in range(3) or c.weak_color not in range(4) or c.intent not in ["plain","direct4","slam"]:return false
 if c.enemy_max_hp not in [24,36,44,48] or c.enemy_hp<0 or c.enemy_hp>c.enemy_max_hp or c.actions_in_turn not in range(4):return false
 for k in ["turn","incoming_damage","enemies_defeated","last_attack_damage","attacks_total","intent_serial"]:
  if c[k]<0 or c[k]>1000000:return false
 if c.incoming_damage not in [3,4,5,6,7,8,10] or not c._turn_prepared:return false
 if s.phase=="ready" and (c.enemy_hp<=0 or c._attack_taken or c.actions_in_turn>=3):return false
 return true
static func restore(view,data:Dictionary)->void:
 var restored=Area.new()
 for key in FIELDS:restored.set(key,data.session[key].duplicate(true) if data.session[key] is Array or data.session[key] is Dictionary else data.session[key])
 for key in COMBAT:restored.combat.set(key,data.combat[key])
 view.session=restored;view.run_seed=data.seed
 view.rng.seed=data.seed;view.rng.state=data.rng
 view.particle_rng.seed=data.seed ^ 0x514C495459;view.particle_rng.state=data.particle_rng
 view.sound.muted=data.muted;view.reduced_effects=data.reduced
 view.quality_fx.reduced_effects=data.reduced;view.feedback.reduced_effects=data.reduced
 view.visual=restored.panels.duplicate(true)
 view.cancel_input();view.primary_touch=-99
static func checksum(bytes:PackedByteArray)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
static func encode(data:Dictionary)->String:
 var bytes=var_to_bytes(data)
 return JSON.stringify({"version":VERSION,"sha256":checksum(bytes),"payload":Marshalls.raw_to_base64(bytes)})
func read_file(path:String)->Dictionary:
 if not FileAccess.file_exists(path):return {"ok":false,"reason":"missing"}
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:return {"ok":false,"reason":"read"}
 if f.get_length()>LIMIT:return {"ok":false,"reason":"size"}
 var parser=JSON.new();var parse_error=parser.parse(f.get_as_text());f.close()
 if parse_error!=OK:return {"ok":false,"reason":"format"}
 var envelope=parser.data
 if not envelope is Dictionary or envelope.get("version")!=VERSION:return {"ok":false,"reason":"version/format"}
 if not envelope.get("payload") is String or not envelope.get("sha256") is String:return {"ok":false,"reason":"envelope"}
 var bytes=Marshalls.base64_to_raw(envelope.payload)
 if checksum(bytes)!=envelope.sha256:return {"ok":false,"reason":"checksum"}
 var data=bytes_to_var(bytes)
 if not valid(data):return {"ok":false,"reason":"schema"}
 return {"ok":true,"data":data}
func load_run()->Dictionary:
 if FileAccess.file_exists(directory.path_join("closed")):return {"ok":false,"closed":true,"reason":"completed"}
 var current=read_file(directory.path_join("current.json"))
 if current.ok:current["recovered"]=false;return current
 var backup=read_file(directory.path_join("backup.json"))
 if backup.ok:backup["recovered"]=true;return backup
 return {"ok":false,"reason":current.reason,"exists":DirAccess.dir_exists_absolute(directory)}
func atomic_text(name:String,text:String)->bool:
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="저장 폴더를 만들 수 없습니다";return false
 var path=directory.path_join(name);var tmp=path+".tmp"
 var f=FileAccess.open(tmp,FileAccess.WRITE)
 if f==null:error="저장 파일을 쓸 수 없습니다";return false
 f.store_string(text);f.flush();var code=f.get_error();f.close()
 if code!=OK:error="저장 쓰기 실패";return false
 if FileAccess.get_file_as_string(tmp)!=text:error="저장 확인 실패";return false
 if DirAccess.rename_absolute(tmp,path)!=OK:error="저장 교체 실패";return false
 return true
func save(data:Dictionary)->bool:
 error=""
 if not valid(data):error="저장 상태 검증 실패";return false
 if FileAccess.file_exists(directory.path_join("closed")):error="종료된 탐험은 저장할 수 없습니다";return false
 var old=read_file(directory.path_join("current.json"))
 if old.ok:
  if not atomic_text("backup.json",encode(old.data)):return false
 elif FileAccess.file_exists(directory.path_join("current.json")):
  # Preserve invalid bytes before replacing only after explicit recovery.
  if DirAccess.rename_absolute(directory.path_join("current.json"),directory.path_join("invalid-"+str(Time.get_ticks_usec())+".json"))!=OK:error="손상 파일 보관 실패";return false
 return atomic_text("current.json",encode(data))
func close_run()->bool:
 error=""
 return atomic_text("closed","completed\n")
func archive()->bool:
 error=""
 if not DirAccess.dir_exists_absolute(directory):return true
 var destination=directory+"-archive-"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(Time.get_ticks_usec())
 if DirAccess.rename_absolute(directory,destination)!=OK:error="이전 저장 보관 실패";return false
 return true

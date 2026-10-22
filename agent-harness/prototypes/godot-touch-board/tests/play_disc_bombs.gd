extends "res://tests/capture_elemental.gd"
## Actual default main scene and legal automated input; never injects resources,
## boards, charge or phases. Captures include decision/screenshot overhead.
var path_choice:="risk"
var no_shots:=false
var event_free:=false
func snapshot(name:String)->void:
 if not no_shots:await super.snapshot(name)
func state()->Dictionary:
 var result:Dictionary=super.state()
 result["panels"]=scene.session.panels.duplicate(true)
 result["node"]=scene.session.current_node
 result["history"]=scene.session.history.duplicate()
 result["fallbacks"]=scene.session.relic_fallbacks
 return result
func choose_node(id:String)->void:
 var index:int=scene.AreaUI.ORDER.find(id)
 await gesture(scene.AreaUI.node_rect(index).get_center(),.12)
 if scene.session.selected_node!=id:errors.append("node candidate unavailable: "+id);return
 await snapshot("map-"+id)
 await create_timer(.55).timeout
 await gesture(scene.AreaUI.ENTER.get_center(),.12)
 record("node_enter",{"id":id})
 await create_timer(.55).timeout
func gesture(point:Vector2,hold:float=.35)->Dictionary:
 scene.press(point,-1)
 var plan:Dictionary=scene.session.selection.duplicate(true)
 if plan.get("valid",false) and not plan.get("blasts",[]).is_empty():
  await snapshot("bomb-preview-%02d"%(clear_count+1));hold=maxf(hold,.85)
 await create_timer(hold).timeout
 scene.release(point,-1)
 return plan
func record(type:String,details:Dictionary={}) -> void:
 if type=="clear":
  details["blasts"]=scene.active_plan.get("blasts",[]).duplicate(true)
  details["activated"]=scene.active_plan.get("activated",[]).duplicate()
  details["bomb_supply"]=scene.active_plan.get("bomb_spawn_kind","")
  details["bomb_supply_color"]=scene.active_plan.get("bomb_spawn_color",-1)
 super.record(type,details)
func run()->void:
 impact_mode=true
 movie="--capture" in OS.get_cmdline_user_args()
 var args:=OS.get_cmdline_user_args()
 for arg in args:
  if arg.begins_with("--hero="):hero=arg.substr(7)
  if arg.begins_with("--path-choice="):path_choice=arg.substr(14)
  if arg=="--attrition":selected_policy="attrition"
  if arg=="--no-shots":no_shots=true
  if arg=="--event-free":event_free=true
 route_choice="elite" if path_choice=="risk" else "safe"
 output_dir="res://evidence/disc-bombs/normal/%s-%s-%s-%s"%[hero,path_choice,selected_policy,"movie" if movie else "live"]+("-free" if event_free else "")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
 began_us=Time.get_ticks_usec();scene=load("res://main.tscn").instantiate();root.add_child(scene)
 await process_frame
 await snapshot("departure");await create_timer(.5).timeout
 await gesture(scene.UI.character_rect(0 if hero=="rio" else 1).get_center(),.12)
 await gesture(scene.UI.DEPART.get_center(),.12)
 await snapshot("initial-map");await create_timer(1.0).timeout
 while errors.is_empty() and scene.session.phase not in ["victory","defeat"] and clear_count<140:
  var s=scene.session
  match s.phase:
   "map":
    var id:String=""
    match s.current_node:
     "start":id="entry"
     "entry":id="event" if path_choice=="risk" else "rest"
     "event","rest":id=route_choice
     "safe","elite":id="extra" if path_choice=="risk" else ("shop" if path_choice=="safe-shop" else "boss")
     "extra":id="shop"
     "shop":id="boss"
    await choose_node(id)
   "rest","event":
    await snapshot(s.phase+"-offer");await create_timer(1.2).timeout
    var index:int=0 if s.phase=="event" and not event_free and s.gold>=3 and s.event_relic()!="" else (0 if s.phase=="rest" and s.gold>=3 and s.rest_gain()>0 else 1)
    var before:Dictionary=state()
    await gesture(scene.AreaUI.option_rect(index).get_center())
    if s.phase!="map":errors.append("node transaction did not complete")
    record("node_choice",{"option":index,"before":before})
   "reward":
    await snapshot("reward-%d"%s.reward_round);await create_timer(1.2).timeout
    var id:String=s.reward_options[0]
    await gesture(scene.UI.reward_rect(0,s.reward_options.size()).get_center())
    record("reward_chosen",{"id":id})
   "spoils":
    await snapshot("relic-exhausted");await create_timer(1.3).timeout
    var before:int=s.gold
    await gesture(scene.AreaUI.ENTER.get_center())
    if s.phase!="map" or s.gold!=before:errors.append("fallback confirmation duplicated reward")
    record("fallback_confirmed")
   "shop":
    await snapshot("shop-offer");await create_timer(1.2).timeout
    if path_choice=="risk":
     for item in ["relic","heal"]:
      var eligible:bool=s.gold>=(8 if item=="relic" else 4) and (s.shop_remaining_relic()!="" if item=="relic" else s.shop_heal_gain()>0)
      if eligible:
       await gesture(scene.UI.shop_rect(1 if item=="relic" else 0).get_center())
       record("shop_purchase",{"item":item})
    await snapshot("shop-exit");await gesture(scene.UI.SUMMARY_CONTINUE.get_center())
    record("shop_exit")
   "ready":
    var chosen:Dictionary=best_clear()
    if (selected_policy!="attrition" or s.skill_uses==0) and s.charge>=s.charge_required and (chosen.is_empty() or chosen.plan.damage<s.combat.enemy_hp):
     var skill:Dictionary=best_skill()
     if not skill.is_empty():await use_skill(skill);chosen=best_clear()
    if chosen.is_empty():errors.append("no legal normal clear");break
    var before:Dictionary=state()
    var preview:Dictionary=await gesture(scene.board_to_screen(chosen.point),.12)
    if preview!=scene.active_plan or s.actions!=before.actions+1:errors.append("preview/commit mismatch");break
    clear_count+=1
    record("clear",{"start_id":chosen.id,"damage":preview.damage,"removed":preview.removed,"before":before})
    await wait_resolution()
    if s.phase=="ready":await create_timer(.12).timeout
   _:errors.append("unexpected area phase: "+s.phase)
 var terminal:Dictionary=state()
 await snapshot(terminal.phase);await create_timer(1.6).timeout
 if terminal.phase in ["victory","defeat"]:
  await gesture(scene.UI.SUMMARY_CONTINUE.get_center())
  if scene.session.phase!="departure" or not scene.session.history.is_empty():errors.append("result failed fresh departure")
  await snapshot("returned");await create_timer(1.1).timeout
 var result:Dictionary={"method":"Actual default area main, automated legal press/release, normal initializer, natural refill. No HP/gold/charge/board injection; not human feel/device/performance evidence.","hero":hero,"path":path_choice,"policy":selected_policy,"event_free":event_free,"movie":movie,"no_fixtures":true,"errors":errors,"terminal":terminal,"returned":scene.session.phase=="departure","events":events,"timings":scene.timings,"screenshots":snapshots}
 FileAccess.open(output_dir.path_join("trace.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("AREA_NORMAL ",hero," ",path_choice," ",selected_policy," terminal=",terminal.phase," clears=",terminal.actions," HP=",terminal.hp," history=",terminal.history," errors=",errors)
 quit(0 if errors.is_empty() and terminal.phase in ["victory","defeat"] else 1)

func wait_resolution() -> void:
 var deadline := Time.get_ticks_msec()+120000
 var attack_recorded := false
 var hit_recorded := false
 var falling_saved := false
 while scene.session.phase in ["busy","enemy_attack"]:
  if Time.get_ticks_msec() > deadline:
   errors.append("natural animation/refill exceeded safety deadline")
   return
  if impact_mode and not hit_recorded and scene.session.phase=="busy":
   var remaining=scene.quality_fx.get("impact_remaining")
   if (remaining!=null and remaining>0.2) or (remaining==null and scene.falling):
    hit_recorded=true
    record("hit_visual",{"canonical_hp":scene.session.combat.enemy_hp,"shown_hp":scene.quality_fx.display_enemy_hp(scene.session.combat.enemy_hp) if remaining!=null else scene.session.combat.enemy_hp})
    await snapshot("hit-%02d"%clear_count)
  if scene.falling and not falling_saved:
   for panel in scene.visual:
    if panel.kind in ["bomb","big_bomb"] and panel.get("vel",Vector2.ZERO).length()>30 and panel.pos.y>scene.BOARD.position.y+52:
     falling_saved=true
     record("falling_bomb",{"id":panel.id,"kind":panel.kind,"color":panel.color,"position":panel.pos,"physical_radius":panel.radius,"visual_radius":scene.PanelView.visual_radius(panel)})
     await snapshot("falling-%02d"%clear_count)
     break
  if scene.session.phase == "enemy_attack" and not attack_recorded:
   attack_recorded = true
   saw_attack = true
   record("enemy_attack")
   await snapshot("attack-%02d"%scene.session.combat.attacks_total)
  await process_frame
 record("resolved")
 if scene.session.phase == "stalled":
  errors.append("natural refill stalled; no board rescue attempted")

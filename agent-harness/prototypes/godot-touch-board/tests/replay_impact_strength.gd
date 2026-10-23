extends SceneTree
## Recorded ordinary area inputs; no policy search, fixture injection or writes
## inside timed windows. Movie/screenshot mode is explicitly separate.
var scene
var output:=""
var movie:=false
var limit:=10
var errors:Array=[]
var rows:Array=[]
var frames:Array=[]
var active:=false
var viewport_rid:RID
var cmd_index:=0
var clear_count:=0
var current:Dictionary={}
var started_us:=0
var frame_before:=0
var impact_saved:=false
var snapshots:Array=[]
func _initialize()->void:call_deferred("run")
func state()->Dictionary:
 var s=scene.session
 return {"phase":s.phase,"node":s.current_node,"hp":s.hp,"gold":s.gold,"charge":s.charge,"requirement":s.charge_required,"ash":s.ash_reserved,"relics":s.relics.duplicate(),"actions":s.actions,"enemy_hp":s.combat.enemy_hp,"intent":s.combat.damage_context(),"rng":scene.rng.state,"panels":s.panels.duplicate(true)}
func after_frame()->void:
 if active and not movie:
  frames.append({"action":clear_count,"frame":Engine.get_process_frames(),"wall_us":Time.get_ticks_usec(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"cpu":scene.bench.duplicate()})
  scene.bench.clear()
func hold(n:int)->void:
 for i in range(n):await process_frame;await RenderingServer.frame_post_draw
func shot(name:String)->void:
 if not movie:return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.get_base_dir().path_join(name+".png"));snapshots.append(name)
func gesture(point:Vector2)->Dictionary:
 await process_frame
 var t:=Time.get_ticks_usec();scene.press(point,-1)
 var cpu:=Time.get_ticks_usec()-t
 await RenderingServer.frame_post_draw
 var draw:=Time.get_ticks_usec()-t
 var plan:Dictionary=scene.session.selection.duplicate(true)
 await hold(6)
 var release:=Time.get_ticks_usec();scene.release(point,-1)
 if not movie:rows.append({"event":"gesture","press_us":cpu,"draw_us":draw,"release_us":Time.get_ticks_usec()-release})
 return plan
func same_ids(a:Array,b:Array)->bool:
 if a.size()!=b.size():return false
 for i in range(a.size()):
  if int(a[i])!=int(b[i]):return false
 return true
func target(id:int)->Vector2:
 for p in scene.session.panels:
  if p.id==id:return scene.board_to_screen(p.pos)
 errors.append("missing ID "+str(id));return Vector2.INF
func resolve()->void:
 var deadline:=Time.get_ticks_msec()+30000
 while scene.session.phase in ["busy","enemy_attack"]:
  await process_frame;await RenderingServer.frame_post_draw
  if movie and not impact_saved and scene.quality_fx.impact_remaining>0:
   impact_saved=true;await shot("hit-%02d"%clear_count)
  if Time.get_ticks_msec()>deadline:errors.append("timeout");break
 if scene.session.phase=="stalled":errors.append("refill stall")
 rows.append({"event":"resolved","clear":clear_count,"plan":current,"state":state(),"wall_ms":(Time.get_ticks_usec()-started_us)/1000.0,"frames":Engine.get_process_frames()-frame_before})
 await hold(12 if not movie else 24)
func run()->void:
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--result="):output=a.substr(9)
  if a.begins_with("--limit="):limit=int(a.substr(8))
 movie="--capture" in OS.get_cmdline_user_args()
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 preload("res://tests/enter_adventure.gd").enter(scene,"noa")
 viewport_rid=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
 RenderingServer.frame_post_draw.connect(after_frame)
 await hold(30);scene.bench.clear();active=true
 var trace:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/impact_strength_commands.json"))
 for command in trace.events:
  if clear_count>=limit or not errors.is_empty():break
  var d:Dictionary=command.details
  match command.type:
   "node_enter":
    if d.id=="entry":continue
    await gesture(scene.AreaUI.node_rect(scene.AreaUI.ORDER.find(d.id)).get_center())
    await gesture(scene.AreaUI.ENTER.get_center());await hold(20)
   "skill":
    await gesture(scene.SKILL.get_center())
    var result:Dictionary=await gesture(target(int(d.start_id)))
    if not same_ids(result.get("targets",[]),d.targets):errors.append("skill mismatch")
    await hold(18)
   "clear":
    clear_count+=1;impact_saved=false
    current=await gesture(target(int(d.start_id)))
    if not same_ids(current.get("removed",[]),d.removed) or int(current.get("damage",-1))!=int(d.damage):errors.append("preview mismatch clear"+str(clear_count));break
    if current!=scene.active_plan:errors.append("commit mismatch");break
    started_us=Time.get_ticks_usec();frame_before=Engine.get_process_frames()
    await resolve()
   "reward_chosen":await gesture(scene.UI.reward_rect(scene.session.reward_options.find(d.id),scene.session.reward_options.size()).get_center());await hold(20)
   "node_choice":await gesture(scene.AreaUI.option_rect(int(d.option)).get_center());await hold(20)
   "fallback_confirmed":await gesture(scene.AreaUI.ENTER.get_center());await hold(20)
   "shop_purchase":await gesture(scene.UI.shop_rect(0 if d.item=="heal" else 1).get_center())
   "shop_exit":await gesture(scene.UI.SUMMARY_CONTINUE.get_center());await hold(20)
 await hold(30 if not movie else 60)
 active=false
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"errors":errors,"clears":clear_count,"movie":movie,"method":"Preloaded normal Noa area inputs; no search or fixture injection. No screenshots/files inside benchmark. Fixedfps capture separately labelled.","rows":rows,"frames":frames,"timings":scene.timings,"final":state(),"snapshots":snapshots},"  "))
 print("STRENGTH_REPLAY clears=",clear_count," errors=",errors)
 quit(0 if errors.is_empty() and clear_count==limit else 1)

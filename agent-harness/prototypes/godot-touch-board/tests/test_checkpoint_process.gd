extends "res://tests/capture_elemental.gd"
const Store=preload("res://scripts/board_checkpoint.gd")
func snapshot(_name:String)->void:pass
var steps=0
var output=""
var interrupted=""
var visited_phases=[]
func gesture(point:Vector2,hold:float=.01)->Dictionary:
 scene.press(point,-1)
 var result=scene.session.selection.duplicate(true)
 scene.release(point,-1)
 return result
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--steps="):steps=int(arg.trim_prefix("--steps="))
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg.begins_with("--interrupt="):interrupted=arg.trim_prefix("--interrupt=")
  if arg.begins_with("--hero="):hero=arg.trim_prefix("--hero=")
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 scene.record_timings=false
 if scene.lifecycle.modal=="resume":
  var before=scene.lifecycle.pending.duplicate(true)
  await gesture(scene.lifecycle.PRIMARY.get_center())
  if Store.capture(scene)!=before:errors.append("resume differs from checkpoint")
  scene.release(scene.UI.DEPART.get_center(),-1)
  if Store.capture(scene)!=before:errors.append("stale release changed resumed run")
  OS.delay_msec(510) # Same-point departing-button repeat guard.
 elif scene.lifecycle.modal!="":errors.append("unexpected lifecycle gate: "+scene.lifecycle.modal)
 else:preload("res://tests/enter_adventure.gd").enter(scene,hero)
 for i in range(steps):
  if not errors.is_empty():break
  var s=scene.session
  visited_phases.append(s.phase+":"+s.current_node)
  match s.phase:
   "ready":
    var chosen=best_clear()
    if s.charge>=s.charge_required and interrupted=="" and (chosen.is_empty() or chosen.plan.damage<s.combat.enemy_hp):
     var skill=best_skill()
     if not skill.is_empty():await use_skill(skill);continue
    if chosen.is_empty():errors.append("no legal clear");break
    var at=scene.board_to_screen(chosen.point)
    if interrupted=="held":scene.press(at,-1);break
    await gesture(at)
    if interrupted=="busy":break
    if interrupted=="attack":
     while s.phase=="busy":await process_frame
     if s.phase=="enemy_attack":break
    await wait_resolution()
   "reward":await gesture(scene.UI.reward_rect(0,s.reward_options.size()).get_center())
   "map":
    var next="entry"
    match s.current_node:
     "entry":next="event"
     "event","rest":next="elite"
     "elite","safe":next="extra"
     "extra":next="shop"
     "shop":next="boss"
    await gesture(scene.AreaUI.node_rect(scene.AreaUI.ORDER.find(next)).get_center())
    await gesture(scene.AreaUI.ENTER.get_center())
    OS.delay_msec(510)
   "event":await gesture(scene.AreaUI.option_rect(1).get_center())
   "rest":await gesture(scene.AreaUI.option_rect(1).get_center())
   "shop":
    if not s.shop_heal_sold and s.shop_heal_gain()>0 and s.gold>=4:await gesture(scene.UI.shop_rect(0).get_center())
    elif not s.shop_relic_sold and s.shop_remaining_relic()!="" and s.gold>=8:await gesture(scene.UI.shop_rect(1).get_center())
    else:await gesture(scene.UI.SUMMARY_CONTINUE.get_center())
   "spoils":await gesture(scene.AreaUI.ENTER.get_center())
   "victory","defeat":break
   _:errors.append("unexpected "+s.phase)
  if scene.lifecycle.error!="":errors.append(scene.lifecycle.error)
 var loaded=scene.lifecycle.store.load_run()
 if scene.session.phase in Store.STABLE and interrupted=="" and (not loaded.ok or loaded.data!=Store.capture(scene)):errors.append("stable live/save mismatch")
 var result={"errors":errors,"phase":scene.session.phase,"seed":scene.run_seed,"actions":scene.session.actions,"visited":visited_phases,"checkpoint":loaded,"data":Store.capture(scene)}
 FileAccess.open(output,FileAccess.WRITE).store_string(Store.encode(result))
 # A plain summary accompanies the exact binary-preserving state for orchestration.
 FileAccess.open(output+".summary.json",FileAccess.WRITE).store_string(JSON.stringify({"errors":errors,"phase":scene.session.phase,"seed":scene.run_seed,"actions":scene.session.actions,"visited":visited_phases,"state_hash":Store.checksum(var_to_bytes(result.data)),"saved_hash":Store.checksum(var_to_bytes(loaded.get("data",{})))}))
 print("PROCESS ",scene.session.phase," actions=",scene.session.actions," errors=",errors)
 scene.set_process(false)
 scene.sound.reset_feedback()
 await process_frame # Fixed-fps Dummy playback teardown warning is documented.
 scene.queue_free();await process_frame
 quit(1 if not errors.is_empty() else 0)

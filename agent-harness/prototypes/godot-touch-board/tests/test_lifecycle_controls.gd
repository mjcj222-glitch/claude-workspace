extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func tap(view,point):view.press(point,-1);view.release(point,-1)
func _initialize():call_deferred("run")
func run():
 var view=load("res://main.tscn").instantiate();root.add_child(view);view.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(view)
 view.lifecycle.enabled=true;view.lifecycle.store=Store.new("/tmp/chroma-controls-"+str(OS.get_process_id()))
 view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
 var initial=Store.capture(view)
 check(view.lifecycle.store.load_run().ok,"fixture checkpoint saved")
 # Reset down must open confirmation, not replace a checkpoint or accept its up.
 view.press(view.RESET.get_center(),-1)
 check(view.lifecycle.modal=="confirm" and Store.capture(view)==initial,"reset requires explicit confirmation")
 view.release(view.lifecycle.PRIMARY.get_center(),-1)
 check(view.lifecycle.modal=="confirm" and view.lifecycle.store.load_run().data==initial,"unowned release cannot abandon")
 tap(view,view.lifecycle.SECONDARY.get_center())
 check(view.lifecycle.modal=="" and Store.capture(view)==initial,"cancel preserves current run")
 # Reward and transaction fixtures use actual controller and one consistent graph.
 var s=view.session
 s.current_node="entry";s.history=["entry"];s.visited={"entry":true};s.paid_nodes={"entry":true}
 s.combat.enemy_hp=0;s.combat._victory_counted=true;s.combat.enemies_defeated=1
 s.phase="reward";s.gold=4;s.reward_round=1;s.reward_options=["pigment","lens","ash"]
 view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
 check(view.lifecycle.store.load_run().data.session.phase=="reward","unclaimed reward checkpoint")
 tap(view,view.UI.reward_rect(0,3).get_center())
 var after=Store.capture(view)
 check(after.session.relics==["pigment"] and view.lifecycle.store.load_run().data==after,"reward commit saves complete ledger")
 view.release(view.UI.reward_rect(0,3).get_center(),-1)
 check(Store.capture(view)==after,"repeated reward release cannot repay")
 for node in ["rest","event"]:
  Store.restore(view,initial)
  s=view.session;s.current_node=node;s.history=["entry",node];s.visited={"entry":true,node:true};s.paid_nodes={"entry":true}
  s.phase=node;s.hp=20;s.gold=6
  view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
  check(view.lifecycle.error=="",node+" boundary validates")
  tap(view,view.AreaUI.option_rect(0).get_center())
  after=Store.capture(view)
  check(after.session.phase=="map" and after.session.gold==3 and view.lifecycle.store.load_run().data==after,node+" transaction saved once")
  view.release(view.AreaUI.option_rect(0).get_center(),-1)
  check(Store.capture(view)==after,node+" stale release inert")
 Store.restore(view,initial);s=view.session
 s.current_node="shop";s.history=["entry","rest","safe","shop"];s.visited={"entry":true,"rest":true,"safe":true,"shop":true};s.paid_nodes={"entry":true,"safe":true};s.battles_entered=2;s.phase="shop";s.hp=10;s.gold=20;s.relics=["pigment","lens"]
 view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
 for index in [0,1]:
  tap(view,view.UI.shop_rect(index).get_center());after=Store.capture(view)
  check(view.lifecycle.store.load_run().data==after,"shop checkpoint "+str(index))
  tap(view,view.UI.shop_rect(index).get_center())
  check(Store.capture(view)==after,"sold stock cannot buy twice "+str(index))
 # Restore does not reroll prepared boss intent or armed inputs.
 Store.restore(view,initial);s=view.session
 s.history=["entry","rest","safe","boss"];s.current_node="boss";s.visited={"entry":true,"rest":true,"safe":true,"boss":true};s.battles_entered=3;s.combat.start_fight(2,s.panels)
 var boss=Store.capture(view);check(Store.valid(boss),"boss checkpoint valid")
 s.begin(s.panels[0].pos,-1);Store.restore(view,boss)
 view.release(view.board_to_screen(view.session.panels[0].pos),-1)
 check(Store.capture(view)==boss and view.session.owner==-99,"boss intent preserved; held input discarded")
 for phase in ["busy","player_attack","player_impact","enemy_attack","stalled"]:
  view.session.phase=phase;view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
  check(view.lifecycle.store.load_run().data!=Store.capture(view),phase+" never persisted")
 for phase in ["victory","defeat"]:
  view.lifecycle.store=Store.new("/tmp/chroma-terminal-"+phase+"-"+str(OS.get_process_id()))
  check(view.lifecycle.store.save(initial),phase+" preterminal fixture")
  view.session.phase=phase;view.lifecycle.terminal_done=false;view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
  check(view.lifecycle.store.load_run().get("closed",false),phase+" blocks backup resurrection")
  tap(view,view.UI.SUMMARY_CONTINUE.get_center())
  check(view.session.phase=="departure" and view.lifecycle.modal=="",phase+" fresh selection")
 view.configured_seed=7;view.fixed_seed=true
 Store.restore(view,initial)
 view.lifecycle.request_new(view)
 tap(view,view.lifecycle.PRIMARY.get_center())
 check(view.run_seed==7 and view.session.phase=="departure","explicit new seed applies after resuming a different saved seed")
 tap(view,view.lifecycle.PRIMARY.get_center())
 check(view.session.departure_choice=="","repeated confirmation cannot select underlying character")
 view.queue_free();await process_frame
 print("LIFECYCLE_CONTROLS checks=",checks," failures=",failures)
 quit(1 if failures else 0)

extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
var view
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _initialize():call_deferred("run")
func next_clear()->int:
 var id=-1;var count=999
 for p in view.session.panels:
  var plan=view.session.plan_for(p.id)
  if plan.valid and plan.removed.size()<count:id=p.id;count=plan.removed.size()
 return id
func commit(id:int):
 for p in view.session.panels:
  if p.id==id:
   var at=view.board_to_screen(p.pos);view.press(at,-1);view.release(at,-1);return
func finish_fall():
 for i in range(1200):
  if view.session.phase!="busy":return
  view._process(1.0/60.0)
 check(false,"physical refill completes within bounded steps")
func run():
 view=load("res://main.tscn").instantiate();root.add_child(view);view.set_process(false);view.record_timings=false;view.sound.muted=true
 preload("res://tests/enter_adventure.gd").enter(view)
 view.lifecycle.enabled=true;view.lifecycle.store=Store.new("/tmp/chroma-bank-interruption-"+str(OS.get_process_id()))
 view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
 for i in range(2):
  var id=next_clear();check(id>=0,"generated board supplies legal clear")
  if id<0:break
  commit(id);finish_fall()
  check(view.session.phase=="ready" and view.session.combat.actions_in_turn==i+1,"legal clear settles to resumable bank")
 var saved=view.lifecycle.store.load_run()
 check(saved.ok and saved.data==Store.capture(view) and saved.data.combat.pending_removed>0,"two-clear bank saved with real refill and RNG")
 if not saved.ok:
  await preload("res://tests/audio_teardown.gd").release(view,self);quit(1);return
 var third=next_clear();commit(third);finish_fall()
 check(view.session.phase=="player_attack","third real clear enters attack presentation")
 var pending=view.session.combat.pending_damage;var hp=view.session.combat.enemy_hp
 view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
 check(not Store.valid(Store.capture(view)),"partial attack snapshot rejected")
 check(view.lifecycle.store.load_run().data==saved.data,"interrupted attack cannot replace two-clear checkpoint")
 Store.restore(view,saved.data)
 view.falling=false;view.active_plan={};view.action_clock=0
 check(Store.capture(view)==saved.data and view.session.combat.enemy_hp==hp,"resume restores pre-strike board/RNG/HP and bank")
 check(view.quality_fx.bank_energy==saved.data.combat.pending_removed and view.quality_fx.cutin_remaining==0,"resume restores charged orb without replaying skill")
 commit(third);finish_fall()
 check(view.session.phase=="player_attack" and view.session.combat.pending_damage==pending,"replayed third legal input creates identical attack")
 var windup_actions=view.session.actions
 var windup_target=next_clear()
 if windup_target>=0:
  commit(windup_target);commit(windup_target)
 view.cancel_input()
 check(view.session.phase=="player_attack" and view.session.actions==windup_actions and view.session.combat.enemy_hp==hp and view.session.combat.pending_damage==pending,"repeated board press/release and cancel cannot change windup bank or HP")
 for i in range(120):
  if view.session.phase!="player_attack":break
  view._process(1.0/60.0)
 check(view.session.combat.enemy_hp==maxi(0,hp-pending) and view.session.combat.strike_settled,"actual impact settles exactly once after replay")
 check(view.session.phase=="player_impact","actual impact holds before reward or retaliation")
 view.lifecycle.dirty=true;view.lifecycle.checkpoint(view)
 check(not Store.valid(Store.capture(view)) and view.lifecycle.store.load_run().data==saved.data,"impact hold preserves pre-strike checkpoint")
 var actions=view.session.actions;var energy=view.session.combat.pending_damage
 var target=next_clear()
 if target>=0:commit(target)
 check(view.session.actions==actions and view.session.combat.pending_damage==energy,"board input is inert during impact hold")
 for i in range(120):
  if view.session.phase!="player_impact":break
  view._process(1.0/60.0)
 check(view.session.phase in ["reward","spoils","enemy_attack","victory"],"impact hold completes through actual controller timing")
 var after=view.session.combat.enemy_hp
 check(not view.session.finish_player_attack() and view.session.combat.enemy_hp==after,"duplicate impact callback cannot apply damage again")
 check(await preload("res://tests/audio_teardown.gd").release(view,self),"bounded audio teardown")
 print("BANK_INTERRUPTION checks=",checks," failures=",failures);quit(1 if failures else 0)

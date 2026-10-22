extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func _initialize():call_deferred("run")
func run():
 var view=load("res://main.tscn").instantiate();root.add_child(view);view.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(view)
 var folder="/tmp/chroma-save-recovery-"+str(OS.get_process_id())
 var life=view.lifecycle;life.enabled=true;life.store=Store.new(folder)
 life.dirty=true;life.checkpoint(view)
 var initial=Store.capture(view)
 DirAccess.make_dir_recursive_absolute(folder+"/backup.json.tmp")
 view.session.gold+=1;life.dirty=true;life.checkpoint(view)
 check(life.error!="","real write-open failure reported")
 check(life.dirty,"failed write retains pending save")
 check(life.store.load_run().data==initial,"write-open failure preserves checkpoint")
 DirAccess.remove_absolute(folder+"/backup.json.tmp")
 await create_timer(1.2).timeout
 life.checkpoint(view)
 check(life.store.load_run().data==Store.capture(view) and life.error=="","recovery without further input")
 DirAccess.make_dir_recursive_absolute(folder+"/closed.tmp")
 view.session.phase="victory";life.dirty=true;life.checkpoint(view)
 check(life.dirty and not life.terminal_done,"terminal write failure stays pending")
 DirAccess.remove_absolute(folder+"/closed.tmp")
 await create_timer(1.2).timeout
 life.checkpoint(view)
 check(life.store.load_run().get("closed",false),"terminal recovery blocks old checkpoint")
 # Fault injection exercises actual temp writes and atomic replacement paths.
 for mode in ["readonly","full","rename","read"]:
  var store=preload("res://tests/fault_checkpoint.gd").new(folder+"-"+mode)
  check(store.save(initial),mode+" initial")
  var newer=initial.duplicate(true);newer.session.gold=2
  check(store.save(newer),mode+" backup exists")
  var current_bytes=FileAccess.get_file_as_bytes(store.directory+"/current.json")
  var backup_bytes=FileAccess.get_file_as_bytes(store.directory+"/backup.json")
  store.fault=mode;newer.session.gold=3
  check(not store.save(newer),mode+" fails safely")
  check(FileAccess.get_file_as_bytes(store.directory+"/current.json")==current_bytes,mode+" current preserved")
  check(FileAccess.get_file_as_bytes(store.directory+"/backup.json")==backup_bytes,mode+" backup preserved")
  store.fault=""
  check(store.load_run().data.session.gold==2,mode+" partial temp never promoted")
  check(store.save(newer) and store.load_run().data==newer,mode+" recovery")
 # Controlled clock checks scheduling, repeated inputs, held/animation boundaries.
 var store=preload("res://tests/fault_checkpoint.gd").new(folder+"-bounded")
 life.store=store;life.modal="";life.last_state={};life.pending_save={};life.failures=0;life.retry_at=0;life.terminal_done=false
 Store.restore(view,initial);life.dirty=true;life.checkpoint(view,0)
 store.fault="readonly";view.session.gold=5;life.dirty=true;life.checkpoint(view,0)
 var count=store.writes
 for tick in range(1000):life.dirty=true;life.checkpoint(view,tick)
 check(store.writes==count,"1000 frames/releases cannot bypass retry delay")
 life.checkpoint(view,1000);life.checkpoint(view,3999)
 check(store.writes==count+1,"first retry once at one second")
 life.checkpoint(view,4000);life.checkpoint(view,11000)
 check(store.writes==count+3 and life.retry_at==-1,"three automatic retries then stop")
 for tick in range(11001,13000):life.checkpoint(view,tick)
 check(store.writes==count+3,"exhausted budget never busy loops")
 store.fault=""
 life.press_retry(life.RETRY.get_center(),-1);life.release(view,life.RETRY.get_center(),-1)
 check(store.load_run().data.session.gold==5 and life.error=="","explicit retry recovers latest stable state")
 store.fault="readonly";view.session.gold=6;life.dirty=true;life.checkpoint(view,0)
 view.session.phase="busy";store.fault="";life.checkpoint(view,1000)
 check(life.dirty and store.load_run().data.session.gold==6,"animation retry saves cached stable state; future boundary still dirty")
 view.session.phase="ready";view.session.gold=7;life.checkpoint(view,1001)
 check(store.load_run().data.session.gold==7,"next completed action is not lost after retry")
 view.session.owner=9;view.session.gold=8;life.dirty=true;life.checkpoint(view,1002)
 check(store.load_run().data.session.gold==7,"held input never captured")
 view.cancel_input();life.checkpoint(view,1003)
 check(store.load_run().data.session.gold==8,"released stable checkpoint captured")
 # Terminal storage unavailability: warning, confirmation and bounded recovery.
 store.fault="readonly";view.session.phase="victory";life.dirty=true;life.checkpoint(view,0)
 check(not life.request_quit(view) and life.modal=="quit","failed terminal close requires explicit unsaved-exit decision")
 check(store.load_run().ok,"unavailable storage honestly still contains old checkpoint")
 life.modal="";life.request_new(view)
 check(life.modal=="confirm","new run after failed terminal barrier requires confirmation")
 life.modal="quit";store.fault=""
 check(life.request_quit(view) and store.load_run().get("closed",false),"quit retry commits terminal barrier before exit")
 # Real target-directory rename failure preserves the old run.
 var blocked=Store.new(folder+"-rename-real")
 check(blocked.save(initial),"real rename initial")
 DirAccess.make_dir_recursive_absolute(blocked.directory+"/closed")
 check(not blocked.close_run() and FileAccess.file_exists(blocked.directory+"/current.json"),"real terminal rename failure preserves original")
 DirAccess.remove_absolute(blocked.directory+"/closed")
 check(blocked.close_run(),"real terminal rename recovery")
 # Retry UI must not steal a different held pointer or arm the board under it.
 Store.restore(view,initial);life.modal="";life.error="test failure"
 view.session.owner=7
 view.press(life.RETRY.get_center(),8)
 check(life.choice!=2 and view.session.owner==7,"retry cannot steal held board pointer")
 view.cancel_input();life.error="test failure"
 view.press(life.RETRY.get_center(),8)
 view.press(view.board_to_screen(view.session.panels[0].pos),7)
 check(view.session.owner==-99,"board cannot arm underneath held retry")
 view.cancel_input()
 # A terminal transition gets its own bounded barrier budget even after
 # ordinary checkpoint retries were exhausted.
 life.modal="";life.terminal_done=false;life.terminal_pending=false;life.failures=4;life.retry_at=-1
 life.store=preload("res://tests/fault_checkpoint.gd").new(folder+"-terminal-budget")
 life.store.save(initial);view.session.phase="defeat";life.dirty=true
 life.checkpoint(view,0)
 check(life.terminal_done and life.store.load_run().get("closed",false),"terminal attempts barrier despite prior exhausted snapshot budget")
 # Failed archive must leave both current run and resumable bytes untouched.
 life.store=preload("res://tests/fault_checkpoint.gd").new(folder+"-archive")
 life.store.save(initial);life.store.fault="archive";Store.restore(view,initial)
 life.request_new(view);life.press(life.PRIMARY.get_center(),-1);life.release(view,life.PRIMARY.get_center(),-1)
 check(life.modal=="confirm" and Store.capture(view)==initial and life.store.load_run().data==initial,"failed confirmed archive preserves run and save")
 # Transactions execute only once while storage is unavailable; retry stores
 # the resulting ledger, never replays a reward/purchase action.
 for transaction in ["reward","shop"]:
  Store.restore(view,initial)
  life.modal="";life.last_state={};life.pending_save={};life.failures=0;life.retry_at=0
  life.store=preload("res://tests/fault_checkpoint.gd").new(folder+"-"+transaction)
  var s=view.session
  if transaction=="reward":
   s.current_node="entry";s.history=["entry"];s.visited={"entry":true};s.paid_nodes={"entry":true}
   s.combat.enemy_hp=0;s.combat._victory_counted=true;s.combat.enemies_defeated=1
   s.phase="reward";s.gold=4;s.reward_round=1;s.reward_options=["pigment","lens","ash"]
  else:
   s.current_node="shop";s.history=["entry","rest","safe","shop"];s.visited={"entry":true,"rest":true,"safe":true,"shop":true};s.paid_nodes={"entry":true,"safe":true};s.battles_entered=2;s.phase="shop";s.hp=10;s.gold=20;s.relics=["pigment","lens"]
  life.dirty=true;life.checkpoint(view)
  check(life.error=="",transaction+" valid initial checkpoint")
  life.store.fault="readonly"
  var point=view.UI.reward_rect(0,3).get_center() if transaction=="reward" else view.UI.shop_rect(0).get_center()
  view.press(point,-1);view.release(point,-1)
  var paid=Store.capture(view)
  check(life.error!="",transaction+" transaction succeeds but write failure explicit")
  view.release(point,-1)
  check(Store.capture(view)==paid,transaction+" repeated release cannot repay")
  life.store.fault="";life.checkpoint(view,Time.get_ticks_msec()+1200)
  check(life.store.load_run().data==paid,transaction+" retry stores ledger without replay")
 view.queue_free();await process_frame
 print("SAVE_RECOVERY checks=",checks," failures=",failures);quit(1 if failures else 0)

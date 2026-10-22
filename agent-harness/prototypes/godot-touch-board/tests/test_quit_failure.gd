extends SceneTree
func _initialize():call_deferred("run")
func run():
 var view=load("res://main.tscn").instantiate();root.add_child(view)
 preload("res://tests/enter_adventure.gd").enter(view)
 var life=view.lifecycle;life.enabled=true
 life.store=preload("res://tests/fault_checkpoint.gd").new("/tmp/chroma-quit-failure-"+str(OS.get_process_id()))
 life.dirty=true;life.checkpoint(view)
 life.store.fault="readonly";view.session.phase="victory";life.dirty=true;life.checkpoint(view)
 view.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 assert(life.modal=="quit" and life.store.load_run().ok)
 view.release(life.SECONDARY.get_center(),-1)
 assert(life.modal=="quit")
 print("PASS unowned quit release inert; old checkpoint honestly resumable")
 if "--recover" in OS.get_cmdline_user_args():
  life.store.fault=""
  view.press(life.PRIMARY.get_center(),-1);view.release(life.PRIMARY.get_center(),-1)
  assert(life.store.load_run().get("closed",false))
  print("PASS explicit retry closes barrier then quits")
 else:
  view.press(life.SECONDARY.get_center(),-1);view.release(life.SECONDARY.get_center(),-1)
  assert(life.store.load_run().ok)
  print("PASS explicit unsaved exit allowed without inventing persistence")

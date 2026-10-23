extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func tap(scene,point:Vector2)->void:scene.press(point,-1);scene.release(point,-1)
func enter_map(scene)->void:
 if scene.session.has_method("select_node"):
  check(scene.session.phase=="map","area departure reaches route map")
  tap(scene,scene.AreaUI.node_rect(0).get_center())
  tap(scene,scene.AreaUI.ENTER.get_center())
  check(scene.session.phase=="ready" and scene.session.current_node=="entry","legal map gestures enter first fight")
 else:
  check(scene.session.phase=="ready","short-run departure enters first fight directly")
 OS.delay_msec(510) # Wait only the actual repeated departing-control guard.
func run()->void:
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 await process_frame
 check(scene.session.phase=="departure","actual app starts in character selection")
 if scene.session.phase!="departure":scene.queue_free();await process_frame;print("CHARACTER_INPUT checks=",checks," failures=",failures);quit(1);return
 var muted:bool=scene.sound.muted
 tap(scene,scene.MUTE.get_center());check(scene.sound.muted!=muted and scene.session.phase=="departure","departure sound control is functional without board input")
 var first:Rect2=scene.UI.character_rect(0);var second:Rect2=scene.UI.character_rect(1);var start:Vector2=scene.UI.DEPART.get_center()
 scene.release(second.get_center(),-1);check(scene.session.departure_choice=="","stale release cannot choose")
 scene.press(second.get_center(),-1);scene.cancel_input();scene.release(second.get_center(),-1)
 check(scene.session.departure_choice=="","focus cancellation preserves selection wait")
 scene.press(second.get_center(),-1);scene.move_pointer(Vector2(10,210),-1);scene.release(second.get_center(),-1)
 check(scene.session.departure_choice=="","card exit cancels")
 scene.press(second.get_center(),-1);scene.release(second.get_center(),2)
 check(scene.session.departure_choice=="","other finger cannot confirm")
 scene.release(second.get_center(),-1);check(scene.session.departure_choice=="noa" and scene.session.character_id=="","card chooses only a candidate")
 var serial:int=scene.session.offer_serial;scene.release(start,-1)
 check(scene.session.phase=="departure" and scene.session.offer_serial==serial,"candidate release cannot start run")
 tap(scene,start);check(scene.session.phase in ["ready","map"] and scene.session.character_id=="noa","explicit departure fixes character")
 scene.release(start,-1);tap(scene,start)
 check(scene.session.actions==0 and scene.session.skill_uses==0 and scene.session.phase in ["ready","map"],"double departure cannot leak a board action")
 enter_map(scene)
 scene.session.open_departure();check(scene.session.phase=="ready" and scene.session.character_id=="noa","cannot reopen choice during run")
 var chosen:Dictionary={}
 for p in scene.session.panels:
  if p.kind=="normal":chosen=p;break
 var point:Vector2=scene.board_to_screen(chosen.pos)
 tap(scene,scene.SKILL.get_center());check(scene.session.skill_mode,"noa enters direct panel targeting")
 scene.press(point,-1);var preview:Dictionary=scene.session.selection.duplicate(true)
 check(preview.get("valid",false) and preview.planted.has(chosen.id) and preview.rain_refills==2,"preview shows planted core")
 scene.cancel_input();scene.release(point,-1)
 check(scene.session.charge==3 and scene.session.skill_uses==0 and scene.quality_fx.cutin_remaining==0,"skill cancel costs nothing and has no cut-in")
 scene.press(point,-1);preview=scene.session.selection.duplicate(true);scene.release(point,-1)
 check(scene.session.skill_uses==1 and scene.session.actions==0 and scene.session.charge==0 and scene.session.rain_remaining==2 and scene.quality_fx.damage_amount==0,"plant commits without clear or fake hit")
 check(scene.quality_fx.cutin_remaining>0 and scene.session.panels.any(func(p):return p.id==chosen.id and p.kind=="core"),"actual skill gets cut-in and same-position core")
 var context:Dictionary=scene.session.combat.damage_context()
 scene.release(point,-1);check(scene.session.skill_uses==1 and scene.session.combat.damage_context()==context,"stale skill release cannot affect intent")
 # Explicit terminal fixture, separate from ordinary run evidence.
 for terminal in ["victory","defeat"]:
  scene.session.phase=terminal;scene.session.cancel()
  tap(scene,scene.UI.SUMMARY_CONTINUE.get_center())
  check(scene.session.phase=="departure" and scene.session.character_id=="" and scene.session.departure_choice=="" and scene.session.relics.is_empty() and scene.session.gold==0 and scene.session.charge==3 and not scene.session.ash_reserved,"terminal returns to fresh selection: "+terminal)
  scene.release(start,-1);check(scene.session.phase=="departure","old terminal release cannot start")
  tap(scene,first.get_center());tap(scene,start)
  enter_map(scene)
  check(scene.session.character_id=="rio" and scene.session.phase=="ready","can start original character after result")
 tap(scene,scene.RESET.get_center())
 check(scene.session.phase=="departure" and scene.quality_fx.take_impact().is_empty() and scene.session.skill_uses==0,"reset clears active effects and character")
 check(await preload("res://tests/audio_teardown.gd").release(scene,self),"audio teardown completes")
 print("CHARACTER_INPUT checks=",checks," failures=",failures);quit(1 if failures else 0)

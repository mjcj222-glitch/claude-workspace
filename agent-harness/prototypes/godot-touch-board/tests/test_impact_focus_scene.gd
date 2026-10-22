extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(scene)
 var chosen:Dictionary={}
 for p in scene.session.panels:
  var candidate:Dictionary=scene.session.plan_for(p.id)
  if candidate.valid and candidate.damage>0:chosen=p;break
 var point:Vector2=scene.board_to_screen(chosen.pos)
 scene.press(point,-1);scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);scene.release(point,-1)
 check(scene.session.actions==0 and scene.session.selection.is_empty(),"focus loss cancels preview without clear or sound")
 scene.press(point,-1);var plan:Dictionary=scene.session.selection.duplicate(true);scene.release(point,-1)
 var committed:Dictionary=scene.active_plan.duplicate(true)
 for i in range(10):scene.press(point,-1);scene.release(point,-1)
 check(scene.session.actions==1 and scene.active_plan==committed and committed==plan,"repeated input cannot restart resolution or plan")
 # Follow three actual legal clears through refill; only the third attacks.
 for clear_index in range(3):
  if clear_index>0:
   chosen={}
   for panel in scene.session.panels:
    if scene.session.plan_for(panel.id).valid:chosen=panel;break
   check(not chosen.is_empty(),"normal board has next legal clear")
   point=scene.board_to_screen(chosen.pos);scene.press(point,-1);scene.release(point,-1)
  for frame in range(1800):
   scene._process(1.0/120)
   if scene.session.phase!="busy":break
  if clear_index<2:
   check(scene.session.phase=="ready" and scene.quality_fx.impact_remaining==0 and not scene.sound.voices[5].playing,"first two refills collect without enemy impact")
  else:
   check(scene.session.phase=="player_attack","third refill releases bank")
 for frame in range(60):
  scene._process(1.0/120)
  if scene.quality_fx.impact_remaining>0:break
 check(scene.sound.voices[5].playing and scene.sound._focus_remaining>0,"third-clear combined impact foregrounds reserved sound")
 scene.reset_board()
 check(scene.sound.voices.all(func(v):return not v.playing) and scene.sound._focus_remaining==0,"controller reset during impact stops every voice and focus")
 for i in range(40):scene._process(1.0/120)
 check(scene.session.phase=="departure" and scene.quality_fx.take_impact().is_empty() and scene.feedback.rings.is_empty(),"interrupted old action never resurrects effects or input state")
 scene.sound.muted=true;scene.sound.impact(2)
 scene.reset_board()
 check(scene.sound.muted and scene.sound._focus_remaining==0,"reset preserves mute without pending focus")
 scene.queue_free();await process_frame;await create_timer(.25).timeout
 print("IMPACT_FOCUS_SCENE checks=",checks," failures=",failures);quit(1 if failures else 0)

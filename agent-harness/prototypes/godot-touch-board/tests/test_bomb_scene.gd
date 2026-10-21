extends SceneTree
## Explicit existing-board type/HP fixture, not ordinary-play evidence.
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(scene,"noa")
 scene.sound.muted=true;scene.session.relics=["lens"];scene.session.combat.enemy_hp=500
 var selected:Dictionary=scene.session.panels[20]
 selected.kind="strong";scene.visual=scene.session.panels.duplicate(true)
 var old_next:int=scene.session.next_id
 var pos:Vector2=scene.board_to_screen(selected.pos)
 scene.press(pos,-1);var plan:Dictionary=scene.session.selection.duplicate(true);scene.release(pos,-1)
 check(plan.bomb_spawn_kind=="big_bomb" and plan==scene.active_plan,"preview prepares large supply and same committed plan")
 var samples:Array=[];var steps:=0;var entered:=false
 while not scene.falling and steps<150:scene._process(1.0/120);steps+=1
 check(scene.falling and scene.motion_state.pending[0].kind=="big_bomb" and scene.motion_state.pending[0].id==old_next,"actual refill queues exactly first existing new ID as bomb")
 while scene.session.phase=="busy" and steps<800:
  scene._process(1.0/120);steps+=1
  for body in scene.visual:
   if body.id==old_next:
    samples.append({"pos":body.pos,"radius":body.radius})
    if not entered:
     entered=true;check(body.pos.y<scene.BOARD.position.y,"bomb actually enters from top outside board")
 check(scene.session.phase=="ready","natural refill completes without effect gate")
 var bombs:Array=scene.session.panels.filter(func(p):return p.kind in ["bomb","big_bomb"])
 check(bombs.size()==1 and bombs[0].id==old_next and bombs[0].radius==48,"settled bomb has same queued ID/body, one supply only")
 check(not plan.removed.has(old_next) and not plan.activated.has(old_next),"fresh bomb was not auto-exploded")
 pos=scene.board_to_screen(bombs[0].pos);var actions:int=scene.session.actions
 scene.press(pos,-1);var preview:Dictionary=scene.session.selection.duplicate(true)
 check(preview.valid and preview.blasts[0].radius==164,"settled supplied large bomb has actual next-input radial preview")
 scene.cancel_input();scene.release(pos,-1)
 check(scene.session.actions==actions,"cancel leaves supplied bomb intact")
 scene.press(pos,-1);preview=scene.session.selection.duplicate(true);scene.release(pos,-1)
 check(scene.active_plan==preview and scene.session.actions==actions+1,"next deliberate release detonates precisely previewed bomb")
 scene.reset_board();scene._process(.8)
 check(scene.session.phase=="departure" and scene.feedback.rings.is_empty() and scene.quality_fx.take_impact().is_empty(),"reset clears blast and pending callbacks")
 FileAccess.open("res://evidence/impact-strength/bomb-supply-path.json",FileAccess.WRITE).store_string(JSON.stringify({"fixture":true,"samples":samples,"checks":checks,"failures":failures},"  "))
 scene.queue_free();await process_frame;await create_timer(.25).timeout
 print("BOMB_SCENE checks=",checks," failures=",failures);quit(1 if failures else 0)

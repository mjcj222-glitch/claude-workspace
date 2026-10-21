extends "res://tests/capture_quality_states.gd"
## Actual X11 pointer against a naturally settled, explicitly injected size fixture.
func run()->void:
 var args:=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 preload("res://tests/enter_adventure.gd").enter(scene,"noa");scene.set_process(false);scene.sound.muted=true;scene.landing=1
 scene.session.combat.enemy_hp=500;scene.session.combat.enemy_max_hp=500
 var rng:=RandomNumberGenerator.new();rng.seed=23
 var state:Dictionary=scene.Motion.start([],scene.BOARD,48,1,rng)
 for i in range(6):scene.Bombs.prepare_supply([state.pending[i]],"big_bomb")
 scene.Bombs.prepare_supply([state.pending[6]],"bomb")
 while not state.ready and not state.stalled:scene.Motion.step(state,scene.BOARD,scene.Motion.STEP)
 check(state.ready,"dense fixture settles naturally")
 scene.session.panels=state.panels;scene.session.next_id=1000;scene.visual=state.panels.duplicate(true)
 await shot("01-dense-volume-fixture")
 if "--comparison-only" in args:scene.queue_free();await process_frame;quit();return
 var big:Dictionary=state.panels[2]
 var rim:=Vector2.ZERO
 for i in range(32):
  var candidate:Vector2=big.pos+Vector2.from_angle(TAU*i/32)*44
  if scene.BOARD.has_point(candidate) and scene.PanelView.hit_test(state.panels,candidate)==big.id:rim=candidate;break
 check(rim!=Vector2.ZERO and big.radius==48,"exposed physical48 rim exists")
 await gesture("rim-down",scene.board_to_screen(rim),"down")
 check(scene.session.selection.valid and scene.session.selection.direct==[big.id],"OS rim selects actual large body")
 await shot("02-rim-preview")
 await gesture("cancel-move",Vector2.ZERO,"move");await gesture("cancel-up",Vector2.ZERO,"up")
 check(scene.session.actions==0 and scene.session.selection.is_empty(),"OS cancel has no action")
 await gesture("reduced",scene.UI.EFFECTS.get_center())
 check(scene.reduced_effects,"OS reduced enabled")
 await shot("03-reduced-same-volume")
 var edge:Dictionary=state.panels[0]
 check(absf(edge.pos.x-edge.radius-scene.BOARD.position.x)<.2,"large physical body rests against wall without clipping")
 var edge_point:Vector2=scene.board_to_screen(Vector2(31,edge.pos.y))
 await gesture("edge-down",edge_point,"down")
 check(scene.session.selection.get("valid",false) and scene.session.selection.direct==[edge.id],"OS inside-wall physical rim selectable")
 await shot("04-edge-preview")
 scene.cancel_input();await gesture("edge-up",edge_point,"up")
 await gesture("wall-outside",scene.board_to_screen(Vector2(29,edge.pos.y)))
 check(scene.session.actions==0 and scene.session.selection.is_empty(),"OS beyond wall cannot select")
 await gesture("edge-commit",edge_point)
 check(scene.session.actions==1 and scene.active_plan.blasts[0].radius==164,"OS one commit uses canonical164 explosion")
 await gesture("reset",scene.RESET.get_center())
 check(scene.session.phase=="departure" and scene.feedback.rings.is_empty(),"OS reset clears selection and effects")
 scene.queue_free();await process_frame
 print("BOMB_VOLUME_WINDOW checks=",checks," failures=",failures," size=",root.size);quit(1 if failures else 0)

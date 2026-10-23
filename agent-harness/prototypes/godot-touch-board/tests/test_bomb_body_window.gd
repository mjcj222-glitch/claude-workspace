extends "res://tests/capture_quality_states.gd"
## Explicit comparison/dense/edge fixture, actual OS pointer and main renderer.
func run()->void:
 var args:=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 preload("res://tests/enter_adventure.gd").enter(scene,"noa");scene.set_process(false);scene.sound.muted=true;scene.landing=1
 scene.session.combat.enemy_hp=500;scene.session.combat.enemy_max_hp=500
 var panels:Array=[]
 for row in range(5):
  for col in range(8):panels.append({"id":row*8+col+1,"pos":Vector2(67+col*74,470+row*74),"radius":37.0,"kind":"normal","color":(row+col)%4})
 var big:Dictionary=panels[20];big.kind="big_bomb"
 panels[18].kind="bomb"
 scene.session.panels=panels;scene.session.next_id=1000;scene.visual=panels.duplicate(true)
 await shot("01-dense-size-fixture")
 var rim:Vector2=scene.board_to_screen(big.pos+Vector2(31,-31))
 await gesture("outer-rim-down",rim,"down")
 check(scene.session.selection.valid and scene.session.selection.direct==[big.id],"OS exposed body beyond37 selects large bomb")
 await shot("02-rim-preview")
 await gesture("cancel-move",Vector2(0,0),"move");await gesture("cancel-up",Vector2(0,0),"up")
 check(scene.session.actions==0 and scene.session.selection.is_empty(),"OS outer-rim cancellation has no action")
 var covered:Vector2=scene.board_to_screen(big.pos+Vector2(41,0))
 await gesture("front-down",covered,"down")
 check(not scene.session.selection.get("direct",[]).has(big.id),"OS front chip owns overlapping visible area")
 await gesture("front-up",covered,"up")
 check(scene.session.actions==0,"front invalid single cannot leak through to bomb")
 await gesture("reduced",scene.UI.EFFECTS.get_center())
 check(scene.reduced_effects,"OS reduced enabled")
 await shot("03-reduced-same-size")
 var edge:Dictionary=panels[16];edge.kind="big_bomb";big.kind="normal";scene.visual=panels.duplicate(true)
 var edge_point:Vector2=scene.board_to_screen(Vector2(31,edge.pos.y))
 await gesture("edge-down",edge_point,"down")
 check(scene.session.selection.get("valid",false) and scene.session.selection.direct==[edge.id],"OS visible wall fragment remains selectable")
 await shot("04-edge-preview")
 scene.cancel_input();await gesture("edge-up",edge_point,"up")
 var outside:Vector2=scene.board_to_screen(Vector2(29,edge.pos.y))
 await gesture("wall-outside",outside)
 check(scene.session.actions==0 and scene.session.selection.is_empty(),"OS clipped outside rim cannot select")
 await gesture("edge-commit",edge_point)
 check(scene.session.actions==1 and scene.active_plan.blasts[0].radius==164,"OS edge release preserves164 blast and one action")
 await gesture("reset",scene.RESET.get_center())
 check(scene.session.phase=="departure" and scene.feedback.rings.is_empty(),"OS reset clears body selection and effects")
 scene.queue_free();await process_frame
 print("BOMB_BODY_WINDOW checks=",checks," failures=",failures," size=",root.size);quit(1 if failures else 0)

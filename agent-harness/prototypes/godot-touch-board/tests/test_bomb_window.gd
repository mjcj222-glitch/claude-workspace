extends "res://tests/capture_quality_states.gd"
## Explicit bomb/HP fixture for real small-window pointer transforms and visuals.
func run()->void:
 var args:=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 preload("res://tests/enter_adventure.gd").enter(scene,"noa");scene.set_process(false);scene.sound.muted=true
 scene.session.combat.enemy_hp=500;scene.session.hp=24;scene.session.relics=["lens"]
 var p:Dictionary=scene.session.panels[20];p.kind="big_bomb"
 var closest:Dictionary={};var distance:=INF
 for q in scene.session.panels:
  if q.id!=p.id and p.pos.distance_to(q.pos)<distance:closest=q;distance=p.pos.distance_to(q.pos)
 closest.kind="bomb";scene.visual=scene.session.panels.duplicate(true)
 var point:Vector2=scene.board_to_screen(p.pos)
 await shot("01-two-bombs-fixture")
 await gesture("bomb-down-cancel",point,"down")
 var plan:Dictionary=scene.session.selection.duplicate(true)
 check(plan.valid and plan.blasts.size()==2,"OS held preview covers both actual bomb ranges")
 await shot("02-chain-preview")
 scene.cancel_input();await gesture("bomb-up-cancel",point,"up")
 check(scene.session.actions==0 and scene.session.hp==24,"OS canceled bomb has no action or heal")
 await gesture("bomb-down",point,"down");plan=scene.session.selection.duplicate(true)
 await gesture("bomb-up",point,"up")
 check(scene.active_plan==plan and scene.session.actions==1,"OS committed chain equals held plan")
 while scene.quality_fx.impact_remaining<=0:scene._process(1.0/120)
 scene.quality_fx.update(.06)
 await shot("03-chain-impact")
 await gesture("reduce",scene.UI.EFFECTS.get_center())
 check(scene.reduced_effects and scene.quality_fx.hit_flash()==0 and scene.quality_fx.stage_offset()==Vector2.ZERO,"OS reduced mode suppresses enhanced reaction")
 await shot("04-reduced-impact")
 await gesture("sound-on",scene.MUTE.get_center());scene.sound.panel(2,"big_bomb")
 await gesture("sound-off",scene.MUTE.get_center())
 check(scene.sound.muted and scene.sound.voices.all(func(v):return not v.playing),"OS mute stops active explosion tails")
 scene.session.phase="reward";scene.session.reward_options=["pigment","ash"];scene.session.reward_round=1;scene.session.offer_serial+=1
 var hp:int=scene.session.hp;var actions:int=scene.session.actions
 await gesture("modal-board",Vector2(360,850))
 check(scene.session.phase=="reward" and scene.session.actions==actions and scene.session.hp==hp,"OS reward modal blocks board attack passthrough")
 await shot("05-reward-lens-fixture")
 scene.session.phase="event";scene.session.relics=["pigment"];scene.session.gold=4;scene.session.current_node="event"
 await shot("06-event-lens-fixture")
 scene.session.phase="shop";scene.session.relics=["pigment","ash"];scene.session.gold=8
 await shot("07-shop-lens-fixture")
 await gesture("reset",scene.RESET.get_center())
 check(scene.session.phase=="departure" and scene.feedback.rings.is_empty() and scene.quality_fx.impact_remaining==0,"OS reset cancels blast and transitions")
 scene.queue_free();await process_frame
 print("BOMB_WINDOW checks=",checks," failures=",failures," size=",root.size);quit(1 if failures else 0)

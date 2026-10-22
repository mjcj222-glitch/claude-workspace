extends "res://tests/capture_quality_states.gd"
## Explicit non-overlapping contact fixture. OS input, not earned normal play.
func p(id:int,x:float,y:float,kind:String,color:int)->Dictionary:
 return {"id":id,"pos":Vector2(x,y),"radius":48.0 if kind=="big_bomb" else 37.0,"kind":kind,"color":color}
func run()->void:
 var args:=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 preload("res://tests/enter_adventure.gd").enter(scene,"rio");scene.set_process(false);scene.sound.muted=false;scene.landing=1
 scene.session.hp=20;scene.session.combat.enemy_hp=500;scene.session.combat.enemy_max_hp=500
 var panels:Array=[p(1,126,600,"normal",1),p(2,200,600,"bomb",1),p(3,274,600,"normal",1),p(4,348,600,"normal",1),p(5,422,600,"normal",0),p(6,496,600,"normal",0),p(7,500,760,"big_bomb",3),p(8,415,760,"normal",3),p(9,341,760,"normal",3),p(10,267,760,"normal",3),p(11,500,675,"heart",4)]
 scene.session.panels=panels;scene.session.next_id=1000;scene.visual=panels.duplicate(true)
 await shot("01-colored-contact-fixture")
 var point:Vector2=scene.board_to_screen(panels[0].pos)
 await gesture("green-chain-down",point,"down")
 check(scene.session.selection.valid and scene.session.selection.direct==[1,2,3,4],"OS same-color chain traverses actual green bomb")
 check(not scene.session.selection.direct.has(5) and scene.session.selection.removed.has(4),"OS red excluded and distant same-color path included beyond98")
 await shot("02-green-chain-preview")
 await gesture("cancel-move",Vector2.ZERO,"move");await gesture("cancel-up",Vector2.ZERO,"up")
 check(scene.session.actions==0 and scene.session.selection.is_empty(),"OS first colored press cancellation has no action")
 await gesture("red-down",scene.board_to_screen(panels[4].pos),"down")
 check(scene.session.selection.direct==[5,6] and scene.session.selection.blasts.is_empty(),"OS other color does not start neighboring green bomb")
 scene.cancel_input();await gesture("red-up",scene.board_to_screen(panels[4].pos),"up")
 await gesture("skill",scene.SKILL.get_center())
 await gesture("red-palette",scene.UI.color_rect(0).get_center())
 await gesture("skill-target",point)
 check(scene.session.actions==0 and scene.session.panels[0].color==0 and scene.session.panels[1].color==1 and scene.session.panels.size()==11,"OS Rio converts only ordinary target, no fake bomb clear")
 var large_point:Vector2=scene.board_to_screen(panels[6].pos)
 await gesture("large-down",large_point,"down")
 var preview:Dictionary=scene.session.selection.duplicate(true)
 check(preview.valid and preview.direct==[7,8,9,10] and preview.blasts[0].color==3 and preview.blasts[0].radius==164,"OS large color and48 body direct-chain preview preserve164 blast")
 check(preview.heal_raw==2 and preview.heal_effective==2,"OS heart included by blast heals once")
 await shot("03-blue-large-preview")
 scene.cancel_input();await gesture("large-cancel-up",large_point,"up")
 await gesture("reduced",scene.UI.EFFECTS.get_center())
 check(scene.reduced_effects,"OS reduced keeps color identification")
 await shot("04-reduced-colors")
 await gesture("commit-down",large_point,"down")
 preview=scene.session.selection.duplicate(true)
 await gesture("commit-up",large_point,"up")
 check(scene.active_plan==preview and scene.session.actions==1,"OS colored full preview equals one committed action")
 # Repeat while the real committed action is busy: no new damage or counts.
 var action:int=scene.session.actions
 for i in range(3):await gesture("repeat-%d"%i,large_point)
 check(scene.session.actions==action and scene.active_plan==preview,"repeated busy clicks cannot restart committed chain")
 await gesture("effects-full",scene.UI.EFFECTS.get_center())
 scene._process(.05)
 await shot("05-bomb-onset")
 var steps:=0
 while scene.quality_fx.impact_remaining<=0 and steps<120:
  scene._process(1.0/120);steps+=1
 check(scene.quality_fx.impact_remaining>0 and scene.falling,"actual clear reaches one enemy impact and natural refill")
 await shot("06-impact-total")
 await gesture("mute",scene.MUTE.get_center())
 check(scene.sound.muted and scene.sound.voices.all(func(v):return not v.playing),"mute during resolution stops all live voices")
 await gesture("reset",scene.RESET.get_center())
 check(scene.session.phase=="departure" and scene.feedback.rings.is_empty(),"OS reset clears chain, effects and modal input")
 check(scene.sound._focus_remaining==0 and scene.quality_fx.take_impact().is_empty(),"reset during resolution clears pending audio focus and hit")
 scene.queue_free();await process_frame
 print("FOCUS_WINDOW checks=",checks," failures=",failures," size=",root.size);quit(1 if failures else 0)

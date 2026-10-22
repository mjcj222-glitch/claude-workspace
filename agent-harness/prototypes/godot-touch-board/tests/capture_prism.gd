extends "res://tests/capture_quality_states.gd"
## Explicit board/phase fixtures with authenticated OS gestures, not normal runs.
func panel(id:int,color:int,kind:String="normal")->Dictionary:
 return {"id":id,"kind":kind,"color":color,"radius":37.0,"pos":Vector2(130+74*((id-1)%6),390+74*((id-1)/6))}
func fixture(board:Array,hero:String)->void:
 var s=scene.session
 s.cancel();s.phase="ready";s.character_id=hero;s.panels=board.duplicate(true);s.next_id=100
 scene.visual=board.duplicate(true);scene.active_plan={};scene.action_clock=0;scene.falling=false;scene.hero_active=0
 scene.quality_fx.reset();scene.feedback.reset();scene.particles.clear()
func run():
 var args=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene);reset()
 print("PRISM FIXTURES: injected boards and frozen ages; OS controller input, not earned-run evidence")
 var s=scene.session
 var board:Array=[]
 for i in range(24):board.append(panel(i+1,0 if i%2==0 else 3))
 board.append(panel(25,4,"heart"));board.append(panel(26,1,"bomb"))
 fixture(board,"rio");s.relics=[];s.combat.start_fight(2,s.panels);s.combat.shield_color=3
 await shot("prism-01-rio-idle-fixture")
 await gesture("rio-skill",scene.SKILL.get_center())
 await gesture("rio-color",scene.UI.color_rect(3).get_center())
 var at=scene.board_to_screen(s.panels[0].pos)
 await gesture("rio-preview",at,"down")
 var expected=s.selection.duplicate(true);var before=s.panels.duplicate(true)
 check(expected.get("valid",false) and expected.targets.size()==12,"Rio global source-color preview spans whole board")
 check(not expected.converted.has(25) and not expected.converted.has(26),"Rio preview preserves heart and disc bomb")
 await shot("prism-02-rio-preview-fixture")
 await gesture("rio-cancel",Vector2(710,450),"up")
 check(s.panels==before and s.skill_uses==0,"cancelled global preview preserves board and charge")
 await gesture("rio-commit",at)
 check(s.skill_uses==1 and s.actions==0 and s.combat.enemy_hp==48,"global skill does not resolve damage")
 var exact=true
 for p in s.panels:
  if expected.converted.has(p.id) and p.color!=expected.converted[p.id]:exact=false
 check(exact and s.panels[24]==before[24] and s.panels[25]==before[25],"Rio commit matches frozen conversion and preserved specials")
 await shot("prism-03-rio-skill-fixture")
 await gesture("rio-stale-release",at,"up")
 check(s.skill_uses==1 and s.actions==0,"repeated skill release remains inert")
 await gesture("rio-clear-preview",at,"down")
 var planned=s.selection.duplicate(true)
 check(planned.get("shield_broken",false) and planned.shield_damage==12 and planned.shield_bonus==6,"large matched chain previews complete shield break reward")
 await shot("prism-04-shield-break-preview-fixture")
 await gesture("rio-clear-commit",at,"up")
 check(s.combat.shield_hp==0 and scene.active_plan.damage==planned.damage and s.combat.enemy_hp==maxi(0,48-planned.damage),"shield HP and enemy damage equal preview on release")
 var committed_actions=s.actions
 await gesture("rio-clear-repeat",at,"up")
 check(s.actions==committed_actions,"repeated clear release cannot duplicate shield reward")
 for id in planned.sequence:scene._burst(id,planned.sequence.find(id))
 scene.quality_fx.update(.4)
 await shot("prism-05-shield-fragments-fixture")
 # Separate Noa fixture. Preserve actual rain transaction across two clears.
 reset();s=scene.session
 board=[panel(1,2),panel(2,1),panel(3,4,"heart"),panel(4,0,"bomb")]
 fixture(board,"noa");s.relics=[];s.combat.start_fight(2,s.panels);s.combat.shield_color=2
 await gesture("noa-skill",scene.SKILL.get_center())
 at=scene.board_to_screen(s.panels[0].pos)
 await gesture("noa-cast",at)
 check(s.rain_remaining==2 and s.rain_color==2 and s.charge==0 and s.actions==0,"Noa actual skill starts two refill rain without damage or charge")
 await shot("prism-06-noa-rain-two-fixture")
 await gesture("noa-first-clear",at)
 check(s.rain_remaining==1 and s.charge==0 and scene.active_plan.supply_color==2,"first rain clear consumes one and suppresses charge")
 check(s.combat.shield_hp==11,"core removal counts only matching ordinary panel toward shield")
 scene._start_fall()
 var correct=true;var normals=0
 for p in scene.motion_state.pending:
  if p.kind=="normal":normals+=1;correct=correct and p.color==2
  elif p.kind=="heart":correct=correct and p.color==4
 check(correct and normals>0,"actual pending refill uses rain color while preserving heart color")
 await shot("prism-07-noa-rain-one-fixture")
 fixture([panel(1,2),panel(2,2),panel(3,4,"heart")],"noa")
 at=scene.board_to_screen(s.panels[0].pos)
 await gesture("noa-last-clear",at)
 check(s.rain_remaining==0 and s.charge==0 and scene.active_plan.supply_color==2,"last rain clear remains uncharged and supplies fixed color")
 await shot("prism-08-noa-rain-zero-fixture")
 fixture([panel(1,2),panel(2,2),panel(3,4,"heart")],"noa")
 await gesture("noa-new-clear",at)
 check(s.charge==1 and scene.active_plan.supply_color==-1,"only a later normal clear starts recharge")
 s.phase="enemy_attack";scene.hero_active=0
 await shot("prism-09-noa-hit-fixture")
 var count=s.actions
 await gesture("prism-reduced",scene.UI.EFFECTS.get_center())
 check(scene.reduced_effects and s.actions==count,"reduced effects toggle does not mutate action during reaction")
 await shot("prism-10-reduced-hit-fixture")
 check(await preload("res://tests/audio_teardown.gd").release(scene,self),"bounded audio cleanup")
 print("PRISM_WINDOW checks=",checks," failures=",failures," size=",root.size)
 quit(1 if failures else 0)

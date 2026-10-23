extends "res://tests/capture_quality_states.gd"
func run():
 var args=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene);reset()
 var s=scene.session
 s.phase="reward";s.relics=["pigment"];s.reward_options=s.Relics.available(s.relics);s.reward_round=2
 await shot("petal-01-offer-fixture")
 var copy=scene.UI.relic_copy("petal",s)
 check(scene.font.get_string_size(copy.change,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<460,"reward effect copy fits card")
 for line in copy.lines:check(scene.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<460,"reward cost copy fits card")
 await gesture("petal-choose",scene.UI.reward_rect(2,3).get_center())
 check(s.relics==["pigment","petal"] and s.phase=="map","OS reward acquires new choice once")
 scene.release(scene.UI.reward_rect(2,3).get_center(),-1)
 check(s.relics.size()==2,"stale reward release inert")
 # Explicit small board fixture, not normal run evidence.
 s.phase="ready";s.hp=20;s.panels=[]
 for i in range(3):s.panels.append({"id":i+1,"kind":"heart","color":4,"radius":37.0,"pos":Vector2(230+74*i,550)})
 scene.visual=s.panels.duplicate(true)
 s.combat.intent="slam";s.combat.mitigation_active=true;s.combat.mitigation_success=false;s.combat.incoming_damage=10
 await shot("petal-02-telegraph-fixture")
 var at=scene.board_to_screen(s.panels[0].pos)
 await gesture("petal-preview",at,"down")
 check(s.selection.get("petal_guard",false) and s.selection.heal_effective==3,"OS preview shows defense and reduced heal")
 check(scene.font.get_string_size(scene.UI.preview_effect_line(s.selection),HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<640,"preview copy fits smallest supported size")
 await shot("petal-03-preview-fixture")
 await gesture("petal-cancel",Vector2(710,450),"up")
 check(s.actions==0 and not s.combat.mitigation_success,"canceled heart preview grants no defense")
 await gesture("petal-commit",at)
 check(s.actions==1 and s.hp==23 and s.combat.incoming_damage==4,"OS committed snapshot heals three and mitigates to four")
 await shot("petal-04-success-fixture")
 print("PETAL_WINDOW checks=",checks," failures=",failures," size=",root.size)
 quit(1 if failures else 0)

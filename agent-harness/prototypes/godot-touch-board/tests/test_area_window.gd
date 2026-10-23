extends "res://tests/capture_quality_states.gd"
func run()->void:
 var args:=OS.get_cmdline_user_args();root.size=Vector2i(int(args[0]),int(args[1]))
 scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false);scene.sound.muted=true
 await process_frame
 await gesture("hero",scene.UI.character_rect(1).get_center())
 await gesture("depart",scene.UI.DEPART.get_center())
 check(scene.session.phase=="map","OS departure opens area map")
 await shot("01-map")
 var point:Vector2=scene.AreaUI.node_rect(0).get_center()
 await gesture("map-down",point,"down")
 await gesture("map-up",point,"up")
 check(scene.session.selected_node=="entry" and scene.session.history.is_empty(),"OS map candidate does not enter")
 await shot("02-candidate")
 await gesture("enter",scene.AreaUI.ENTER.get_center())
 check(scene.session.phase=="ready" and scene.session.character_id=="noa","OS separate entry commits")
 await create_timer(.55).timeout
 # Explicit post-victory resource fixture isolates transactions/input.
 scene.session.combat.enemy_hp=0;scene.session.phase="busy";scene.session.finish_refill();scene.session.choose_relic("pigment",scene.session.offer_serial)
 await shot("03-fork-fixture")
 await gesture("rest",scene.AreaUI.node_rect(1).get_center())
 await gesture("rest-enter",scene.AreaUI.ENTER.get_center())
 scene.session.hp=28
 await shot("04-rest-fixture")
 var option:Vector2=scene.AreaUI.option_rect(0).get_center()
 await gesture("rest-down-cancel",option,"down");scene.cancel_input();await gesture("rest-up-cancel",option,"up")
 check(scene.session.hp==28 and scene.session.gold==4,"OS canceled rest costs nothing")
 await gesture("rest-pay",option)
 check(scene.session.phase=="map" and scene.session.hp==30 and scene.session.gold==1,"OS capped rest charged once")
 await gesture("backtrack",scene.AreaUI.node_rect(0).get_center())
 check(scene.session.selected_node=="","OS visited node locked")
 await shot("05-next-fork-fixture")
 await gesture("reset",scene.RESET.get_center())
 check(scene.session.phase=="departure" and scene.session.history.is_empty() and scene.session.gold==0,"OS reset clears area history")
 scene.queue_free();await process_frame
 print("AREA_WINDOW checks=",checks," failures=",failures," size=",root.size)
 quit(1 if failures else 0)

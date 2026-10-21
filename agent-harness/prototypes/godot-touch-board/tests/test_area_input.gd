extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func tap(s,p:Vector2)->void:s.press(p,-1);s.release(p,-1)
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=load("res://main.tscn").instantiate();root.add_child(s);s.set_process(false);await process_frame
 check(s.session.get("area_mode")==true and s.session.phase=="departure","actual default is area with hero departure")
 tap(s,s.UI.character_rect(1).get_center());tap(s,s.UI.DEPART.get_center())
 check(s.session.phase=="map" and s.session.character_id=="noa","hero departure opens map")
 var point:Vector2=s.AreaUI.node_rect(0).get_center()
 s.release(point,-1);check(s.session.selected_node=="","stale release cannot choose node")
 s.press(point,-1);s.cancel_input();s.release(point,-1)
 check(s.session.selected_node=="","cancel/focus leaves map unconsumed")
 s.press(point,-1);s.release(point,4);check(s.session.selected_node=="","extra finger cannot confirm")
 s.release(point,-1);check(s.session.selected_node=="entry" and s.session.history.is_empty(),"node gesture only chooses candidate")
 s.release(s.AreaUI.ENTER.get_center(),-1);check(s.session.phase=="map","same release cannot enter")
 var old_rng:int=s.rng.state
 tap(s,s.AreaUI.ENTER.get_center());check(s.session.phase=="ready" and s.session.history==["entry"],"explicit entry starts one encounter")
 check(s.rng.state==old_rng,"entry reuses normal initialized board without favorable reroll")
 tap(s,s.AreaUI.ENTER.get_center());check(s.session.actions==0 and s.session.skill_uses==0,"double entry does not leak action")
 # Controller boundary fixtures, separate from normal earned-run tests.
 s.session.combat.enemy_hp=0;s.session.phase="busy";s.session.finish_refill();s.session.choose_relic("pigment",s.session.offer_serial)
 check(s.session.phase=="map","reward returns map")
 point=s.AreaUI.node_rect(2).get_center();tap(s,point);tap(s,s.AreaUI.ENTER.get_center())
 check(s.session.phase=="event" and s.session.gold==4,"event entry carries resources")
 point=s.AreaUI.option_rect(0).get_center();s.press(point,-1);s.cancel_input();s.release(point,-1)
 check(s.session.phase=="event" and s.session.gold==4,"event cancel does not charge or pay")
 tap(s,point);s.release(point,-1)
 check(s.session.phase=="map" and s.session.gold==1 and s.session.relics.size()==2,"paid event commits once and returns map")
 tap(s,s.AreaUI.node_rect(0).get_center());check(s.session.selected_node=="","visited node cannot be entered backward")
 var hp:int=s.session.hp;tap(s,s.board_to_screen(s.session.panels[0].pos))
 check(s.session.hp==hp and s.session.actions==0 and s.session.selection.is_empty(),"map consumes board coordinates without passthrough")
 for phase in ["map","rest","event","spoils","shop","victory","defeat"]:
  s.session.phase=phase;s.session.gold=9;s.session.ash_reserved=true;s.quality_fx.skill_activated()
  tap(s,s.RESET.get_center())
  check(s.session.phase=="departure" and s.session.history.is_empty() and s.session.gold==0 and not s.session.ash_reserved and s.quality_fx.cutin_remaining==0,"reset clears area state: "+phase)
 s.queue_free();await process_frame;await create_timer(.25).timeout
 print("AREA_INPUT checks=",checks," failures=",failures);quit(1 if failures else 0)

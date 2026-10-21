extends SceneTree
## Actual controller fixtures, separate from ordinary native play.
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	await process_frame
	scene.sound.muted=true;scene.record_timings=true
	check(scene.quality_fx.has_method("take_impact"),"controller owns synchronized impact")
	if not scene.quality_fx.has_method("take_impact"):scene.queue_free();await process_frame;quit(1);return
	var chosen:Dictionary={}
	for p in scene.session.panels:
		if scene.session.plan_for(p.id).valid and scene.session.plan_for(p.id).damage>0:chosen=p;break
	var point:Vector2=scene.board_to_screen(chosen.pos)
	var hp:int=scene.session.combat.enemy_hp
	scene.press(point,-1);scene.cancel_input();scene.release(point,-1)
	check(scene.session.combat.enemy_hp==hp and scene.quality_fx.impact_remaining==0,"cancel has no damage or hit")
	scene.press(point,-1);var preview:Dictionary=scene.session.selection.duplicate(true);scene.release(point,-1)
	check(scene.session.combat.enemy_hp==maxi(0,hp-preview.damage) and scene.quality_fx.display_enemy_hp(scene.session.combat.enemy_hp)==hp,"canonical damage commits once while displayed HP waits")
	var now_hp:int=scene.session.combat.enemy_hp
	scene.release(point,-1);check(scene.session.combat.enemy_hp==now_hp and scene.session.actions==1,"stale release cannot hit again")
	var steps:=0
	while scene.quality_fx.impact_remaining==0 and steps<120:
		scene._process(1.0/120);steps+=1
	var hits:Array=scene.timings.filter(func(x):return x.event=="attack_impact")
	check(hits.size()==1 and hits[0].damage==preview.damage and scene.falling,"one hit aligns with existing refill onset")
	check(scene.quality_fx.total_remaining>0 and scene.target_hit>0,"one hit drives number and enemy response")
	scene.press(scene.UI.EFFECTS.get_center(),-1);scene.release(scene.UI.EFFECTS.get_center(),-1)
	check(scene.reduced_effects and scene.quality_fx.stage_offset()==Vector2.ZERO and scene.quality_fx.hit_flash()==0,"effect control works during resolution without visual displacement/flash")
	check(scene.session.actions==1 and scene.session.combat.enemy_hp==now_hp,"effects control cannot consume a board action")
	while scene.session.phase=="busy" and steps<600:scene._process(1.0/120);steps+=1
	check(scene.session.phase=="ready" and scene.quality_fx.display_enemy_hp(now_hp)==now_hp,"visual finish never delays or alters natural readiness")
	check(scene.timings.filter(func(x):return x.event=="attack_impact").size()==1,"longer processing cannot duplicate hit")
	scene.reset_board();check(scene.reduced_effects and scene.quality_fx.impact_remaining==0 and scene.quality_fx.take_impact().is_empty(),"reset clears hit but retains reduced-effects preference")
	# Third-action lethal boundary: ordinary canonical group, explicit enemy fixture.
	chosen={}
	for p in scene.session.panels:
		if scene.session.plan_for(p.id).valid and scene.session.plan_for(p.id).damage>0:chosen=p;break
	point=scene.board_to_screen(chosen.pos)
	var lethal:Dictionary=scene.session.plan_for(chosen.id)
	scene.session.combat.enemy_hp=lethal.damage;scene.session.combat.actions_in_turn=2
	scene.press(point,-1);scene.release(point,-1)
	steps=0
	while scene.session.phase=="busy" and steps<600:scene._process(1.0/120);steps+=1
	check(scene.session.phase=="reward" and scene.session.combat.attacks_total==0 and scene.session.gold==4,"third-action kill rewards once before retaliation")
	var actions:int=scene.session.actions
	scene.press(point,-1);scene.release(point,-1);scene.session.finish_refill()
	check(scene.session.actions==actions and scene.session.gold==4,"resolution and reward modal reject duplicate callback/passthrough")
	var id:String=scene.session.reward_options[0];scene.session.choose_relic(id,scene.session.offer_serial);scene.session.choose_route("elite")
	scene._advance_fight()
	check(scene.session.combat.encounter==1 and scene.quality_fx.impact_remaining==0 and scene.quality_fx.take_impact().is_empty() and scene.quality_fx.display_enemy_hp(44)==44,"new encounter has no stale hit or HP hold")
	scene.reset_board()
	# Heart fixture: healing remains real and cannot produce enemy response.
	scene.session.hp=25
	scene.session.panels=[{"id":1,"kind":"heart","color":4,"radius":37.0,"pos":Vector2(160,450)},{"id":2,"kind":"heart","color":4,"radius":37.0,"pos":Vector2(234,450)}]
	scene.session.next_id=100;scene.visual=scene.session.panels.duplicate(true)
	point=scene.board_to_screen(Vector2(160,450));scene.press(point,-1);scene.release(point,-1)
	for i in range(30):scene._process(1.0/120)
	check(scene.session.hp==29 and scene.session.combat.enemy_hp==24 and scene.quality_fx.damage_amount==0 and scene.quality_fx.impact_remaining==0,"heart healing is separate from attack")
	scene.reset_board();scene._process(0.2)
	check(scene.quality_fx.take_impact().is_empty() and scene.quality_fx.display_enemy_hp(24)==24,"reset during delivery cancels stale pending impact")
	scene.queue_free();await process_frame;await create_timer(0.25).timeout
	print("HIT_SCENE checks=",checks," failures=",failures);quit(1 if failures else 0)

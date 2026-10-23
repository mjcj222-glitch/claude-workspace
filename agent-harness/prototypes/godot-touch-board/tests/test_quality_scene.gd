extends SceneTree
## Actual controller integration fixtures, not a natural/balance run.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	await process_frame
	var names: Array=[]
	for p in scene.get_property_list(): names.append(p.name)
	check(names.has("quality_fx") and names.has("font_display") and names.has("particle_rng"),"scene owns dedicated quality presentation and type resources")
	if not names.has("quality_fx"):
		scene.queue_free(); await process_frame
		print("QUALITY_SCENE checks=",checks," failures=",failures); quit(1); return
	scene.fixed_seed=true
	scene.record_timings=false
	scene.sound.muted=true
	check(scene.font.resource_path.ends_with("Pretendard-Medium.otf") and scene.font_bold.resource_path.ends_with("Pretendard-SemiBold.otf") and scene.font_display.resource_path.ends_with("BlackHanSans-Regular.ttf"),"official imported display and body fonts are active")
	var initial_rng: int=scene.rng.state
	var initial_panels: Array=scene.session.panels.duplicate(true)
	scene.press(scene.SKILL.get_center(),-1);scene.release(scene.SKILL.get_center(),-1)
	check(scene.session.skill_mode and scene.quality_fx.cutin_remaining==0,"opening targeting does not trigger activation strip")
	scene.press(scene.SKILL.get_center(),-1);scene.release(scene.SKILL.get_center(),-1)
	check(not scene.session.skill_mode and scene.quality_fx.cutin_remaining==0,"cancel targeting causes no activation")
	scene.press(scene.SKILL.get_center(),-1);scene.release(scene.SKILL.get_center(),-1)
	var first: Dictionary={}
	for candidate in scene.session.panels:
		if candidate.kind=="normal": first=candidate;break
	scene.session.skill_color=(int(first.color)+1)%4
	var point: Vector2=scene.board_to_screen(first.pos)
	scene.press(point,-1);scene.cancel_input();scene.release(point,-1)
	check(scene.quality_fx.cutin_remaining==0 and scene.session.actions==0,"cancelled skill preview never activates")
	scene.press(point,-1);scene.release(point,-1)
	check(scene.quality_fx.cutin_remaining>0 and scene.quality_fx.cutin_remaining<=0.6 and scene.session.phase=="ready" and scene.session.actions==0,"successful skill shows bounded cutin without gating input or spending action")
	check(scene.rng.state==initial_rng,"skill visuals do not consume game randomness")
	scene.quality_fx.update(0.6)
	check(scene.quality_fx.cutin_remaining==0,"cutin finishes without scheduled gameplay callback")
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	check(scene.session.panels==initial_panels and scene.rng.state==initial_rng and scene.quality_fx.cutin_remaining==0,"reset restores identical normal board and clears effects")
	# Use an actual canonical clear from the normal board, not recolored panels.
	var chosen: Dictionary={}
	for p in scene.session.panels:
		if scene.session.plan_for(p.id).valid: chosen=p;break
	point=scene.board_to_screen(chosen.pos)
	scene.press(point,-1)
	var preview: Dictionary=scene.session.selection.duplicate(true)
	check(scene.selection_trace.size()>0 and scene.quality_fx.total_remaining==0,"actual contact trace appears on preview without committed damage effects")
	scene.release(point,-1)
	check(scene.active_plan==preview and scene.quality_fx.damage_amount==preview.damage and scene.quality_fx.heal_effective==preview.heal_effective,"feedback receives exact committed damage and effective healing")
	var before: int=scene.rng.state
	var legacy:=RandomNumberGenerator.new();legacy.state=before
	for id in preview.sequence:
		for i in range(7):legacy.randf_range(65,180);legacy.randf_range(2,6)
		scene._burst(id,0);scene._burst(id,0)
	check(scene.rng.state==legacy.state,"visual RNG is separate while fixed legacy clear budget preserves next-board RNG")
	check(scene.quality_fx.damage_amount==preview.damage and scene.feedback.count==preview.removed.size(),"duplicate FX reachability cannot change actual count or total damage")
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	check(scene.quality_fx.trails.is_empty() and scene.quality_fx.total_remaining==0 and scene.selection_trace.is_empty(),"reset clears trails, numbers and contact trace")
	# Conversion FX must use the same final color that earned weakness damage.
	var converted_board: Array=[]
	for i in range(3):
		converted_board.append({"id":i+1,"pos":Vector2(160+74*i,450),"radius":37.0,"color":3 if i==0 else 0,"kind":"strong" if i==0 else "normal"})
	scene.session.panels=converted_board.duplicate(true)
	scene.session.next_id=100
	scene.session.combat.start_fight(0,scene.session.panels)
	scene.visual=converted_board.duplicate(true)
	point=scene.board_to_screen(converted_board[0].pos)
	scene.press(point,-1);scene.release(point,-1)
	check(scene.active_plan.effective_colors.get(2)==3,"fixture actually converts red normal into blue before removal")
	scene._burst(2,0)
	check(not scene.quality_fx.trails.is_empty() and scene.quality_fx.trails.back().color==scene.COLORS[3],"damage trail uses committed effective color rather than original panel color")
	scene.queue_free();await process_frame;await process_frame
	print("QUALITY_SCENE checks=",checks," failures=",failures)
	quit(1 if failures else 0)

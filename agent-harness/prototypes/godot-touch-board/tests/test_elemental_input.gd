extends SceneTree
## Scene input fixtures isolate preview/commit integration; they are not balance
## or naturally earned progression evidence. Combat and rule suites own breadth.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void: call_deferred("run")
func panel(id: int, pos: Vector2, color: int, kind: String = "normal") -> Dictionary:
	return {"id":id, "pos":pos, "color":color, "kind":kind, "radius":37.0}
func pair(color: int, kind: String = "normal") -> Array:
	return [panel(1,Vector2(160,450),color,kind),panel(2,Vector2(234,450),color,kind)]
func triple(color: int) -> Array:
	var result: Array=pair(color)
	result.append(panel(3,Vector2(308,450),color))
	return result
func fixture(scene, panels: Array, fight: int = 0, route: String = "safe") -> void:
	scene.reset_board()
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true
	scene.session.panels = panels.duplicate(true)
	scene.session.next_id = 100
	scene.session.route = route
	scene.session.combat.start_fight(fight, scene.session.panels, route)
	scene.visual = scene.session.panels.duplicate(true)
func click(scene, p: Vector2) -> void:
	scene.press(p, -1)
	scene.release(p, -1)
func touch(scene, p: Vector2, index: int, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = p
	event.index = index
	event.pressed = down
	event.canceled = canceled
	scene._input(event)
func point(scene, id: int) -> Vector2:
	for p in scene.session.panels:
		if p.id == id: return scene.board_to_screen(p.pos)
	return Vector2.ZERO
func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	await process_frame
	print("ELEMENTAL_INPUT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	fixture(scene, pair(0))
	var p: Vector2 = point(scene, 1)
	scene.press(p, -1)
	var preview: Dictionary = scene.session.selection.duplicate(true)
	var enriched: bool = preview.get("base_damage", -1) == 2 and preview.get("weak_count", -1) == 2 and preview.get("weak_bonus", -1) == 1 and preview.get("damage", -1) == 3 and not preview.get("combat_context", {}).is_empty()
	check(enriched, "actual scene preview carries base plus weakness and combat context")
	if not enriched:
		await finish(scene)
		return
	check(scene.session.combat.enemy_hp == 24 and scene.session.actions == 0 and scene.session.damage_total == 0, "preview cannot damage or spend action")
	check(preview.combat_context == scene.session.combat.damage_context(), "held preview captures exact current combat context")
	scene._process(0.05)
	check(scene.session.selection == preview, "held preview remains unchanged across presentation frame")
	scene.release(p, -1)
	check(scene.active_plan == preview and scene.active_plan.combat_context == preview.combat_context, "release executes the same enriched snapshot")
	check(scene.session.combat.enemy_hp == 21 and scene.session.damage_total == 3 and scene.session.actions == 1, "base plus weakness commits once to enemy hp and total")
	scene.release(p, -1)
	check(scene.session.combat.enemy_hp == 21 and scene.session.actions == 1, "duplicate release cannot apply weakness twice")
	check(scene.UI.BOARD_SCREEN == Rect2(30,390,660,530) and scene.board_to_screen(scene.BOARD.end) == Vector2(690,920), "premium composition preserves full physical board visibility")

	# Final restored contract: weak pairs or eight ordinary panels qualify;
	# seven ordinary panels do not. floor(W/2) damage remains unchanged.
	fixture(scene,pair(3),2)
	scene.press(point(scene,1),-1)
	preview=scene.session.selection.duplicate(true)
	check(scene.session.combat.damage_context().intent=="slam" and scene.session.combat.incoming_damage==10 and preview.mitigates_intent, "weak pair alone restores approachable slam mitigation")
	check(preview.weak_count==2 and preview.weak_bonus==1 and preview.damage==3, "restored weak pair keeps unchanged damage bonus")
	scene.release(point(scene,1),-1)
	check(scene.session.combat.enemy_hp==45 and scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==4, "restored weak pair commits damage and mitigation")
	var eight: Array=[]
	for i in range(8): eight.append(panel(i+1,Vector2(110+i*74,450),0))
	fixture(scene,eight,2)
	scene.press(point(scene,1),-1)
	check(scene.session.selection.normal_count==8 and scene.session.selection.mitigates_intent and scene.session.combat.damage_context().intent=="slam", "restored eight ordinary panels enable slam mitigation")
	var seven: Array=eight.slice(0,7)
	fixture(scene,seven,2)
	scene.press(point(scene,1),-1)
	check(scene.session.selection.normal_count==7 and not scene.session.selection.mitigates_intent and scene.session.combat.damage_context().intent=="plain", "seven ordinary panels remain below restored threshold")
	var ten: Array=[]
	for i in range(10): ten.append(panel(i+1,Vector2(110+(i%5)*74,450+(i/5)*74),0))
	fixture(scene,ten,2)
	scene.press(point(scene,1),-1)
	preview=scene.session.selection.duplicate(true)
	check(preview.normal_count==10 and preview.weak_count==0 and preview.mitigates_intent and scene.session.combat.damage_context().intent=="slam", "ten ordinary panels still qualify without weakness")
	check(preview.combat_context.get("slam_weak_required",-1)==2 and preview.combat_context.get("slam_normal_required",-1)==8, "held snapshot records canonical restored two-weak eight-normal requirements")
	scene.release(point(scene,1),-1)
	check(scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==4 and scene.session.combat.enemy_hp==38, "ten ordinary committed clear reduces slam without changing base damage")

	for cancel_kind in ["outside", "focus", "system"]:
		fixture(scene, triple(3), 2)
		p = point(scene, 1)
		var before: Dictionary = scene.session.combat.damage_context().duplicate(true)
		check(before.intent == "slam" and before.incoming_damage == 10, "boss feasible weak triple advertises slam")
		if cancel_kind == "system":
			touch(scene,p,0,true)
			touch(scene,p,0,false,true)
			touch(scene,p,0,false)
		else:
			scene.press(p,-1)
			check(scene.session.selection.get("mitigates_intent",false), "eligible boss preview signals mitigation")
			if cancel_kind == "outside": scene.move_pointer(Vector2.ZERO,-1)
			else: scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			scene.release(p,-1)
		check(scene.session.actions == 0 and scene.session.damage_total == 0 and scene.session.combat.enemy_hp == 48, cancel_kind + " cancellation causes no damage/action")
		check(scene.session.combat.damage_context() == before and not scene.session.combat.mitigation_success, cancel_kind + " cancellation cannot latch mitigation")

	fixture(scene,triple(3),2)
	p=point(scene,1)
	scene.session.skill_mode=true
	scene.session.skill_color=0
	click(scene,p)
	check(scene.session.actions==0 and scene.session.combat.actions_in_turn==0 and scene.session.damage_total==0 and scene.session.combat.enemy_hp==48, "skill converts without combat damage or action")
	check(not scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==10, "skill cannot satisfy boss mitigation")
	check(scene.session.charge==0 and scene.session.panels[0].color==0, "skill still consumes charge and converts")

	fixture(scene,triple(3),2)
	p=point(scene,1)
	scene.press(p,-1)
	preview=scene.session.selection.duplicate(true)
	check(preview.weak_count==3 and preview.weak_bonus==1 and preview.mitigates_intent, "single weak triple qualifies boss mitigation")
	scene.release(p,-1)
	check(scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==4 and scene.session.combat.enemy_hp==44, "committed weak triple latches reduced attack and damage")

	# Weakness is evaluated after core conversion; the core itself adds no W.
	var core_board: Array=[panel(1,Vector2(160,450),3,"core"),panel(2,Vector2(234,450),0),panel(3,Vector2(308,450),3),panel(4,Vector2(160,600),4,"heart")]
	fixture(scene,core_board,2)
	p=point(scene,1)
	scene.press(p,-1)
	preview=scene.session.selection.duplicate(true)
	check(preview.base_damage==2 and preview.normal_count==2 and preview.weak_count==2 and preview.weak_bonus==1 and preview.damage==3, "converted normal and connected weak normal count while core does not")
	scene.release(p,-1)
	check(scene.session.combat.enemy_hp==45 and scene.session.damage_total==3 and scene.session.panels.size()==1 and scene.session.panels[0].kind=="heart", "core weakness math commits once and leaves heart")

	fixture(scene,pair(4,"heart"),2)
	scene.session.hp=20
	p=point(scene,1)
	scene.press(p,-1)
	preview=scene.session.selection.duplicate(true)
	check(preview.base_damage==0 and preview.normal_count==0 and preview.weak_count==0 and preview.weak_bonus==0, "hearts do not add base or weakness")
	scene.release(p,-1)
	check(scene.session.hp==24 and scene.session.damage_total==0 and scene.session.combat.enemy_hp==48 and scene.session.actions==1, "heart action heals without weakness damage")

	# No accumulation: each chosen solo core removes one weak normal. A separate
	# untouched triple makes slam feasible at turn start, without being selected.
	var split: Array=[panel(1,Vector2(110,400),3),panel(2,Vector2(184,400),3),panel(9,Vector2(258,400),3),panel(3,Vector2(110,550),3,"core"),panel(4,Vector2(184,550),3),panel(5,Vector2(380,550),3,"core"),panel(6,Vector2(454,550),3),panel(7,Vector2(110,710),3,"core"),panel(8,Vector2(184,710),3)]
	fixture(scene,split,2)
	for id in [3,5]:
		p=point(scene,id)
		scene.press(p,-1)
		check(scene.session.selection.weak_count==1 and not scene.session.selection.mitigates_intent, "one weak normal does not qualify per-action condition")
		scene.release(p,-1)
		scene.session.finish_refill()
		check(not scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==10, "weak normals across separate actions never accumulate")
	scene.press(point(scene,7),-1)
	check(scene.session.selection.weak_count==1 and not scene.session.selection.mitigates_intent, "third separate weak normal still cannot accumulate mitigation")
	scene.release(point(scene,7),-1)
	scene.session.finish_refill()
	check(scene.session.phase=="enemy_attack" and scene.session.hp==20 and scene.session.combat.last_attack_damage==10, "unmet slam resolves ten damage after third action")
	scene.session.finish_attack()
	check(scene.session.phase=="ready" and scene.session.combat.damage_context().intent=="plain" and scene.session.combat.incoming_damage==6, "odd boss turn resets to plain six")

	for route in ["safe","elite"]:
		var group: Array=[]
		for i in range(4): group.append(panel(i+1,Vector2(110+i*74,450),0))
		fixture(scene,group,1,route)
		check(scene.session.combat.damage_context().intent=="direct4", route+" second fight retains direct-four condition")
		scene.press(point(scene,1),-1)
		check(scene.session.selection.mitigates_intent, route+" direct-four preview qualifies")
		scene.release(point(scene,1),-1)
		check(scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==(3 if route=="safe" else 4), route+" direct-four commit preserves reduction")

	fixture(scene,triple(3),2)
	scene.session.combat.enemy_hp=4
	scene.session.combat.actions_in_turn=2
	scene.session.actions=2
	click(scene,point(scene,1))
	scene.session.finish_refill()
	check(scene.session.phase=="victory" and scene.session.hp==30 and scene.session.combat.attacks_total==0, "third-action elemental kill wins without retaliation")

	for phase in ["route","shop"]:
		fixture(scene,triple(3),2)
		scene.press(point(scene,1),-1)
		scene.cancel_input()
		scene.session.phase=phase
		var context: Dictionary=scene.session.combat.damage_context().duplicate(true)
		var hp: int=scene.session.combat.enemy_hp
		click(scene,scene.SKILL.get_center())
		click(scene,scene.board_to_screen(Vector2(60,320)))
		check(scene.session.combat.damage_context()==context and scene.session.combat.enemy_hp==hp and scene.session.damage_total==0, phase+" modal cannot leak elemental damage or mitigation")
		scene.press(scene.RESET.get_center(),-1)
		scene.release(point(scene,scene.session.panels[0].id),-1)
		scene._process(1.0)
		check(scene.session.combat.weak_color==0 and scene.session.combat.enemy_hp==24 and scene.session.damage_total==0 and not scene.session.combat.mitigation_success and scene.session.actions==0, phase+" reset clears weakness context and stale input")
	await finish(scene)

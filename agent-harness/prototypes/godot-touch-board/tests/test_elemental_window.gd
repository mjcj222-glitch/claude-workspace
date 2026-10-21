extends SceneTree
## Actual narrow-window OS input. Fight/turn fixtures below are explicitly
## injected to inspect weakness/intent presentation, not earned-run evidence.
var scene
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void: call_deferred("run")
func gesture(stage: String, point: Vector2, action: String = "click", capture: String = "") -> void:
	scene.queue_redraw()
	scene.board_surface.queue_redraw()
	scene.overlay_surface.queue_redraw()
	await RenderingServer.frame_post_draw
	var actual: Vector2 = root.get_screen_transform() * point + Vector2(root.position)
	var file := FileAccess.open("/tmp/chroma-elemental-window-request.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage, "x":actual.x, "y":actual.y, "action":action, "capture":capture, "window_size":[root.size.x,root.size.y], "window_position":[root.position.x,root.position.y]}))
	file.close()
	var deadline := Time.get_ticks_msec() + 12000
	var acknowledged := false
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists("/tmp/chroma-elemental-window-ack.json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("/tmp/chroma-elemental-window-ack.json"))
			if data is Dictionary and data.get("stage", "") == stage:
				acknowledged = true
				break
		await process_frame
	check(acknowledged, "OS driver acknowledged " + stage)
	await process_frame
	await process_frame
func fixture(fight: int, route: String = "safe") -> void:
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true
	scene.session.route = route
	scene.session.combat.start_fight(fight,scene.session.panels,route)
func weak_candidate() -> Dictionary:
	for p in scene.session.panels:
		var plan: Dictionary=scene.session.plan_for(p.id)
		if plan.get("valid",false) and plan.get("weak_count",0)>=2 and plan.get("activated",[]).is_empty(): return p
	return {}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(int(args[0]),int(args[1]))
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	scene.record_timings=false
	scene.sound.muted=true
	await process_frame
	check(not scene.sandbox,"default actual mode")
	check(scene.UI.BOARD_SCREEN==Rect2(30,268,660,530) and scene.board_to_screen(scene.BOARD.end)==Vector2(690,798),"two status lines preserve full translated board extent")
	var chosen: Dictionary=weak_candidate()
	check(not chosen.is_empty(),"real initial board contains a legal weak-color group")
	if chosen.is_empty(): quit(1);return
	var p: Vector2=scene.board_to_screen(chosen.pos)
	await gesture("first_down",p,"down","first-ready")
	var preview: Dictionary=scene.session.selection.duplicate(true)
	check(preview.get("weak_count",0)>=2 and preview.get("damage",0)==preview.get("base_damage",0)+preview.get("weak_bonus",0),"OS press previews base plus weakness")
	await gesture("first_up",p,"up","first-preview")
	check(scene.active_plan==preview and scene.session.combat.enemy_hp==24-int(preview.damage) and scene.session.damage_total==int(preview.damage),"OS release applies exact weakness snapshot")
	await gesture("first_reset",scene.RESET.get_center())
	check(scene.session.damage_total==0 and scene.session.combat.enemy_hp==24,"OS reset clears elemental damage")
	print("ELEMENTAL_INTENT_FIXTURES: subsequent fights selected explicitly; generated boards remain unchanged")
	for index in range(2):
		var route: String="safe" if index==0 else "elite"
		fixture(1,route)
		check(scene.session.combat.weak_color==(1 if index==0 else 2),route+" weakness color mapped")
		await gesture(route+"_read",Vector2.ZERO,"up",route+"-weakness")
	fixture(2)
	check(scene.session.combat.weak_color==3 and scene.session.combat.damage_context().intent=="slam" and scene.session.combat.incoming_damage==10,"boss feasible opening advertises slam ten and water weakness")
	chosen=weak_candidate()
	check(not chosen.is_empty(),"generated boss fixture has legal weak pair")
	if chosen.is_empty():quit(1);return
	p=scene.board_to_screen(chosen.pos)
	await gesture("boss_down_cancel",p,"down","boss-telegraph")
	check(scene.session.selection.get("mitigates_intent",false),"OS held boss preview reports mitigation eligibility")
	await gesture("boss_outside_up",Vector2.ZERO,"up","boss-preview")
	check(scene.session.actions==0 and scene.session.damage_total==0 and not scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==10,"OS outside release cancels boss damage and mitigation")
	await gesture("boss_down",p,"down")
	preview=scene.session.selection.duplicate(true)
	await gesture("boss_up",p,"up","boss-preview-confirm")
	check(scene.active_plan==preview and scene.session.combat.enemy_hp==48-int(preview.damage) and scene.session.combat.mitigation_success and scene.session.combat.incoming_damage==4,"OS boss qualifying commit applies exact damage and reduces slam")
	# Explicit presentation fixture ends the animation/refill stage without
	# claiming a naturally played turn; gameplay completion is tested elsewhere.
	scene.session.finish_refill()
	scene.visual=scene.session.panels.duplicate(true)
	scene.active_plan={}
	await gesture("boss_success_read",Vector2.ZERO,"up","boss-mitigated")
	check(scene.session.actions==1 and scene.session.combat.actions_in_turn==1,"mitigation presentation does not spend another action")
	await gesture("boss_reset",scene.RESET.get_center())
	check(scene.session.combat.weak_color==0 and scene.session.combat.enemy_hp==24 and scene.session.hp==30 and scene.session.damage_total==0,"OS reset after boss restores first-fight context")
	print("ELEMENTAL_WINDOW checks=",checks," failures=",failures," size=",root.size)
	quit(1 if failures else 0)

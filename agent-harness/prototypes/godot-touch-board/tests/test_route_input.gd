extends SceneTree
## Route/shop scene input fixtures; session/progression suites cover earning them.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void: call_deferred("run")
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
func fresh(scene) -> void:
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true
func route_fixture(scene) -> void:
	fresh(scene)
	scene.session.phase = "route"
	scene.session.combat.enemy_hp = 0
	scene.session.combat.enemies_defeated = 1
	scene.session.relics = ["pigment"]
	scene.session.reward_options = []
	scene.session.rewards_taken = 1
	scene.session.offer_serial = 29
func shop_fixture(scene, funds: int = 12, hp: int = 17) -> void:
	fresh(scene)
	scene.session.phase = "shop"
	scene.session.combat.encounter = 1
	scene.session.combat.enemy_hp = 0
	scene.session.combat.enemies_defeated = 2
	scene.session.route = "elite"
	scene.session.relics = ["pigment", "lens"]
	scene.session.rewards_taken = 2
	scene.session.gold = funds
	scene.session.hp = hp
	scene.session.offer_serial = 41
func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	await process_frame
	print("ROUTE_INPUT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	await process_frame
	# Contract coordinates let missing scene routing fail behaviorally before
	# new UI helpers/session properties exist, without property/parser errors.
	var first := Rect2(64, 350, 592, 140).get_center()
	var second := Rect2(64, 506, 592, 140).get_center()
	var exit_shop := Rect2(84, 670, 552, 88).get_center()
	route_fixture(scene)
	click(scene, first)
	var routed: bool = scene.session.phase == "ready" and scene.session.combat.encounter == 1
	check(routed, "fresh safe route card starts second encounter")
	if not routed:
		await finish(scene)
		return
	check(scene.UI.route_rect(0) == Rect2(64, 350, 592, 140) and scene.UI.route_rect(1) == Rect2(64, 506, 592, 140), "route touch geometry matches contract")
	check(scene.UI.shop_rect(0) == Rect2(64, 350, 592, 140) and scene.UI.shop_rect(1) == Rect2(64, 506, 592, 140), "shop touch geometry matches contract")
	check(scene.session.route == "safe", "first route card maps to safe")
	for choice in [0, 1]:
		route_fixture(scene)
		scene.session.hp = 19
		scene.session.charge = 1
		scene.session.charge_required = 2
		scene.session.ash_reserved = true
		scene.session.gold = 4
		var p: Vector2 = first if choice == 0 else second
		var before: Array = scene.session.panels.duplicate(true)
		scene.release(p, -1)
		check(scene.session.phase == "route", "stale route release does not depart")
		scene.press(p, -1)
		check(scene.session.phase == "route", "route down alone does not depart")
		scene.release(p, 1)
		check(scene.session.phase == "route", "wrong pointer cannot commit route")
		scene.release(p, -1)
		check(scene.session.phase == "ready" and scene.session.combat.encounter == 1 and scene.session.route == ("safe" if choice == 0 else "elite"), "fresh route commits chosen branch without extra between step")
		check(scene.session.panels.size() == 48 and scene.session.panels != before, "route supplies fresh next fight board")
		check(scene.session.hp == 19 and scene.session.charge == 1 and scene.session.charge_required == 2 and scene.session.ash_reserved and scene.session.gold == 4 and scene.session.relics == ["pigment"], "route keeps player resources and relic")
		scene.release(p, -1)
		scene.release(scene.board_to_screen(scene.session.panels[0].pos), -1)
		check(scene.session.actions == 0 and scene.session.selection.is_empty() and scene.session.combat.encounter == 1, "route release cannot double-advance or clear board")

	for phase in ["route", "shop"]:
		if phase == "route": route_fixture(scene)
		else: shop_fixture(scene)
		var starting_hp: int = scene.session.hp
		var starting_gold: int = scene.session.gold
		scene.press(first, -1)
		scene.move_pointer(Vector2.ZERO, -1)
		scene.move_pointer(first, -1)
		scene.release(first, -1)
		check(scene.session.phase == phase and scene.session.gold == starting_gold and scene.session.hp == starting_hp, phase + " outside/reentry cancels card")
		scene.press(first, -1)
		scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		scene.release(first, -1)
		check(scene.session.phase == phase and scene.session.gold == starting_gold and scene.modal_pointer == -99, phase + " focus loss cancels candidate")
		touch(scene, first, 0, true)
		touch(scene, second, 1, true)
		touch(scene, second, 1, false)
		check(scene.session.phase == phase and scene.modal_pointer == 0 and scene.session.gold == starting_gold, phase + " ignores additional finger")
		touch(scene, first, 0, false, true)
		touch(scene, first, 0, false)
		check(scene.session.phase == phase and scene.session.gold == starting_gold and scene.session.hp == starting_hp, phase + " system cancellation keeps modal")
		scene.press(first, -1)
		scene.session.offer_serial += 1
		scene.release(first, -1)
		check(scene.session.phase == phase and scene.session.gold == starting_gold and scene.session.hp == starting_hp, phase + " offer serial change invalidates card")
		scene.press(first, -1)
		scene.release(second, -1)
		check(scene.session.phase == phase and scene.session.gold == starting_gold and scene.session.hp == starting_hp, phase + " release over different card cannot buy or choose")
		click(scene, scene.SKILL.get_center())
		click(scene, scene.UI.owned_rect(0).get_center())
		check(not scene.session.skill_mode and scene.detail_relic == "" and scene.session.selection.is_empty(), phase + " blocks skill and owned detail")
		click(scene, scene.board_to_screen(Vector2(60, 320)))
		check(scene.session.actions == 0 and scene.session.selection.is_empty(), phase + " blocks underlying board")
		scene.press(first, -1)
		scene.press(scene.RESET.get_center(), -1)
		scene.release(first, -1)
		scene._process(1.0)
		check(scene.session.phase == "departure" and scene.session.hp == 30 and scene.session.gold == 0 and scene.session.route == "" and scene.session.relics.is_empty(), phase + " reset clears run and rejects late release")
		check(scene.modal_pointer == -99 and scene.detail_pointer == -99 and scene.session.selection.is_empty(), phase + " reset clears all candidates")

	shop_fixture(scene)
	scene.release(first, -1)
	check(scene.session.gold == 12 and scene.session.hp == 17, "stale shop release cannot spend")
	click(scene, first)
	check(scene.session.phase == "shop" and scene.session.hp == 25 and scene.session.gold == 8 and scene.session.gold_spent == 4 and scene.session.shop_heal_sold, "fresh healing purchase applies eight hp for four gold once")
	scene.release(first, -1)
	click(scene, first)
	check(scene.session.hp == 25 and scene.session.gold == 8 and scene.session.gold_spent == 4, "duplicate/heal sold click cannot charge again")
	click(scene, second)
	check(scene.session.relics == ["pigment", "lens", "ash"] and scene.session.gold == 0 and scene.session.gold_spent == 12 and scene.session.shop_relic_sold, "fresh relic purchase grants only remaining relic for eight gold")
	click(scene, second)
	check(scene.session.relics.size() == 3 and scene.session.gold_spent == 12, "sold relic cannot duplicate")
	scene.release(exit_shop, -1)
	check(scene.session.phase == "shop", "stale exit release cannot leave shop")
	scene.press(exit_shop, -1)
	check(scene.session.phase == "shop", "shop exit waits for release")
	scene.release(exit_shop, -1)
	check(scene.session.phase == "ready" and scene.session.combat.encounter == 2 and scene.session.shop_closed, "fresh exit goes straight to third fight")
	check(scene.session.hp == 25 and scene.session.gold == 0 and scene.session.relics.size() == 3, "shop departure retains purchases")
	scene.release(exit_shop, -1)
	check(scene.session.actions == 0 and scene.session.selection.is_empty(), "shop exit release cannot clear underlying board")

	shop_fixture(scene, 3)
	click(scene, first)
	click(scene, second)
	check(scene.session.gold == 3 and scene.session.hp == 17 and not scene.session.shop_heal_sold and not scene.session.shop_relic_sold and scene.session.relics.size() == 2, "insufficient funds purchases do nothing")
	shop_fixture(scene, 12, 30)
	click(scene, first)
	check(scene.session.hp == 30 and scene.session.gold == 12 and not scene.session.shop_heal_sold, "full health disables heal without payment")
	shop_fixture(scene, 4, 28)
	click(scene, first)
	check(scene.session.hp == 30 and scene.session.gold == 0 and scene.session.gold_spent == 4, "partial useful heal caps at max without free purchase")

	shop_fixture(scene)
	scene.press(exit_shop, -1)
	scene.session.offer_serial += 1
	scene.release(exit_shop, -1)
	check(scene.session.phase == "shop", "changed offer invalidates armed shop exit")
	shop_fixture(scene)
	scene.press(exit_shop, -1)
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene.release(exit_shop, -1)
	check(scene.session.phase == "shop", "focus cancels exit without departure")
	touch(scene, exit_shop, 0, true)
	touch(scene, exit_shop, 1, true)
	touch(scene, exit_shop, 1, false)
	check(scene.session.phase == "shop", "second finger cannot exit shop")
	touch(scene, exit_shop, 0, false, true)
	check(scene.session.phase == "shop", "system-canceled exit keeps shop")
	await finish(scene)

extends SceneTree
## Narrow-window OS routing. All route/shop states below are fixtures, not
## naturally earned progression, balance, or real mobile-device evidence.
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
	var file := FileAccess.open("/tmp/chroma-route-window-request.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage, "x":actual.x, "y":actual.y, "action":action, "capture":capture, "window_size":[root.size.x,root.size.y], "window_position":[root.position.x,root.position.y]}))
	file.close()
	var deadline := Time.get_ticks_msec() + 12000
	var acknowledged := false
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists("/tmp/chroma-route-window-ack.json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("/tmp/chroma-route-window-ack.json"))
			if data is Dictionary and data.get("stage", "") == stage:
				acknowledged = true
				break
		await process_frame
	check(acknowledged, "OS driver acknowledged " + stage)
	await process_frame
	await process_frame
func route_fixture() -> void:
	scene.reset_board()
	scene.session.phase = "route"
	scene.session.gold = 4
	scene.session.combat.enemy_hp = 0
	scene.session.combat.enemies_defeated = 1
	scene.session.relics = ["pigment"]
	scene.session.rewards_taken = 1
	scene.session.offer_serial = 9
func shop_fixture(funds: int = 12, hp: int = 17) -> void:
	scene.reset_board()
	scene.session.phase = "shop"
	scene.session.route = "elite" if funds == 12 else "safe"
	scene.session.combat.encounter = 1
	scene.session.combat.enemy_hp = 0
	scene.session.combat.enemies_defeated = 2
	scene.session.relics = ["pigment", "lens"]
	scene.session.rewards_taken = 2
	scene.session.gold = funds
	scene.session.hp = hp
	scene.session.offer_serial = 17
func run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(int(args[0]), int(args[1]))
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true
	await process_frame
	print("ROUTE_SHOP_FIXTURES: injected earned-modal resources; not natural progression")
	check(not scene.sandbox and scene.session.phase == "ready", "default starts actual game")
	var first: Vector2 = scene.UI.route_rect(0).get_center()
	var second: Vector2 = scene.UI.route_rect(1).get_center()
	var exit_shop: Vector2 = scene.UI.SUMMARY_CONTINUE.get_center()
	route_fixture()
	await gesture("route_stale", first, "up", "route")
	check(scene.session.phase == "route" and scene.session.route == "", "OS stale release keeps route")
	await gesture("route_down", first, "down")
	check(scene.session.phase == "route", "OS route down does not depart")
	await gesture("route_up", first, "up")
	check(scene.session.phase == "ready" and scene.session.combat.encounter == 1 and scene.session.route == "safe", "OS safe route starts fight two")
	await gesture("route_duplicate", first, "up", "safe-fight")
	check(scene.session.actions == 0 and scene.session.selection.is_empty(), "OS route release cannot clear underlying board")
	route_fixture()
	await gesture("route_elite", second)
	check(scene.session.phase == "ready" and scene.session.route == "elite" and scene.session.gold == 4, "OS elite route starts with gold preserved")
	await gesture("elite_read", Vector2.ZERO, "up", "elite-fight")

	shop_fixture()
	var heal: Vector2 = scene.UI.shop_rect(0).get_center()
	var relic: Vector2 = scene.UI.shop_rect(1).get_center()
	await gesture("shop_stale", heal, "up", "shop")
	check(scene.session.gold == 12 and scene.session.hp == 17, "OS stale shop release does not spend")
	await gesture("heal_down", heal, "down")
	check(scene.session.gold == 12 and scene.session.hp == 17, "OS heal down waits for release")
	await gesture("heal_up", heal, "up")
	check(scene.session.hp == 25 and scene.session.gold == 8 and scene.session.shop_heal_sold, "OS healing purchase applies once")
	await gesture("heal_repeat", heal, "click", "heal-sold")
	check(scene.session.hp == 25 and scene.session.gold == 8, "OS repeated sold heal is inert")
	await gesture("relic_buy", relic)
	check(scene.session.relics == ["pigment", "lens", "ash"] and scene.session.gold == 0 and scene.session.shop_relic_sold, "OS remaining relic purchase applies once")
	await gesture("relic_repeat", relic, "click", "shop-sold")
	check(scene.session.gold_spent == 12 and scene.session.relics.size() == 3, "OS sold relic cannot duplicate")
	await gesture("exit_stale", exit_shop, "up")
	check(scene.session.phase == "shop", "OS stale exit release stays shop")
	await gesture("exit_down", exit_shop, "down")
	check(scene.session.phase == "shop", "OS exit down waits")
	await gesture("exit_up", exit_shop, "up")
	check(scene.session.phase == "ready" and scene.session.combat.encounter == 2 and scene.session.shop_closed and scene.session.hp == 25 and scene.session.relics.size() == 3, "OS exit starts third fight with purchased resources")
	await gesture("exit_duplicate", exit_shop, "up", "fight-three")
	check(scene.session.actions == 0 and scene.session.selection.is_empty(), "OS exit does not pass through")
	shop_fixture(3)
	await gesture("poor_heal", heal, "click", "shop-poor")
	await gesture("poor_relic", relic)
	check(scene.session.gold == 3 and scene.session.hp == 17 and not scene.session.shop_heal_sold and not scene.session.shop_relic_sold, "OS unaffordable purchases leave resources unchanged")
	shop_fixture(12, 30)
	await gesture("full_heal", heal, "click", "shop-full-hp")
	check(scene.session.gold == 12 and scene.session.hp == 30 and not scene.session.shop_heal_sold, "OS full health disables healing payment")
	await gesture("shop_reset", scene.RESET.get_center())
	check(scene.session.phase == "ready" and scene.session.route == "" and scene.session.gold == 0 and scene.session.relics.is_empty(), "OS shop reset clears route gold and relics")
	route_fixture()
	await gesture("armed_route", first, "down")
	scene.reset_board()
	route_fixture()
	await gesture("old_route_release", first, "up")
	check(scene.session.phase == "route" and scene.session.route == "", "OS held route across reset cannot choose new offer")
	await gesture("route_reset", scene.RESET.get_center())
	check(scene.session.phase == "ready" and scene.session.gold == 0 and scene.session.hp == 30, "OS route reset starts clean")
	print("ROUTE_WINDOW checks=", checks, " failures=", failures, " size=", root.size)
	quit(1 if failures else 0)

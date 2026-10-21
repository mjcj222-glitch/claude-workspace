extends SceneTree
## Actual XTest input at narrow window sizes. Modal/combat phases are explicit
## routing fixtures, not evidence of naturally completing the three fights.
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
	var file := FileAccess.open("/tmp/chroma-run-window-request.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage, "x":actual.x, "y":actual.y, "action":action, "capture":capture, "window_size":[root.size.x,root.size.y], "window_position":[root.position.x,root.position.y]}))
	file.close()
	var deadline := Time.get_ticks_msec() + 12000
	var acknowledged := false
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists("/tmp/chroma-run-window-ack.json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("/tmp/chroma-run-window-ack.json"))
			if data is Dictionary and data.get("stage", "") == stage:
				acknowledged = true
				break
		await process_frame
	check(acknowledged, "OS driver acknowledged " + stage)
	await process_frame
	await process_frame
func run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(int(args[0]), int(args[1]))
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true
	await process_frame
	check(not scene.sandbox and scene.session.hp == 30, "default actual run starts full")
	check(scene.board_to_screen(scene.BOARD.end) == scene.UI.BOARD_SCREEN.end, "board screen translation keeps entire field")
	check(scene.session.combat.telegraph_text() == "3회 소거 후 공격 4", "first fight telegraph is actionable")
	await gesture("skill", scene.SKILL.get_center(), "click", "ready")
	check(scene.session.skill_mode, "OS click enables skill")
	await gesture("color", scene.UI.color_rect(3).get_center(), "click", "palette")
	check(scene.session.skill_color == 3, "OS click picks fourth color")
	var panel: Dictionary = {}
	for p in scene.session.panels:
		if p.kind == "normal": panel = p; break
	await gesture("convert", scene.board_to_screen(panel.pos))
	check(scene.session.charge == 0 and scene.session.actions == 0, "OS board click converts without spending combat action")
	await gesture("reset", scene.RESET.get_center())
	check(scene.session.hp == 30 and scene.session.charge == 3, "OS reset fresh run")
	print("COMBAT_MODAL_FIXTURES: phases below injected for OS routing; not natural run proof")
	scene.session.phase = "enemy_attack"
	scene.session.combat.last_attack_damage = 4
	scene.session.hp = 26
	await gesture("attack_skill", scene.SKILL.get_center(), "click", "enemy-attack")
	check(not scene.session.skill_mode and scene.session.hp == 26, "OS skill input blocked during enemy attack")
	await gesture("attack_reset", scene.RESET.get_center())
	scene._process(1.0)
	check(scene.session.phase == "ready" and scene.session.hp == 30, "OS attack reset cannot later damage new run")
	scene.session.phase = "reward"
	scene.session.reward_options = ["pigment", "lens", "ash"]
	scene.session.offer_serial = 4
	scene.session.reward_round = 1
	scene.session.combat.enemy_hp = 0
	scene.session.combat.enemies_defeated = 1
	var card: Vector2 = scene.UI.reward_rect(0, 3).get_center()
	await gesture("reward_stale", card, "up", "reward")
	check(scene.session.phase == "reward" and scene.session.relics.is_empty(), "OS stale release cannot choose reward")
	await gesture("reward_choose", card)
	check(scene.session.phase == "between" and scene.session.relics == ["pigment"], "OS reward selection waits between fights")
	var next: Vector2 = scene.UI.NEXT_BATTLE.get_center()
	await gesture("next_stale", next, "up", "between")
	check(scene.session.phase == "between" and scene.session.combat.encounter == 0, "OS old release cannot advance fight")
	await gesture("next_down", next, "down")
	check(scene.session.phase == "between", "OS next down has no advance")
	await gesture("next_up", next, "up")
	check(scene.session.phase == "ready" and scene.session.combat.encounter == 1 and scene.session.relics == ["pigment"], "OS fresh next completes exactly once and carries relic")
	await gesture("next_duplicate", next, "up", "fight-two")
	check(scene.session.actions == 0 and scene.session.selection.is_empty(), "OS duplicated next release cannot clear board")
	await gesture("owned", scene.UI.owned_rect(0).get_center())
	check(scene.detail_relic == "pigment", "OS owned relic detail remains reachable in next fight")
	await gesture("owned_close", scene.UI.DETAIL_CLOSE.get_center(), "click", "owned-detail")
	check(scene.detail_relic == "" and scene.session.actions == 0, "OS detail closes without clear")
	for phase in ["victory", "defeat"]:
		scene.session.phase = phase
		scene.session.hp = 0 if phase == "defeat" else 17
		await gesture(phase + "_stale", next, "up", phase)
		check(scene.session.phase == phase, "OS terminal stale release remains " + phase)
		await gesture(phase + "_restart", next)
		check(scene.session.phase == "ready" and scene.session.hp == 30 and scene.session.relics.is_empty() and scene.session.charge == 3, "OS fresh restart from " + phase)
	print("RUN_WINDOW checks=", checks, " failures=", failures, " size=", root.size)
	quit(1 if failures else 0)

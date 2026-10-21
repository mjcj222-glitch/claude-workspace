extends SceneTree
## Input-routing integration only. Injected phases/relics isolate transitions;
## test_run_session proves combat progression and earned reward accounting.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _initialize() -> void:
	call_deferred("run")

func touch(scene, point: Vector2, index: int, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = down
	event.canceled = canceled
	scene._input(event)

func click(scene, point: Vector2) -> void:
	scene.press(point, -1)
	scene.release(point, -1)

func fresh(scene) -> void:
	scene.reset_board()
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true

func offer(scene) -> void:
	fresh(scene)
	scene.session.phase = "reward"
	scene.session.reward_options = ["pigment", "lens", "ash"]
	scene.session.offer_serial = 17
	scene.session.reward_round = 1
	scene.session.combat.enemy_hp = 0
	scene.session.combat.enemies_defeated = 1

func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	await process_frame
	print("RUN_INPUT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	if scene.get("sandbox") == null:
		check(false, "scene exposes explicit sandbox versus actual-run mode")
		await finish(scene)
		return
	check(not scene.sandbox, "default entry is actual run")
	check(scene.session.get("combat") != null, "default session owns combat")
	if scene.session.get("combat") == null:
		await finish(scene)
		return
	check(scene.session.hp == 30 and scene.session.charge == 3, "actual run begins full and skill ready")
	var next: Vector2 = scene.UI.SUMMARY_CONTINUE.get_center()
	check(scene.UI.SUMMARY_CONTINUE == Rect2(84, 670, 552, 88), "next/restart shared hitbox remains explicit")
	var card: Vector2 = scene.UI.reward_rect(0, 3).get_center()
	var owned: Vector2 = scene.UI.owned_rect(0).get_center()

	offer(scene)
	scene.release(card, -1)
	check(scene.session.phase == "reward" and scene.session.relics.is_empty(), "stale release cannot choose reward")
	scene.press(card, -1)
	scene.move_pointer(Vector2.ZERO, -1)
	scene.release(card, -1)
	check(scene.session.phase == "reward" and scene.session.relics.is_empty(), "outside then reentry cancels reward choice")
	scene.press(card, -1)
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene.release(card, -1)
	check(scene.session.phase == "reward" and scene.modal_pointer == -99, "focus cancellation retains reward")
	touch(scene, card, 0, true)
	touch(scene, scene.UI.reward_rect(1, 3).get_center(), 1, true)
	touch(scene, scene.UI.reward_rect(1, 3).get_center(), 1, false)
	check(scene.session.relics.is_empty() and scene.modal_pointer == 0, "extra finger cannot choose reward")
	touch(scene, card, 0, false, true)
	touch(scene, card, 0, false)
	check(scene.session.phase == "reward" and scene.session.relics.is_empty(), "system cancel and stale touch-up retain reward")

	scene.press(card, -1)
	scene.session.offer_serial += 1
	scene.release(card, -1)
	check(scene.session.phase == "reward" and scene.session.relics.is_empty(), "changed offer serial invalidates armed choice")
	click(scene, card)
	check(scene.session.phase == "between" and scene.session.relics == ["pigment"], "reward choice enters between instead of ready")
	check(scene.session.rewards_taken == 1 and scene.session.combat.encounter == 0, "choice is atomic and does not advance encounter")
	scene.release(card, -1)
	scene.release(next, -1)
	scene._process(0.1)
	check(scene.session.phase == "between" and scene.session.combat.encounter == 0, "held old release and elapsed frames cannot auto-advance")

	var previous_board: Array = scene.session.panels.duplicate(true)
	scene.session.hp = 17
	scene.session.charge = 1
	scene.session.charge_required = 2
	scene.session.ash_reserved = true
	scene.press(next, -1)
	check(scene.session.phase == "between", "next button down waits for matching release")
	scene.release(next, 1)
	check(scene.session.phase == "between", "wrong pointer cannot advance next battle")
	scene.release(next, -1)
	check(scene.session.phase == "ready" and scene.session.combat.encounter == 1, "fresh next gesture advances exactly one encounter")
	check(scene.session.panels.size() == 48 and scene.session.panels != previous_board, "next encounter receives a fresh full board")
	check(scene.session.hp == 17 and scene.session.charge == 1 and scene.session.charge_required == 2 and scene.session.ash_reserved and scene.session.relics == ["pigment"], "next fight retains hp charge and growth state")
	scene.release(next, -1)
	scene.release(scene.board_to_screen(scene.session.panels[0].pos), -1)
	check(scene.session.actions == 0 and scene.session.selection.is_empty() and scene.session.combat.encounter == 1, "duplicate next release cannot clear underlying board or advance again")

	for phase in ["between", "victory", "defeat"]:
		fresh(scene)
		scene.session.phase = phase
		scene.session.combat.enemy_hp = 0
		scene.press(next, -1)
		scene.move_pointer(Vector2.ZERO, -1)
		scene.move_pointer(next, -1)
		scene.release(next, -1)
		check(scene.session.phase == phase, phase + " outside cancellation keeps modal")
		scene.press(next, -1)
		scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		scene.release(next, -1)
		check(scene.session.phase == phase and scene.modal_pointer == -99, phase + " focus cancellation keeps modal")
		touch(scene, next, 0, true)
		touch(scene, next, 1, true)
		touch(scene, next, 1, false)
		check(scene.session.phase == phase and scene.modal_pointer == 0, phase + " ignores extra finger")
		touch(scene, next, 0, false, true)
		scene.release(next, -1)
		check(scene.session.phase == phase, phase + " system cancel preserves modal")

	for phase in ["busy", "enemy_attack", "reward", "between", "victory", "defeat"]:
		fresh(scene)
		scene.session.phase = phase
		scene.session.relics = ["pigment"]
		scene.session.reward_options = ["lens", "ash"] if phase == "reward" else []
		var before: Array = scene.session.panels.duplicate(true)
		click(scene, scene.SKILL.get_center())
		check(not scene.session.skill_mode, phase + " blocks skill toggle")
		click(scene, owned)
		check(scene.detail_relic == "", phase + " blocks owned detail")
		# Top board location avoids reward/next buttons; modal clicks are not
		# treated as board gestures even where presentation overlays the board.
		var board_point: Vector2 = scene.board_to_screen(Vector2(60, 320))
		click(scene, board_point)
		check(scene.session.selection.is_empty() and scene.session.panels == before and scene.session.actions == 0, phase + " blocks board preview and clear")
		scene.cancel_input()

	for phase in ["victory", "defeat"]:
		fresh(scene)
		scene.session.phase = phase
		scene.session.hp = 0 if phase == "defeat" else 13
		scene.session.relics = ["ash", "lens"]
		scene.session.ash_reserved = true
		scene.session.charge = 1
		scene.session.charge_required = 2
		scene.release(next, -1)
		check(scene.session.phase == phase, phase + " stale release cannot restart")
		click(scene, next)
		check(scene.session.phase == "ready" and scene.session.hp == 30 and scene.session.charge == 3 and scene.session.charge_required == 3, phase + " fresh restart restores health and charge")
		check(scene.session.relics.is_empty() and not scene.session.ash_reserved and scene.session.actions == 0 and scene.session.combat.encounter == 0, phase + " restart clears run growth and counters")
		scene.release(next, -1)
		check(scene.session.actions == 0 and scene.session.selection.is_empty(), phase + " restart release cannot select board")

	for phase in ["busy", "enemy_attack", "reward", "between", "victory", "defeat"]:
		fresh(scene)
		scene.session.phase = phase
		scene.session.hp = 9
		scene.attack_clock = 0.35
		scene.motion_state = {"old_run":true}
		scene.active_plan = {"old_run":true}
		scene.particles = [{"old_run":true}]
		scene.feedback.visible = true
		scene.modal_pointer = -1
		scene.modal_phase = phase
		scene.modal_index = 0
		# Reset is the one accepted action even during attack/busy animation.
		scene.press(scene.RESET.get_center(), -1)
		check(scene.session.phase == "ready" and scene.session.hp == 30, phase + " reset works immediately")
		check(scene.attack_clock == 0 and scene.motion_state.is_empty() and scene.active_plan.is_empty() and scene.particles.is_empty() and not scene.feedback.visible, phase + " reset clears delayed presentation state")
		check(scene.modal_pointer == -99 and scene.detail_pointer == -99 and scene.session.owner == -99 and scene.session.selection.is_empty(), phase + " reset cancels all candidates")
		scene.release(next, -1)
		scene._process(1.0)
		check(scene.session.hp == 30 and scene.session.phase == "ready" and scene.session.actions == 0 and scene.session.combat.attacks_total == 0, phase + " late process and release cannot damage fresh run")
	await finish(scene)

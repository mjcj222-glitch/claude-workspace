extends SceneTree
## Routing integration fixtures intentionally inject owned relics and phases.
## Reward acquisition itself is covered by test_growth_session/play_growth.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

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

func escape(scene) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	scene._input(event)

func fixture(scene) -> void:
	scene.reset_board()
	scene.session.relics = ["pigment", "lens", "ash"]
	scene.session.phase = "ready"
	scene.session.panels = [
		{"id": 101, "pos": Vector2(200, 800), "radius": 30.0, "color": 0, "kind": "normal"},
		{"id": 102, "pos": Vector2(260, 800), "radius": 30.0, "color": 0, "kind": "normal"},
		{"id": 103, "pos": Vector2(200, 440), "radius": 30.0, "color": 1, "kind": "normal"},
		{"id": 104, "pos": Vector2(260, 440), "radius": 30.0, "color": 1, "kind": "normal"},
	]
	scene.visual = scene.session.panels.duplicate(true)
	scene.primary_touch = -99

func _initialize() -> void:
	call_deferred("run")

func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	print("RELIC DETAILS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.record_timings = false
	scene.sound.muted = true
	scene.set_process(false)
	await process_frame
	# A missing feature is an assertion, not an invalid-property/runtime failure.
	if scene.get("detail_relic") == null:
		check(false, "owned relic detail routing exists (detail_relic)")
		await finish(scene)
		return
	fixture(scene)
	var first: Vector2 = scene.UI.owned_rect(0).get_center()
	var second: Vector2 = scene.UI.owned_rect(1).get_center()
	var third: Vector2 = scene.UI.owned_rect(2).get_center()
	var close: Vector2 = scene.UI.DETAIL_CLOSE.get_center()
	var outside: Vector2 = scene.board_to_screen(Vector2(200, 800))
	var inside: Vector2 = scene.board_to_screen(Vector2(200, 440))
	check(scene.UI.owned_rect(0) == Rect2(180, 974, 88, 88) and scene.UI.owned_rect(2) == Rect2(388, 974, 88, 88), "owned icons expose agreed touch hitboxes")
	check(scene.UI.DETAIL_PANEL == Rect2(48, 310, 624, 430) and scene.UI.DETAIL_CLOSE == Rect2(84, 650, 552, 88), "detail panel and close bounds match contract")
	scene.press(first, -1)
	check(scene.detail_relic == "", "owned icon press alone does not open detail")
	scene.release(first, -1)
	check(scene.detail_relic == "pigment" and scene.session.phase == "ready", "matching release opens owned detail without changing ready phase")
	check(scene.session.actions == 0 and scene.session.selection.is_empty(), "opening detail does not consume an action or select board")
	var before: Array = scene.session.panels.duplicate(true)
	click(scene, inside)
	check(scene.detail_relic == "pigment" and scene.session.selection.is_empty(), "touch inside panel stays open and cannot select underlying board")
	check(scene.session.panels == before and scene.session.actions == 0, "inside modal touch preserves board and counters")
	click(scene, scene.UI.SKILL.get_center())
	check(not scene.session.skill_mode and scene.session.actions == 0, "outside skill-button gesture never toggles underlying skill")
	check(scene.detail_relic == "", "fresh outside-panel gesture closes detail")
	click(scene, second)
	check(scene.detail_relic == "lens", "second owned icon opens corresponding relic")
	scene.release(outside, -1)
	check(scene.detail_relic == "lens" and scene.session.actions == 0, "stray release cannot close modal or clear board")
	scene.press(outside, -1)
	check(scene.detail_relic == "lens" and scene.session.selection.is_empty(), "outside down waits for release while board remains blocked")
	scene.release(outside, -1)
	check(scene.detail_relic == "" and scene.session.actions == 0 and scene.session.selection.is_empty(), "outside closing release cannot pass through to board")
	scene.release(outside, -1)
	check(scene.session.actions == 0, "duplicate closing release consumes no action")
	click(scene, third)
	check(scene.detail_relic == "ash", "third owned icon opens corresponding relic")
	click(scene, close)
	check(scene.detail_relic == "" and scene.session.actions == 0, "close-button fresh gesture closes only detail")
	click(scene, first)
	escape(scene)
	check(scene.detail_relic == "", "Escape closes detail")

	fixture(scene)
	scene.press(first, -1)
	scene.release(second, -1)
	check(scene.detail_relic == "", "down and release on different icons cannot open detail")
	scene.press(first, -1)
	scene.move_pointer(Vector2(5, 5), -1)
	scene.release(first, -1)
	check(scene.detail_relic == "", "leaving icon cancels candidate even after reentry")
	scene.press(first, -1)
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene.release(first, -1)
	check(scene.detail_relic == "", "focus loss cancels pending icon opening")
	touch(scene, first, 0, true)
	touch(scene, first, 0, false, true)
	check(scene.detail_relic == "", "system canceled icon touch never opens detail")
	click(scene, first)
	scene.press(close, -1)
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene.release(close, -1)
	check(scene.detail_relic == "pigment", "focus loss cancels close candidate but retains open detail")
	touch(scene, close, 0, true)
	touch(scene, close, 0, false, true)
	check(scene.detail_relic == "pigment", "system canceled close gesture retains open detail")
	escape(scene)

	fixture(scene)
	touch(scene, first, 0, true)
	touch(scene, second, 1, true)
	touch(scene, second, 1, false)
	check(scene.detail_relic == "", "second finger cannot complete first icon press")
	touch(scene, first, 0, false)
	check(scene.detail_relic == "pigment", "first finger keeps its original icon ownership")
	touch(scene, inside, 0, true)
	touch(scene, close, 1, true)
	touch(scene, close, 1, false)
	touch(scene, inside, 0, false)
	check(scene.detail_relic == "pigment", "second finger cannot close an open detail")
	escape(scene)

	fixture(scene)
	scene.press(outside, -1)
	var preview: Dictionary = scene.session.selection.duplicate(true)
	check(preview.get("valid", false), "existing board preview still starts when detail is closed")
	scene.press(first, 1)
	scene.release(first, 1)
	check(scene.detail_relic == "" and scene.session.selection == preview, "owned icon cannot interrupt active board preview")
	scene.release(outside, -1)
	check(scene.active_plan == preview and scene.session.actions == 1, "existing board release executes its unchanged preview")
	click(scene, first)
	check(scene.detail_relic == "", "busy board does not open owned detail")

	fixture(scene)
	scene.session.skill_mode = true
	click(scene, first)
	check(scene.detail_relic == "" and scene.session.skill_mode, "skill palette hides owned icon hit targets")
	for phase in ["reward", "summary"]:
		fixture(scene)
		scene.session.phase = phase
		scene.session.reward_options = ["pigment", "lens", "ash"] if phase == "reward" else []
		click(scene, first)
		check(scene.detail_relic == "" and scene.session.phase == phase, "%s modal prevents owned detail routing" % phase)

	fixture(scene)
	click(scene, first)
	click(scene, scene.UI.RESET.get_center())
	check(scene.detail_relic == "" and scene.session.relics.is_empty() and scene.session.actions == 0 and scene.session.phase == "ready", "reset allowed while detail open and clears all detail/session state")
	scene.release(close, -1)
	check(scene.session.actions == 0 and scene.detail_relic == "", "stale detail release after reset has no effect")
	fixture(scene)
	scene.press(first, -1)
	scene.reset_board()
	scene.release(first, -1)
	check(scene.detail_relic == "" and scene.session.relics.is_empty() and scene.session.selection.is_empty(), "reset clears pending icon candidate before stale release")
	await finish(scene)

extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.record_timings = false
	await process_frame
	check(scene.session.panels.size() == 48, "actual scene creates dense free-position board")
	var chosen: Dictionary = {}
	for p in scene.session.panels:
		var plan: Dictionary = scene.Rules.plan(scene.session.panels, p.id, scene.session.hp, scene.session.max_hp)
		if plan.valid and plan.direct.size() >= 6:
			chosen = p
			break
	check(not chosen.is_empty(), "first board offers core creation")
	if chosen.is_empty(): quit(1); return
	var ui_first := InputEventScreenTouch.new()
	ui_first.index = 0
	ui_first.pressed = true
	ui_first.position = Vector2(5, 5)
	scene._input(ui_first)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = chosen.pos
	scene._input(second)
	check(scene.session.selection.is_empty(), "UI/background first finger blocks extra finger")
	second.pressed = false
	scene._input(second)
	ui_first.pressed = false
	scene._input(ui_first)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = chosen.pos
	scene._input(down)
	check(not scene.session.selection.is_empty(), "real touch handler selects")
	var other := InputEventScreenTouch.new()
	other.index = 1
	other.pressed = true
	other.position = chosen.pos
	scene._input(other)
	check(scene.session.owner == 0, "real second touch ignored")
	down.pressed = false
	down.canceled = true
	scene._input(down)
	check(scene.session.selection.is_empty() and scene.session.actions == 0, "real system cancellation no action")
	down.canceled = false
	down.pressed = true
	scene._input(down)
	var preview: Dictionary = scene.session.selection.duplicate(true)
	down.pressed = false
	scene._input(down)
	check(scene.active_plan == preview, "actual scene consumes exact shown plan")
	check(scene.session.phase == "busy", "refill input gate starts")
	scene.press(Vector2(620, 50), -1)
	check(scene.session.actions == 1 and scene.session.phase == "busy", "busy UI reset discarded")
	down.pressed = true
	scene._input(down)
	check(scene.session.selection.is_empty(), "busy touch discarded")
	for i in range(150): scene._process(1.0/120)
	check(scene.session.phase == "ready", "controlled fall unlocks without full physics sleep")
	check(scene.session.actions == 1, "refill never auto clears or consumes action")
	check(scene.session.panels.size() == 48, "one refill restores 48")
	var cores := 0
	for p in scene.session.panels:
		if p.kind in ["core", "strong"]: cores += 1
	check(cores == 1, "new generated core survives same action")
	down.pressed = false
	scene._input(down)
	check(scene.session.actions == 1, "busy press cannot execute on later release")
	scene.queue_free()
	await process_frame
	await process_frame
	# AudioServer releases playback on its mixing thread, not process-frame count.
	await create_timer(0.25).timeout
	print("SCENE failures=", failures)
	quit(1 if failures else 0)

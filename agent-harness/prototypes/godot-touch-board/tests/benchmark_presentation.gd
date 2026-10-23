extends SceneTree
func _initialize() -> void: call_deferred("run")
func accept_reward(scene) -> void:
	if scene.session.phase != "reward": return
	var point:Vector2=scene.UI.reward_rect(0,scene.session.reward_options.size()).get_center()
	scene.press(point,-1)
	await create_timer(0.08).timeout
	scene.release(point,-1)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	for i in range(5): await process_frame
	for trial in range(5):
		var best: Dictionary = {}
		var best_size := 999
		for p in scene.session.panels:
			var plan: Dictionary = scene.session.plan_for(p.id)
			if plan.valid and plan.activated.is_empty() and plan.removed.size() < best_size and p.kind == "normal":
				best = p
				best_size = plan.removed.size()
		if best.is_empty(): break
		scene.press(scene.board_to_screen(best.pos),-1)
		await create_timer(0.15).timeout
		scene.release(scene.board_to_screen(best.pos),-1)
		while scene.session.phase == "busy": await process_frame
		await accept_reward(scene)
		if scene.session.phase != "ready":
			printerr("BENCHMARK stalled")
			quit(1)
			return
		await create_timer(0.15).timeout
	# Separate explicit long-chain fixture using actual current contacts/renderer.
	for p in scene.session.panels:
		if p.kind != "heart": p.color = 0
	var normals: Array = scene.session.panels.filter(func(p): return p.kind != "heart")
	normals[0].kind = "strong"
	var graph: Dictionary = scene.Rules.contact_graph(scene.session.panels)
	for panel in normals:
		if panel.id in graph[normals[0].id]:
			panel.kind = "core"
			break
	scene.visual = scene.session.panels.duplicate(true)
	await process_frame
	scene.press(scene.board_to_screen(normals[0].pos),-1)
	await create_timer(0.15).timeout
	scene.release(scene.board_to_screen(normals[0].pos),-1)
	while scene.session.phase == "busy": await process_frame
	await accept_reward(scene)
	if scene.session.phase != "ready":
		printerr("BENCHMARK stalled")
		quit(1)
		return
	var output := "res://evidence/presentation/before.json" if "--before" in OS.get_cmdline_user_args() else "res://evidence/presentation/after.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"llvmpipe software OpenGL", "method":"live rendered process frames; engine-dispatched input, no movie mode; first reward chosen after action3; long-chain board is an explicit fixture", "relics":scene.session.relics, "timings":scene.timings},"  "))
	await create_timer(0.3).timeout
	quit()

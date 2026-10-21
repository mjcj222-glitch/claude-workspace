extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	for trial in range(5):
		var best: Dictionary = {}
		var best_size := 999
		for p in scene.session.panels:
			var plan: Dictionary = scene.Rules.plan(scene.session.panels,p.id,scene.session.hp,scene.session.max_hp)
			if plan.valid and plan.activated.is_empty() and plan.removed.size() < best_size and p.kind == "normal":
				best = p
				best_size = plan.removed.size()
		if best.is_empty(): break
		scene.press(best.pos,-1)
		await create_timer(0.15).timeout
		scene.release(best.pos,-1)
		while scene.session.phase == "busy": await process_frame
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
	scene.press(normals[0].pos,-1)
	await create_timer(0.15).timeout
	scene.release(normals[0].pos,-1)
	while scene.session.phase == "busy": await process_frame
	if scene.session.phase != "ready":
		printerr("BENCHMARK stalled")
		quit(1)
		return
	var file := FileAccess.open("res://evidence/motion-fix/live-timings.json" if "--motion-fix" in OS.get_cmdline_user_args() else "res://evidence/live-timings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"llvmpipe software OpenGL", "method":"live rendered process frames; engine-dispatched input, no movie mode", "timings":scene.timings},"  "))
	await create_timer(0.3).timeout
	quit()

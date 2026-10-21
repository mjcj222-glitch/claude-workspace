extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var prefix := "res://evidence/polish/" if "--polish" in OS.get_cmdline_user_args() else "res://evidence/"
	var suffix := "-small" if "--small" in OS.get_cmdline_user_args() else ""
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix + "board-ready" + suffix + ".png")
	for p in scene.session.panels:
		var plan: Dictionary = scene.Rules.plan(scene.session.panels, p.id, scene.session.hp, scene.session.max_hp)
		if plan.valid and plan.direct.size() >= 6:
			scene.press(scene.board_to_screen(p.pos), -1)
			break
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix + "board-preview" + suffix + ".png")
	quit()

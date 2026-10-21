extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.4).timeout
	for p in scene.session.panels:
		if scene.Rules.plan(scene.session.panels,p.id,scene.session.hp,scene.session.max_hp).valid:
			var f := FileAccess.open("/tmp/chroma-os-point.json",FileAccess.WRITE)
			f.store_string(JSON.stringify({"x":p.pos.x,"y":p.pos.y}))
			f.close()
			break
	await create_timer(8.0).timeout
	print("OS_POINTER actions=",scene.session.actions," damage=",scene.session.damage_total," phase=",scene.session.phase)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/os-pointer-after.png")
	quit(0 if scene.session.actions == 1 and scene.session.phase == "ready" else 1)

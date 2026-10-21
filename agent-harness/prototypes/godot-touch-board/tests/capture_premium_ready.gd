extends SceneTree
## Actual first skill via ordinary scene input. No board/charge/HP fixtures.
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/premium/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/premium"))
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	await capture("ready-first-actual")
	scene.press(scene.SKILL.get_center(),-1);scene.release(scene.SKILL.get_center(),-1)
	scene.press(scene.UI.color_rect(0).get_center(),-1);scene.release(scene.UI.color_rect(0).get_center(),-1)
	var target:=Vector2.ZERO
	for p in scene.session.panels:
		if p.id==34:target=scene.board_to_screen(p.pos)
	scene.press(target,-1)
	await create_timer(0.20).timeout
	scene.release(target,-1)
	await create_timer(0.65).timeout
	await capture("charging-first-actual")
	print("PREMIUM_ACTUAL_FIRST_SKILL charge=",scene.session.charge,"/",scene.session.charge_required," actions=",scene.session.actions," phase=",scene.session.phase," portrait=original-temporary")
	quit(0 if scene.session.charge==0 and scene.session.actions==0 and scene.session.phase=="ready" else 1)

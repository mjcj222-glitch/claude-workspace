extends SceneTree
var scene
var failures:=0
var prefix:String
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func signal_click(name:String,point:Vector2)->void:
	await RenderingServer.frame_post_draw
	var actual:Vector2=root.get_screen_transform()*point + Vector2(root.position)
	var f:=FileAccess.open("/tmp/chroma-small-click.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage":name,"x":actual.x,"y":actual.y,"window_size":[root.size.x,root.size.y],"window_position":[root.position.x,root.position.y]}))
	f.close()
func run()->void:
	var args:=OS.get_cmdline_user_args()
	root.size=Vector2i(int(args[0]),int(args[1]))
	await process_frame
	print("SCALE mode=",root.content_scale_mode," factor=",root.content_scale_factor," base=",root.content_scale_size)
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	prefix="res://evidence/polish/small-%dx%d"%[root.size.x,root.size.y]
	await create_timer(0.3).timeout
	check(scene.board_to_screen(scene.BOARD.position)==scene.UI.BOARD_SCREEN.position,"board top coordinate correspondence")
	check(scene.board_to_screen(scene.BOARD.end)==scene.UI.BOARD_SCREEN.end,"full board extent remains visible")
	var initial_color:int=scene.session.skill_color
	scene.press(scene.UI.color_rect(3).get_center(),-1)
	check(scene.session.skill_color==initial_color,"hidden palette does not accept input")
	await signal_click("skill",scene.SKILL.get_center())
	var deadline:=Time.get_ticks_msec()+12000
	while not scene.session.skill_mode and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.session.skill_mode,"OS click opens skill")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix+"-palette.png")
	await signal_click("color",scene.UI.color_rect(3).get_center())
	deadline=Time.get_ticks_msec()+12000
	while scene.session.skill_color!=3 and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.session.skill_color==3,"OS click selects fourth color")
	var chosen:Dictionary={}
	for p in scene.session.panels:
		if p.kind=="normal":chosen=p;break
	await signal_click("panel",scene.board_to_screen(chosen.pos))
	deadline=Time.get_ticks_msec()+12000
	while scene.session.charge==3 and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.session.charge==0,"translated OS panel click executes skill")
	check(scene.session.actions==0,"skill does not spend clear action")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix+"-after.png")
	await signal_click("reset",scene.RESET.get_center())
	deadline=Time.get_ticks_msec()+12000
	while scene.session.charge!=3 and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.session.charge==3 and scene.session.damage_total==0,"OS reset works")
	await signal_click("done",Vector2.ZERO)
	print("SMALL_WINDOW failures=",failures," window=",root.size," content=",root.get_texture().get_size())
	await create_timer(0.3).timeout
	quit(1 if failures else 0)

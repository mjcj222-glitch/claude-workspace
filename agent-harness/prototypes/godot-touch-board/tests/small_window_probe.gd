extends SceneTree
var scene
var failures:=0
var prefix:String
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func signal_click(name:String,point:Vector2,action:String="click",capture:String="")->void:
	await RenderingServer.frame_post_draw
	var actual:Vector2=root.get_screen_transform()*point + Vector2(root.position)
	var f:=FileAccess.open("/tmp/chroma-small-click.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage":name,"action":action,"capture":capture,"x":actual.x,"y":actual.y,"window_size":[root.size.x,root.size.y],"window_position":[root.position.x,root.position.y]}))
	f.close()
func run()->void:
	var args:=OS.get_cmdline_user_args()
	root.size=Vector2i(int(args[0]),int(args[1]))
	await process_frame
	print("SCALE mode=",root.content_scale_mode," factor=",root.content_scale_factor," base=",root.content_scale_size)
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	prefix="res://evidence/%s/small-%dx%d"%[args[2] if args.size()>2 else "growth",root.size.x,root.size.y]
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
	# Explicit state fixtures below isolate OS modal routing, not a played run.
	print("GROWTH_MODAL_FIXTURE: reward state from actions/rewards_taken; not natural 3/6 clears")
	open_reward_fixture(false)
	await signal_click("reward_first",scene.UI.reward_rect(0,3).get_center(),"click","reward-3")
	await wait_ack("reward_first")
	check(scene.session.phase=="ready" and scene.session.relics.size()==1,"OS first reward card selects one relic")
	check(scene.session.actions==3,"reward selection does not consume action")
	await signal_click("owned_open",scene.UI.owned_rect(0).get_center(),"click","owned-strip")
	await wait_ack("owned_open")
	check(scene.detail_relic=="pigment","OS owned icon opens correct detail")
	await signal_click("owned_inside",Vector2(400,470),"click","owned-details")
	await wait_ack("owned_inside")
	check(scene.detail_relic=="pigment" and scene.session.actions==3,"OS detail interior cannot clear board")
	await signal_click("owned_close",scene.UI.DETAIL_CLOSE.get_center())
	await wait_ack("owned_close")
	check(scene.detail_relic=="" and scene.session.actions==3,"OS close does not pass through")
	await signal_click("owned_stale_up",Vector2(200,600),"up")
	await wait_ack("owned_stale_up")
	check(scene.session.actions==3,"stale OS detail release ignored")
	await signal_click("reward_skill",scene.SKILL.get_center())
	await wait_ack("reward_skill")
	check(scene.session.skill_mode,"OS skill input works after reward")
	chosen={}
	for p in scene.session.panels:
		if p.kind=="normal":chosen=p;break
	await signal_click("reward_skill_panel",scene.board_to_screen(chosen.pos))
	await wait_ack("reward_skill_panel")
	check(scene.session.charge==0 and not scene.session.skill_mode,"OS skill executes after reward")
	check(scene.session.actions==3,"post-reward skill does not consume clear")

	open_reward_fixture(false)
	await signal_click("modal_reset",scene.RESET.get_center(),"click","reward-reset")
	await wait_ack("modal_reset")
	check(scene.session.phase=="ready" and scene.session.actions==0 and scene.session.relics.is_empty(),"OS reset works while reward modal is open")

	open_reward_fixture(false)
	var card:Vector2=scene.UI.reward_rect(0,3).get_center()
	await signal_click("stale_down",card,"down")
	await wait_ack("stale_down")
	check(scene.modal_pointer==-1,"OS card down captures modal pointer")
	# Reset while OS button remains held, then offer a new fixture. The later
	# OS release must not choose a card in the newly displayed offer.
	open_reward_fixture(false)
	await signal_click("stale_up",card,"up")
	await wait_ack("stale_up")
	check(scene.session.phase=="reward" and scene.session.relics.is_empty(),"stale OS release after reset cannot select new offer")
	check(scene.session.actions==3 and scene.modal_pointer==-99,"stale release leaves fixture count and pointer clean")

	open_reward_fixture(true)
	await signal_click("reward_second",scene.UI.reward_rect(1,2).get_center(),"click","reward-2")
	await wait_ack("reward_second")
	check(scene.session.phase=="ready" and scene.session.relics.size()==2 and scene.session.rewards_taken==2,"OS second reward card selects from two remaining relics")
	check(scene.session.actions==6,"second reward keeps action count")
	await signal_click("growth_final_reset",scene.RESET.get_center())
	await wait_ack("growth_final_reset")
	check(scene.session.actions==0 and scene.session.relics.is_empty(),"OS final reset clears growth")
	# Real initial board and actual OS clear: counter is not a modal fixture.
	var small:Dictionary={}
	for panel in scene.session.panels:
		var plan:Dictionary=scene.session.plan_for(panel.id)
		if plan.valid and plan.removed.size()==2 and plan.activated.is_empty():small=panel;break
	check(not small.is_empty(),"normal small clear exists")
	if not small.is_empty():
		await signal_click("small_clear",scene.board_to_screen(small.pos))
		await wait_ack("small_clear")
		deadline=Time.get_ticks_msec()+12000
		while not scene.feedback.finished and Time.get_ticks_msec()<deadline:await process_frame
		check(scene.feedback.count==2 and scene.feedback.core_count==0,"actual OS small clear counts two panels")
		await signal_click("counter_read",Vector2.ZERO,"capture","counter")
		await wait_ack("counter_read")
		while scene.session.phase=="busy" and Time.get_ticks_msec()<deadline:await process_frame
		check(scene.session.phase=="ready","effects do not block actual OS clear readiness")
	await signal_click("done",Vector2.ZERO)
	print("SMALL_WINDOW failures=",failures," window=",root.size," content=",root.get_texture().get_size())
	await create_timer(0.3).timeout
	quit(1 if failures else 0)

func wait_ack(stage:String)->void:
	var deadline:=Time.get_ticks_msec()+12000
	var received:=false
	while Time.get_ticks_msec()<deadline:
		if FileAccess.file_exists("/tmp/chroma-small-ack.json"):
			var data=JSON.parse_string(FileAccess.get_file_as_string("/tmp/chroma-small-ack.json"))
			if data is Dictionary and data.get("stage","")==stage:
				received=true
				break
		await process_frame
	check(received,"OS driver acknowledged "+stage)
	# XTest delivery precedes ack but event processing may be next frame.
	await process_frame
	await process_frame

func open_reward_fixture(second:bool)->void:
	scene.reset_board()
	scene.session.actions=6 if second else 3
	if second:
		scene.session.relics=["pigment"]
		scene.session.rewards_taken=1
	scene.session.phase="busy"
	scene.session.finish_refill()
	check(scene.session.phase=="reward","reward fixture opened")
	scene.queue_redraw()

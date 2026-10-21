extends SceneTree
## Rendered showcase. The long-chain board is an explicit effect fixture;
## normal nine-clear growth acquisition remains covered by play_growth.gd.
var scene
var failures:=0
var events:Array=[]
var movie:=false
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func shot(name:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/presentation/%s.png"%name)
func click(point:Vector2,hold:float=0.12)->void:
	scene.press(point,-1)
	await create_timer(hold).timeout
	scene.release(point,-1)
func clear_panel(panel:Dictionary,label:String)->void:
	var point:Vector2=scene.board_to_screen(panel.pos)
	scene.press(point,-1)
	var preview:Dictionary=scene.session.selection.duplicate(true)
	check(preview.get("valid",false),label+" has legal preview")
	await create_timer(0.7).timeout
	scene.release(point,-1)
	check(scene.active_plan==preview,label+" executes preview unchanged")
	var count_trace:Array=[]
	var previous:=-1
	var effect_shot:=false
	var limit:=Time.get_ticks_msec()+20000
	while scene.session.phase=="busy" and Time.get_ticks_msec()<limit:
		if scene.feedback.count!=previous:
			count_trace.append({"frame":Engine.get_process_frames(),"panels":scene.feedback.count,"cores":scene.feedback.core_count})
			check(scene.feedback.count>=previous and scene.feedback.count<=preview.removed.size(),"running count monotonic and bounded")
			previous=scene.feedback.count
		if not effect_shot and scene.action_clock>0.17:
			effect_shot=true
			await shot(label+"-effects")
		await process_frame
	check(scene.session.phase not in ["busy","stalled"],label+" naturally finishes")
	check(scene.feedback.count==preview.removed.size(),label+" actual panel total accurate")
	check(scene.feedback.core_count==preview.activated.size(),label+" actual core activations accurate")
	events.append({"label":label,"panels":preview.removed.size(),"cores":preview.activated.size(),"ready_while_feedback_visible":scene.feedback.visible,"ready_while_particles_alive":not scene.feedback.particles.is_empty(),"count_trace":count_trace,"at":scene.time})
	await shot(label+"-ready")
	await create_timer(0.9).timeout
func small_panel()->Dictionary:
	var best:Dictionary={}
	var size:=999
	for p in scene.session.panels:
		var plan:Dictionary=scene.session.plan_for(p.id)
		if plan.valid and plan.activated.is_empty() and plan.removed.size()<size:
			best=p;size=plan.removed.size()
	return best
func run()->void:
	movie="--capture" in OS.get_cmdline_user_args()
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.45).timeout
	await clear_panel(small_panel(),"small")
	# Same fixture procedure as timing probe; this board follows one small clear.
	for p in scene.session.panels:
		if p.kind!="heart":p.color=0
	var normals:Array=scene.session.panels.filter(func(p):return p.kind!="heart")
	normals[0].kind="strong"
	var graph:Dictionary=scene.Rules.contact_graph(scene.session.panels)
	for p in normals:
		if p.id in graph[normals[0].id]:p.kind="core";break
	scene.visual=scene.session.panels.duplicate(true)
	await process_frame
	await clear_panel(normals[0],"core-chain-fixture")
	await clear_panel(small_panel(),"third-clear")
	check(scene.session.phase=="reward","third resolved action opens reward")
	await shot("reward-icons")
	await create_timer(2.7).timeout
	await click(scene.UI.reward_rect(0,3).get_center())
	check(scene.session.relics==["pigment"],"reward chosen with normal fresh gesture")
	await shot("owned-strip")
	await create_timer(1.1).timeout
	await click(scene.UI.owned_rect(0).get_center())
	check(scene.detail_relic=="pigment","owned icon opens detail")
	await shot("owned-details")
	await create_timer(3.0).timeout
	await click(scene.UI.DETAIL_CLOSE.get_center())
	check(scene.detail_relic=="" and scene.session.actions==3,"detail close does not clear panel")
	await shot("final-board")
	await create_timer(1.6).timeout
	var file:=FileAccess.open("res://evidence/presentation/showcase%s.json"%("-movie" if movie else ""),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"movie":movie,"long_clear_is_fixture":true,"events":events,"timings":scene.timings,"final_hold_seconds":1.6},"  "))
	print("SHOWCASE failures=",failures)
	# Quit directly with scene intact; queue_free would record an empty gray frame.
	quit(1 if failures else 0)

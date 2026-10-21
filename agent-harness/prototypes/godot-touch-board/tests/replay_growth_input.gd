extends SceneTree
## Literal screen coordinates captured with the prior inlet condition. No fixtures
## enter the live scene; all board/skill/reward operations use normal UI gestures.
var failures:=0
var semantic:=false
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	semantic="--ids" in OS.get_cmdline_user_args()
	var recorded=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/growth/play-pair0-before-inlet.json"))
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	await create_timer(0.3).timeout
	var results:Array=[]
	for item in recorded.inputs:
		check(scene.session.phase==item.phase_before,"same phase before recorded input")
		check(scene.session.actions==item.actions_before,"same clear count before recorded input")
		var point:=Vector2(item.point[0],item.point[1])
		if semantic and item.get("start_id",-1)>=0:
			var found:=false
			for p in scene.session.panels:
				if p.id==item.start_id:
					point=scene.board_to_screen(p.pos)
					found=true
			check(found,"original selected panel ID still present")
		scene.press(point,-1)
		var preview:Dictionary=scene.session.selection.duplicate(true)
		if item.valid:check(preview.get("valid",false),"original coordinate remains legal")
		await create_timer(item.hold).timeout
		scene.release(point,-1)
		check(scene.session.actions==item.actions_after,"recorded gesture increments once")
		var limit:=Time.get_ticks_msec()+20000
		while scene.session.phase=="busy" and Time.get_ticks_msec()<limit:await process_frame
		results.append({"original_point":item.point,"point":[point.x,point.y],"id":item.get("start_id",-1),"phase":scene.session.phase,"actions":scene.session.actions,"direct_ids":preview.get("direct",[]),"targets":preview.get("targets",[])})
		check(scene.session.phase not in ["busy","stalled"],"recorded gesture refill completes")
		if failures:break
	check(scene.session.actions==7 and scene.session.phase=="ready","same literal input sequence passes former seventh-clear stall")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/growth/input-replay%s-after.png"%("-ids" if semantic else ""))
	var file:=FileAccess.open("res://evidence/growth/input-replay%s.json"%("-ids" if semantic else ""),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"method":"same initial seed; original selected IDs at their current positions" if semantic else "same initial seed and literal recorded screen coordinates/hold times; no fixture/forced charge/reset", "results":results,"timings":scene.timings},"  "))
	print("INPUT_REPLAY failures=",failures," actions=",scene.session.actions," phase=",scene.session.phase)
	scene.queue_free();await process_frame;await create_timer(0.3).timeout
	quit(1 if failures else 0)

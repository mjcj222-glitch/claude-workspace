extends SceneTree
const PAIRS = [["pigment","lens"],["pigment","ash"],["lens","ash"]]
var failures:=0
var events:Array=[]
var scene
var pair_index:=0
var evidence_dir:="growth"
var movie:=false
var greedy_stress:=false
var before_inlet:=false
var input_records:Array=[]
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func gesture(point:Vector2,hold:float=0.08)->Dictionary:
	var actions_before:int=scene.session.actions
	var phase_before:String=scene.session.phase
	scene.press(point,-1)
	var preview:Dictionary=scene.session.selection.duplicate(true)
	await create_timer(hold).timeout
	scene.release(point,-1)
	var input_id:int=-1
	if preview.get("valid",false): input_id=preview.direct[0] if preview.mode=="clear" else preview.targets[0]
	input_records.append({"start_id":input_id,"point":[point.x,point.y],"hold":hold,"phase_before":phase_before,"actions_before":actions_before,"actions_after":scene.session.actions,"mode":preview.get("mode",""),"valid":preview.get("valid",false)})
	return preview
func snapshot(name:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s/%s-pair%d.png"%[evidence_dir,name,pair_index])
func desired_size()->int:
	if "ash" in scene.session.relics and not scene.session.ash_reserved:return 6
	return 5 if "lens" in scene.session.relics else 6
func use_skill()->void:
	var best:Dictionary={}
	var score:=-1
	for p in scene.session.panels:
		if p.kind!="normal":continue
		for color in range(4):
			var plan:Dictionary=scene.session.skill_plan_for(p.id,color)
			var changed:=0
			for id in plan.targets:
				for candidate in scene.session.panels:
					if candidate.id==id and candidate.color!=color:changed+=1
			var value:int=plan.connected.size()*100+changed if greedy_stress else 1000-absi(plan.connected.size()-desired_size())*100+changed
			if value>score:
				score=value;best={"point":scene.board_to_screen(p.pos),"color":color,"plan":plan}
	if best.is_empty():return
	await gesture(scene.SKILL.get_center())
	await gesture(scene.UI.color_rect(best.color).get_center())
	var preview:Dictionary=await gesture(best.point,0.3 if movie else 0.08)
	check(preview.get("targets",[])==best.plan.targets,"normal skill preview matches chosen plan")
	events.append({"type":"skill","action_before":scene.session.actions,"owned":scene.session.relics.duplicate(),"start_id":preview.get("targets",[-1])[0],"color":best.color,"target_ids":preview.get("targets",[]),"targets":preview.get("targets",[]).size(),"consumed_ash":preview.get("consume_ash",false),"recharge_required":scene.session.charge_required})
func motion_snapshot()->Dictionary:
	var state:Dictionary=scene.motion_state
	var bodies:Array=[]
	for p in state.get("panels",[]):
		bodies.append({"id":p.id,"pos":[p.pos.x,p.pos.y],"vel":[p.vel.x,p.vel.y],"anchored":p.anchored,"kind":p.kind,"color":p.color})
	return {"elapsed":state.get("elapsed",0),"pending":state.get("pending",[]).size(),"profile":state.get("profile",{}),"bodies":bodies}
func run()->void:
	var args:=OS.get_cmdline_user_args()
	evidence_dir="presentation" if "--presentation" in args else "growth"
	for a in args:
		if a.begins_with("--pair="):pair_index=int(a.substr(7))
	movie="--capture" in args
	greedy_stress="--greedy-stress" in args
	before_inlet="--before-inlet" in args
	if before_inlet:
		# Reconstruct only the prior inlet condition in memory to record the
		# original failing mouse coordinates; release scripts stay unchanged.
		var old_motion:=GDScript.new()
		old_motion.source_code=FileAccess.get_file_as_string("res://scripts/board_motion.gd").replace("if free and clearance >= bounds.position.y+RADIUS and clearance>best_clearance:","if free and clearance>best_clearance:")
		check(old_motion.reload()==OK,"baseline motion compiles")
		var controller:=GDScript.new()
		controller.source_code=FileAccess.get_file_as_string("res://scripts/main.gd").replace("const Motion = preload", "var Motion = preload")
		check(controller.reload()==OK,"baseline controller compiles")
		scene=Node2D.new()
		scene.set_script(controller)
		scene.Motion=old_motion
	else:
		scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.3).timeout
	for action in range(1,10):
		check(scene.session.phase=="ready","normal gameplay ready before action")
		if scene.session.phase!="ready":break
		if scene.session.charge>=scene.session.charge_required:await use_skill()
		var best:Dictionary={}
		var score:=-1
		for p in scene.session.panels:
			var plan:Dictionary=scene.session.plan_for(p.id)
			if not plan.valid:continue
			var value:int=plan.direct_normals*100+plan.removed.size() if greedy_stress else 1000-absi(plan.direct_normals-desired_size())*100+plan.removed.size()
			if value>score:
				score=value;best={"point":scene.board_to_screen(p.pos),"plan":plan}
		check(not best.is_empty(),"normal board has legal clear")
		if best.is_empty():break
		var owned:Array=scene.session.relics.duplicate()
		var start_id:int=best.plan.direct[0]
		var motion_start:Dictionary={}
		var preview:Dictionary=await gesture(best.point,0.4 if movie else 0.08)
		check(scene.active_plan==preview,"normal clear executes exact visible plan")
		var limit:=Time.get_ticks_msec()+15000
		while scene.session.phase=="busy" and Time.get_ticks_msec()<limit:
			if scene.falling and motion_start.is_empty():motion_start=scene.motion_state.duplicate(true)
			await process_frame
		check(scene.session.phase!="busy" and scene.session.phase!="stalled","natural refill completes")
		if scene.session.phase in ["busy","stalled"]:
			var diagnostic:=FileAccess.open("res://evidence/%s/stall-pair%d.json"%[evidence_dir,pair_index],FileAccess.WRITE)
			diagnostic.store_string(JSON.stringify(motion_snapshot(),"  "))
			var fixture:=FileAccess.open("res://evidence/%s/stall-start-pair%d.dat"%[evidence_dir,pair_index],FileAccess.WRITE)
			fixture.store_var(motion_start)
			events.append({"type":"stalled_clear","action":action,"start_id":start_id,"removed_ids":preview.removed,"direct_ids":preview.direct,"owned":owned})
			await snapshot("stall")
			break
		check(scene.session.actions==action,"one normal clear counted once")
		events.append({"type":"clear","start_id":start_id,"removed_ids":preview.removed,"direct_ids":preview.direct,"action":action,"owned":owned,"removed":preview.removed.size(),"direct_normals":preview.direct_normals,"core":preview.spawn.get("kind",""),"ash_trigger":preview.ash_reserve,"reserved_now":scene.session.ash_reserved,"charge":scene.session.charge,"charge_required":scene.session.charge_required,"phase":scene.session.phase})
		if action in [3,6]:
			check(scene.session.phase=="reward","reward earned through completed normal actions")
			await snapshot("reward%d"%scene.session.reward_round)
			await create_timer(1.0 if movie else 0.1).timeout
			var id:String=PAIRS[pair_index][0 if action==3 else 1]
			var index:int=scene.session.reward_options.find(id)
			check(index>=0,"unowned intended relic offered")
			if index<0:break
			await gesture(scene.UI.reward_rect(index,scene.session.reward_options.size()).get_center(),0.15)
			check(scene.session.phase=="ready" and id in scene.session.relics,"new gesture acquires relic")
			events.append({"type":"reward","action":action,"id":id})
	check(scene.session.actions==9 and scene.session.phase=="summary","nine normal clears reach summary")
	if scene.session.phase=="summary":
		await snapshot("summary")
		await create_timer(1.2 if movie else 0.1).timeout
		await gesture(scene.UI.SUMMARY_CONTINUE.get_center())
		check(scene.session.phase=="ready","summary can continue without extra reward")
		if scene.session.ash_reserved and scene.session.charge>=scene.session.charge_required:
			await use_skill()
			check(not scene.session.ash_reserved and scene.session.charge_required==2 and scene.session.actions==9,"naturally earned ash consumed by next skill after summary")
			await snapshot("ash-consumed")
	var f:=FileAccess.open("res://evidence/%s/play-pair%d%s.json"%[evidence_dir,pair_index,"-before-inlet" if before_inlet else "-greedy" if greedy_stress else "-movie" if movie else ""],FileAccess.WRITE)
	f.store_string(JSON.stringify({"pair":PAIRS[pair_index],"failures":failures,"policy":"maximum connection stress" if greedy_stress else "prefer lens five / ash six direct normals", "method":"normal UI gestures; no fixture injection, forced charge, or intermediate board reset","inputs":input_records,"events":events,"stats":scene.session.stats,"timings":scene.timings},"  "))
	print("NORMAL_GROWTH pair=",pair_index," failures=",failures," actions=",scene.session.actions)
	scene.queue_free();await process_frame;await create_timer(0.3).timeout
	quit(1 if failures else 0)

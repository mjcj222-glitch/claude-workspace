extends SceneTree
const Motion=preload("res://scripts/board_motion.gd")
const BOUNDS=Rect2(30,290,660,530)
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL "+label)
func candidates(state:Dictionary)->Array:
	var result:Array=[]
	for trial in range(33):
		var x:float=BOUNDS.position.x+37+trial*(BOUNDS.size.x-74)/32.0
		var point:=Vector2(x,252)
		var free:=true
		var clearance:float=BOUNDS.end.y-37
		for p in state.panels:
			if p.pos.distance_to(point)<p.radius+38:free=false;break
			var dx:float=absf(p.pos.x-x)
			var reach:float=p.radius+37
			if dx<reach:clearance=minf(clearance,p.pos.y-sqrt(reach*reach-dx*dx))
		if free:result.append({"x":x,"first_hit_y":clearance})
	result.sort_custom(func(a,b):return a.first_hit_y>b.first_hit_y)
	return result
func _init()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=1
	# No inlet can currently hold a full body inside. A free spawn point alone
	# must not send the pending panel onto this already-high surface.
	var high:Array=[]
	for i in range(9):high.append({"id":i+1,"pos":Vector2(67+i*73,327),"radius":37.,"kind":"normal","color":0})
	var blocked:Dictionary=Motion.start(high,BOUNDS,10,10,rng)
	blocked.spawn_clock=1.0
	Motion._spawn(blocked,BOUNDS)
	check(blocked.pending.size()==1,"defer outside landing despite free spawn point")
	var f:=FileAccess.open("res://evidence/growth/stall-start-pair0.dat",FileAccess.READ)
	if f==null:check(false,"saved natural-play reproduction exists");quit(1);return
	var state:Dictionary=f.get_var()
	var trace:Array=[]
	var frames:Array=[]
	var previous:Dictionary={}
	for p in state.panels:previous[p.id]=p.pos
	var max_overlap:=0.0
	var max_swept:=0.0
	var max_step:=0.0
	var uncaused_sideways:=0
	while not state.ready and not state.stalled:
		var ids:Array=[]
		for p in state.panels:ids.append(p.id)
		var available:Array=candidates(state) if not state.pending.is_empty() else []
		var at:float=state.elapsed
		Motion.step(state,BOUNDS,Motion.STEP)
		for p in state.panels:
			if p.id not in ids:trace.append({"id":p.id,"elapsed":at,"x":p.pos.x,"y_after_tick":p.pos.y,"available_inlets":available})
		var positions:Dictionary={}
		var row:Array=[]
		for p in state.panels:
			positions[p.id]=p.pos
			row.append([p.id,p.pos.x,p.pos.y])
			if not previous.has(p.id):check(p.pos.y+p.radius<305,"repro new panel enters above top")
			else:
				max_step=maxf(max_step,previous[p.id].distance_to(p.pos))
				if absf(p.pos.x-previous[p.id].x)>0.001 and p.get("contact_count",0)==0:uncaused_sideways+=1
			for q in state.panels:
				if p.id>=q.id:continue
				max_overlap=maxf(max_overlap,p.radius+q.radius-p.pos.distance_to(q.pos))
				if previous.has(p.id) and previous.has(q.id):
					var r0:Vector2=previous[p.id]-previous[q.id]
					var dr:Vector2=(p.pos-q.pos)-r0
					var t:=clampf(-r0.dot(dr)/maxf(0.000001,dr.length_squared()),0,1)
					max_swept=maxf(max_swept,p.radius+q.radius-(r0+dr*t).length())
		frames.append(row)
		previous=positions
	check(max_overlap<0.2,"repro intermediate non-overlap")
	check(max_swept<0.6,"repro swept bodies cannot pass")
	check(max_step<20 and uncaused_sideways==0,"repro no teleport or uncaused lateral drift")
	check(state.ready,"same seventh-clear start finishes without teleport or timeout extension")
	check(state.pending.is_empty() and state.panels.size()==48,"all pending panels delivered")
	for p in state.panels:
		check(p.pos.y-p.radius>=289.8,"repro full body inside %d"%p.id)
		for q in state.panels:
			if p.id<q.id:check(p.pos.distance_to(q.pos)>=p.radius+q.radius-0.2,"repro no final overlap")
	var output:=FileAccess.open("res://evidence/growth/inlet-%s.json"%("red" if failures else "green"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures":failures,"elapsed":state.elapsed,"spawns":trace,"profile":state.profile,"max_overlap":max_overlap,"swept_overlap":max_swept,"max_step":max_step,"uncaused_sideways":uncaused_sideways,"frames":frames},"  "))
	print("REFILL_INLET failures=",failures," sim_s=",state.elapsed)
	quit(1 if failures else 0)

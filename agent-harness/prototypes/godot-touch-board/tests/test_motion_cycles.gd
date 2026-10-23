extends SceneTree
const Motion=preload("res://scripts/board_motion.gd")
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func body(id:int,pos:Vector2)->Dictionary:
	return {"id":id,"pos":pos,"radius":37.0,"color":0,"kind":"normal"}
func _init()->void:
	var bounds:=Rect2(30,290,660,530)
	var rng:=RandomNumberGenerator.new()
	rng.seed=901
	var support_y:=783.0-sqrt(74.0*74.0-37.0*37.0)
	var supported:Array=[body(1,Vector2(150,783)),body(2,Vector2(224,783)),body(3,Vector2(187,support_y))]
	var state:Dictionary=Motion.start(supported,bounds,3,4,rng)
	for i in range(100):Motion.step(state,bounds,1.0/120)
	for i in range(3):check(state.panels[i].pos.distance_to(supported[i].pos)<0.01,"unchanged two supports preserve upper body")
	state=Motion.start([supported[1],supported[2]],bounds,2,4,rng)
	for i in range(300):Motion.step(state,bounds,1.0/120)
	check(state.panels[0].pos==supported[1].pos,"remaining floor support unchanged")
	check(state.panels[1].pos.y>supported[2].pos.y+10,"lost support falls instead of hovering")
	check(state.panels[1].get("contact_count",0)>0,"rolling records actual collision")
	var initial:Dictionary=Motion.initial_board(bounds,48,1,rng)
	var panels:Array=initial.panels
	var next_id:int=initial.next_id
	var durations:Array=[]
	for cycle in range(10):
		var survivors:Array=[]
		for p in panels:
			if (p.id+cycle)%5!=0:survivors.append(p)
		state=Motion.start(survivors,bounds,48,next_id,rng)
		for frame in range(500):
			Motion.step(state,bounds,1.0/120)
			if state.ready or state.stalled:break
		if state.stalled:
			var detail:Array=[]
			for body_data in state.panels:detail.append({"id":body_data.id,"pos":[body_data.pos.x,body_data.pos.y],"vel":[body_data.vel.x,body_data.vel.y],"anchored":body_data.anchored})
			var f:=FileAccess.open("res://evidence/motion-fix/stall-%d.json"%cycle,FileAccess.WRITE)
			f.store_string(JSON.stringify({"pending":state.pending.size(),"bodies":detail},"  "))
		check(state.ready,"cycle %d bounded ready"%cycle)
		check(state.panels.size()==48,"cycle count")
		for p in state.panels:
			check(p.pos.y-p.radius>=bounds.position.y-0.2,"final top containment")
			for q in state.panels:
				if p.id<q.id:check(p.pos.distance_to(q.pos)>=p.radius+q.radius-0.2,"cycle %d overlap ids %d/%d depth %.4f anchored %s/%s"%[cycle,p.id,q.id,p.radius+q.radius-p.pos.distance_to(q.pos),p.anchored,q.anchored])
		panels=state.panels
		next_id=state.next_id
		durations.append(state.elapsed)
	print("CYCLES failures=",failures," durations=",durations)
	quit(1 if failures else 0)

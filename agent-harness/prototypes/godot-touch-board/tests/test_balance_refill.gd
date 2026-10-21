extends SceneTree
## Exact archived action20 refill: preserve survivors, int64 RNG and all velocities.
const Motion=preload("res://scripts/board_motion.gd")
const BOUNDS=Rect2(30,290,660,530)
const SAVED="res://evidence/balance/stall-reproduction/state.var"
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL "+label)
func check_surface_admission()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=23
	var surfaces:Array=[]
	for i in range(8):surfaces.append({"id":i+1,"pos":Vector2(67+i*80,450),"radius":37.0,"color":0,"kind":"normal"})
	var state:Dictionary=Motion.start(surfaces,BOUNDS,9,9,rng)
	for p in state.panels:p.vel=Vector2(0,-20)
	state.spawn_clock=1.0
	Motion._spawn(state,BOUNDS)
	check(state.pending.size()==1 and state.panels.size()==8,"a rising first-hit surface is not a usable inlet")
	for velocity in [0.0,20.0]:
		state=Motion.start(surfaces,BOUNDS,9,9,rng)
		for p in state.panels:p.vel=Vector2(0,velocity)
		state.spawn_clock=1.0
		Motion._spawn(state,BOUNDS)
		check(state.pending.is_empty() and state.panels.size()==9,"stationary or descending inlet stays usable: %s"%velocity)
func _init()->void:
	check_surface_admission()
	var f:=FileAccess.open(SAVED,FileAccess.READ)
	var saved:Dictionary=f.get_var(false)
	var original:Dictionary=saved.motion
	check(original.stalled and not original.ready and original.pending.is_empty(),"original archive records unresolved refill, not defeat")
	var rng:=RandomNumberGenerator.new()
	rng.state=saved.rng_state_before_motion
	var state:Dictionary=Motion.start(saved.survivors_before_refill,BOUNDS,48,saved.session_next_id,rng)
	check(rng.state==saved.rng_state,"exact saved refill RNG restored")
	var snapshots:Array=[]
	var spawn_rows:Array=[]
	var previous:Dictionary={}
	var max_overlap:=0.0
	var max_swept:=0.0
	var max_step:=0.0
	var uncaused_sideways:=0
	for p in state.panels:previous[p.id]=p.pos
	while not state.ready and not state.stalled:
		var old:Dictionary={}
		for p in state.panels:old[p.id]=p.duplicate(true)
		Motion.step(state,BOUNDS,Motion.STEP)
		var row:Array=[]
		var next:Dictionary={}
		for p in state.panels:
			row.append([p.id,p.pos.x,p.pos.y,p.vel.x,p.vel.y,p.anchored])
			next[p.id]=p.pos
			if not previous.has(p.id):
				spawn_rows.append({"id":p.id,"time":state.elapsed,"x":p.pos.x,"y":p.pos.y})
				check(p.pos.y+p.radius<BOUNDS.position.y,"new body arrives above top")
			else:
				max_step=maxf(max_step,p.pos.distance_to(previous[p.id]))
				# Existing collision momentum may continue in free flight. Only
				# unexplained displacement, not inertia or wall/anchor contact, fails.
				var inertial_x:float=previous[p.id].x+old[p.id].vel.x*Motion.STEP
				var wall_contact:bool=p.pos.x-p.radius<=BOUNDS.position.x+0.01 or p.pos.x+p.radius>=BOUNDS.end.x-0.01
				if absf(p.pos.x-inertial_x)>0.001 and not p.anchored and not wall_contact and p.get("contact_count",0)==old[p.id].get("contact_count",0):uncaused_sideways+=1
			for q in state.panels:
				if p.id>=q.id:continue
				max_overlap=maxf(max_overlap,p.radius+q.radius-p.pos.distance_to(q.pos))
				if previous.has(p.id) and previous.has(q.id):
					var r0:Vector2=previous[p.id]-previous[q.id]
					var dr:Vector2=(p.pos-q.pos)-r0
					var t:=clampf(-r0.dot(dr)/maxf(dr.length_squared(),0.000001),0,1)
					max_swept=maxf(max_swept,p.radius+q.radius-(r0+dr*t).length())
		snapshots.append(row);previous=next
	var outside:Array=[]
	var moving:Array=[]
	for p in state.panels:
		if p.pos.y-p.radius<BOUNDS.position.y-0.1:outside.append(p)
		if p.vel.length()>1:moving.append(p)
	check(state.ready and not state.stalled,"exact seed23 clear20 refill resolves before unchanged4s limit")
	check(state.pending.is_empty() and state.panels.size()==48,"all48 bodies delivered")
	check(outside.is_empty(),"all bodies fully inside before readiness")
	var supported:Dictionary={}
	for p in state.panels:
		if absf(p.pos.y+p.radius-BOUNDS.end.y)<0.2:supported[p.id]=true
	for iteration in range(state.panels.size()):
		for p in state.panels:
			for q in state.panels:
				if supported.has(q.id) and q.pos.y>p.pos.y+0.1 and p.pos.distance_to(q.pos)<=p.radius+q.radius+0.2:supported[p.id]=true
	check(supported.size()==state.panels.size(),"READY bodies have continuous downward contact paths to floor")
	check(max_overlap<0.2 and max_swept<0.6,"intermediate and swept non-overlap")
	check(max_step<20 and uncaused_sideways==0,"no teleport or airborne uncaused sideways movement")
	var variant:="red" if failures else "green"
	var out:=FileAccess.open("res://evidence/refill-stall/exact-"+variant+".var",FileAccess.WRITE)
	out.store_var({"state":state,"frames":snapshots,"spawns":spawn_rows});out.close()
	out=FileAccess.open("res://evidence/refill-stall/exact-"+variant+".json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"failures":failures,"elapsed":state.elapsed,"ready":state.ready,"stalled":state.stalled,"pending":state.pending.size(),"outside":outside,"moving":moving,"spawns":spawn_rows,"max_overlap":max_overlap,"max_swept":max_swept,"max_step":max_step,"uncaused_sideways":uncaused_sideways,"profile":state.profile},"  "))
	print("EXACT_REFILL ",variant," failures=",failures," elapsed=",state.elapsed," outside=",outside.size()," moving=",moving.size())
	quit(1 if failures else 0)

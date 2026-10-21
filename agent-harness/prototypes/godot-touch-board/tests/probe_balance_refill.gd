extends SceneTree
const Motion=preload("res://scripts/board_motion.gd")
const BOUNDS=Rect2(30,290,660,530)
func _init()->void:
	var f:=FileAccess.open("res://evidence/balance/stall-reproduction/state.var",FileAccess.READ)
	var saved:Dictionary=f.get_var(false)
	var rng:=RandomNumberGenerator.new();rng.state=saved.rng_state_before_motion
	var state:Dictionary=Motion.start(saved.survivors_before_refill,BOUNDS,48,saved.session_next_id,rng)
	var rows:Array=[]
	var graph:Array=[]
	while not state.ready and not state.stalled:
		if state.pending.size()>0 and state.pending[0].id==255 and state.spawn_clock+Motion.STEP>=0.035:
			var inlet:Array=[]
			for trial in range(33):
				var x:float=67+trial*586.0/32
				var first:float=783
				var hit:Dictionary={}
				for p in state.panels:
					var dx:float=absf(p.pos.x-x)
					if dx<74:
						var y:float=p.pos.y-sqrt(74*74-dx*dx)
						if y<first:first=y;hit=p.duplicate(true)
				inlet.append({"x":x,"first":first,"hit":hit})
			graph.append({"time":state.elapsed,"inlet":inlet})
		Motion.step(state,BOUNDS,Motion.STEP)
		if state.profile.ticks%12==0:
			var top:Array=[]
			var max_speed:=0.0
			for p in state.panels:
				max_speed=maxf(max_speed,p.vel.length())
				if p.pos.y<420:top.append(p.duplicate(true))
			rows.append({"time":state.elapsed,"top":top,"max_speed":max_speed,"quiet":state.quiet})
	var panel_support:Array=[]
	for p in state.panels:
		var supports:Array=[]
		for q in state.panels:
			if p.id!=q.id and p.pos.distance_to(q.pos)<p.radius+q.radius+0.2:
				supports.append({"id":q.id,"dx":q.pos.x-p.pos.x,"dy":q.pos.y-p.pos.y,"distance":p.pos.distance_to(q.pos),"anchored":q.anchored})
		panel_support.append({"panel":p,"contacts":supports})
	var canonical:bool=state.panels==saved.motion.panels
	var label:="current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.substr(8)
	assert(label in ["before","current"])
	var out:=FileAccess.open("res://evidence/refill-stall/probe-"+label+".json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"canonical_final_panels_match_archive":canonical,"rows":rows,"inlet255":graph,"support_graph":panel_support},"  "))
	print("PROBE saved panels equal=",canonical)
	quit()

extends SceneTree
const Motion = preload("res://scripts/board_motion.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func _init() -> void:
	var bounds := Rect2(30,290,660,530)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var packed: Dictionary = Motion.initial_board(bounds,48,1,rng)
	var initial: Array = packed.panels
	var cases := {"two":[23,24],"center":[],"left_column":[]}
	for p in initial:
		if p.pos.distance_to(Vector2(360,620)) < 110: cases.center.append(p.id)
		if p.pos.x < 150: cases.left_column.append(p.id)
	var traces := {}
	for name in cases:
		var removed: Array = cases[name]
		var survivors: Array = initial.filter(func(p):return p.id not in removed)
		var state: Dictionary = Motion.start(survivors,bounds,48,49,rng)
		var original := {}
		for p in survivors: original[p.id]=p.pos
		for p in state.panels: check(p.pos == original[p.id],name+" preserves start position")
		var frames: Array = []
		var previous: Dictionary = original.duplicate()
		var max_overlap := 0.0
		var max_step := 0.0
		var max_swept_overlap := 0.0
		var uncaused_sideways := 0
		var stable_floor_drift := 0.0
		for frame in range(600):
			Motion.step(state,bounds,1.0/120.0)
			var positions := {}
			for p in state.panels:
				positions[p.id]=p.pos
				if not previous.has(p.id):
					check(p.pos.y+p.radius <= bounds.position.y+15,name+" new body enters above top only")
				else:
					max_step=maxf(max_step,previous[p.id].distance_to(p.pos))
					if absf(p.pos.x-previous[p.id].x)>0.001 and p.get("contact_count",0)==0:uncaused_sideways+=1
				if original.has(p.id) and absf(original[p.id].y+p.radius-bounds.end.y)<0.1:
					stable_floor_drift=maxf(stable_floor_drift,p.pos.distance_to(original[p.id]))
				for q in state.panels:
					if p.id<q.id:
						max_overlap=maxf(max_overlap,p.radius+q.radius-p.pos.distance_to(q.pos))
						if previous.has(p.id) and previous.has(q.id):
							var r0: Vector2=previous[p.id]-previous[q.id]
							var dr: Vector2=(p.pos-q.pos)-r0
							var t := clampf(-r0.dot(dr)/maxf(0.000001,dr.length_squared()),0,1)
							max_swept_overlap=maxf(max_swept_overlap,p.radius+q.radius-(r0+dr*t).length())
			var row: Array=[]
			for p in state.panels: row.append([p.id,p.pos.x,p.pos.y])
			frames.append(row)
			previous=positions
			if state.ready:break
		check(state.ready,name+" bounded refill reaches input-ready")
		check(state.panels.size()==48,name+" exact refill count")
		check(stable_floor_drift<0.1,name+" floor supported survivors stay fixed")
		check(max_swept_overlap<0.6,name+" swept bodies cannot pass between samples")
		check(uncaused_sideways==0,name+" sideways movement requires recorded collision")
		check(max_overlap<0.2,name+" intermediate bodies do not overlap")
		check(max_step<20,name+" no intermediate teleport/tunneling-sized step")
		traces[name]={"removed":removed,"ready":state.ready,"seconds":state.elapsed,"max_overlap":max_overlap,"max_step":max_step,"swept_overlap":max_swept_overlap,"uncaused_sideways":uncaused_sideways,"floor_drift":stable_floor_drift,"frames":frames}
	var f := FileAccess.open("res://evidence/motion-fix/path-traces.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(traces))
	print("PATH failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
## Real seeded Board reuse regression; optional graphical timing evidence.
const Board = preload("res://scripts/v2/board.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
const Observer = preload("res://tests/v2/physics_timing_observer.gd")
var output := ""
var board: Node
var view: Node
var trace: Node
var failures := 0
var graphical := false
var timed_out := false
func _initialize() -> void: call_deferred("run")
func wait_board() -> void:
    for tick in range(1800):
        if not board.settling: return
        await physics_frame
    failures+=1
func capture(name: String) -> void:
    if not graphical or output.is_empty(): return
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png(output.path_join(name+".png"))
    if error != OK: failures+=1
func final_metrics() -> Dictionary:
    var snap: Dictionary=board.capture()
    var polys: Array=[]
    var area:=0.0
    var top:=600.0
    var overlap:=0.0
    for p in snap.pieces:
        var poly:=Geometry.transformed(Geometry.polygon(p.hull_id,p.size),Vector2(p.x,p.y),p.angle)
        area+=Geometry.area(poly)
        for point in poly:top=minf(top,point.y)
        for prior in polys:
            for intersection in Geometry2D.intersect_polygons(poly,prior):overlap=maxf(overlap,Geometry.area(intersection))
        polys.append(poly)
    return {"count":snap.pieces.size(),"support":board.supported(snap),"max_overlap":overlap,"area_ratio":area/360000,"top_empty":top}
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.has("--output"):output=args[args.find("--output")+1]
    graphical=args.has("--graphical")
    var tail_ticks := 60
    if args.has("--tail-ticks"):tail_ticks=int(args[args.find("--tail-ticks")+1])
    var observe := not args.has("--observer-off")
    if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(720,1280)
    board=Board.new()
    if graphical:
        view=load("res://scenes/v2/battle_view.tscn").instantiate()
        root.add_child(view)
        view.bind_board(board)
    else:root.add_child(board)
    board.settle_failed.connect(func(_why):timed_out=true)
    trace=Observer.new()
    trace.board=board
    trace.process_physics_priority=100
    root.add_child(trace)
    var cases: Array=[]
    for seed_value in [41,73,991,20261020]:
        timed_out=false
        board.new_board(seed_value)
        await wait_board()
        if timed_out:
            failures+=1
            print(JSON.stringify({"seed":seed_value,"phase":"initial","timed_out":true}))
            continue
        await capture("seed-%d-initial"%seed_value)
        var before: Dictionary=board.capture()
        var plan := {}
        for p in before.pieces:
            var candidate:=Selection.preview(before,int(p.id),1)
            if not candidate.is_empty() and candidate.removed_ids.size()>=3 and candidate.removed_ids.size()<=8 and (plan.is_empty() or candidate.direct_ids.size()>plan.direct_ids.size()):plan=candidate
        if plan.is_empty():
            failures+=1
            print(JSON.stringify({"seed":seed_value,"no_legal_3_to_8":true}))
            continue
        if graphical:
            view.show_selection(before,plan)
            await capture("seed-%d-preview"%seed_value)
            view.show_selection(before,{})
        var batch: Array=board.make_refill(plan.removed_ids.size())
        trace.frames=[]
        trace.active=observe
        var t0_usec:=Time.get_ticks_usec()
        board.apply_clear(plan.removed_ids,batch)
        await wait_board()
        var wall_seconds:=(Time.get_ticks_usec()-t0_usec)/1000000.0
        # Observe frozen selection time before reusing this same Board.
        for tick in range(tail_ticks):await physics_frame
        trace.active=false
        var metrics:=final_metrics()
        if timed_out or not metrics.support or metrics.max_overlap>=32 or metrics.count!=42:failures+=1
        if metrics.area_ratio<0.60 or metrics.area_ratio>0.71 or metrics.top_empty<0 or metrics.top_empty>96:failures+=1
        var item:={"seed":seed_value,"graphical":graphical,"plan":plan,"refill_count":batch.size(),"settle_seconds":board.last_settle_seconds,"elapsed_seconds":board.elapsed,"wall_seconds_until_wait_return":wall_seconds,"timed_out":timed_out,"metrics":metrics,"before":before,"after":board.capture(),"batch":batch,"tail_ticks":tail_ticks,"observe":observe,"frames":trace.frames}
        if not output.is_empty():
            var file:=FileAccess.open(output.path_join("seed-%d-trace.json"%seed_value),FileAccess.WRITE)
            file.store_string(JSON.stringify(item))
        cases.append({"seed":seed_value,"removed_ids":plan.removed_ids,"group_size":plan.removed_ids.size(),"settle_seconds":board.last_settle_seconds,"wall_seconds":wall_seconds,"timed_out":timed_out,"metrics":metrics,"trace_frames":trace.frames.size()})
        await capture("seed-%d-refill-settled"%seed_value)
        print(JSON.stringify(cases[-1]))
    print(JSON.stringify({"suite":"normal legal removal provisional physical timing","graphical":graphical,"failures":failures,"physics_ticks_per_second":Engine.physics_ticks_per_second,"cases":cases}))
    quit(0 if failures==0 else 1)

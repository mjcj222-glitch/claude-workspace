extends SceneTree
const Inlet = preload("res://scripts/v2/inlet_geometry.gd")
const Reference = preload("res://tests/v2/fixtures/inlet_geometry_reference.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; print("FAIL: ",message)
func rect(x0: float,y0: float,x1: float,y1: float) -> PackedVector2Array:
    return PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)])
func compare(p: PackedVector2Array,obstacles: Array,sample: float,label_value: String) -> Dictionary:
    var audit := {"details":true}
    var actual := Inlet.choose(p,obstacles,sample,100,100,-20,1,audit)
    var old_audit := {"details":true}
    var expected := Reference.choose(p,obstacles,sample,100,100,-20,1,old_audit)
    check(audit.get("blocked",[]) == old_audit.blocked and audit.get("point_hits",{}) == old_audit.point_hits,"blocked union and isolated event-key/value differential: "+label_value)
    check(audit.get("event_xs",[]) == old_audit.event_xs and audit.get("representative_xs",[]) == old_audit.representative_xs and audit.get("ranked",[]) == old_audit.ranked,"complete event/representative/rank differential: "+label_value)
    check(actual == expected,"frozen placement differential: "+label_value)
    if not actual.is_empty():
        var poly := Geometry.transformed(p,Vector2(actual.x,actual.y),0)
        for other in obstacles: check(Geometry.distance(poly,other) >= 1,"independent actual guard: "+label_value)
    check(audit.has("envelope") and audit.has("blocked") and audit.has("point_hits") and audit.has("event_xs") and audit.has("ranked"),"full intermediate audit available: "+label_value)
    return audit
func run() -> void:
    var merge_cases: Array = [
        [[],[]],
        [[Reference._line(0,2,3,3),Reference._line(5,8,4,4)],[Reference._line(1,6,9,1)]],
        [[Reference._line(0,10,0,10)],[Reference._line(0,10,10,0)]],
        [[Reference._line(0,10,3,3)],[Reference._line(0,10,3,3)]],
        [[Reference._line(0,5,5,5),Reference._line(5,10,0,0)],[Reference._line(0,10,2,2)]],
        [[Reference._line(0,100,50,50)],[Reference._line(20,30,80,80),Reference._line(60,70,90,90)]],
        [[Reference._line(1.0,1.0000000000000002,1,2)],[Reference._line(1.0,1.0000000000000002,2,1)]]]
    for pair in merge_cases:
        var old := Reference._merge(pair[0],pair[1])
        var current := Inlet._merge(pair[0],pair[1])
        check(old == current,"linear merge preserves full original domains/coefficients/gaps/crossing/ties/rounded midpoint")
        for line in old:
            for x in [line.x0,line.x1,(line.x0+line.x1)/2]: check(Inlet._depth(current,x) == Reference._depth(old,x),"closed endpoint depth differential")
    var p := rect(-2,-2,2,2)
    compare(p,[rect(0,-40,100,0)],50,"blocked aperture")
    compare(p,[rect(0,40,39,100),rect(61,40,100,100)],0,"gap")
    compare(rect(-1,-1,1,1),[rect(-10,20,1,30)],-5,"isolated point event")
    var roofs: Array = [rect(-20,20,120,30),rect(-20,70,120,80)]
    var dominance := compare(p,roofs,50,"complete roof and dominated lower hull")
    check(dominance.get("depth_pruned",0) > 0,"certified depth dominance skips covered lower component")
    var gap_audit := compare(p,[rect(0,20,40,30),rect(60,20,100,30),rect(-20,70,120,80)],50,"roof gap retains lower obstruction")
    check(gap_audit.get("depth_pruned",0) == 0,"no complete roof certificate across open gap")
    var point_audit := compare(rect(-1,-1,1,1),[rect(-20,30,120,40),rect(-10,70,1,80)],-5,"dominated isolated point key")
    check(point_audit.get("point_hits",{}).has(2.0),"depth-dominated isolated event remains observable")
    var slope_a := PackedVector2Array([Vector2(0,20),Vector2(100,120),Vector2(100,140),Vector2(0,140)])
    var slope_b := PackedVector2Array([Vector2(0,120),Vector2(100,20),Vector2(100,140),Vector2(0,140)])
    compare(rect(-1,-1,1,1),[slope_a,slope_b,rect(-20,90,120,100)],10,"crossing and lower component")
    var concave := PackedVector2Array([Vector2(0,-40),Vector2(40,-40),Vector2(40,60),Vector2(60,60),Vector2(60,-40),Vector2(100,-40),Vector2(100,100),Vector2(0,100)])
    compare(p,[concave],50,"convex decomposition retains concave cell")
    var occupancy := compare(p,[rect(-20,20,120,30),rect(48,-30,52,-10)],50,"birth blocker independent of depth")
    check(not occupancy.get("blocked",[]).is_empty(),"birth occupancy preserved independently")
    for gap in [2.0,1.0,0.9999999]:
        compare(p,[rect(52+gap,-22,56+gap,-18)],50,"actual AABB separation at margin %.10f" % gap)
    for boundary in [-23.0,-22.0,-21.0,-19.0,-18.0,-17.0]:
        compare(p,[rect(30,boundary,70,boundary+1)],50,"expanded slice extrema %.1f" % boundary)
    var clear := compare(p,[rect(0,70,20,80)],50,"far actual clearance")
    check(clear.get("clearance_pruned",0) > 0,"conservative AABB avoids far polygon distance")
    var cached := compare(p,[rect(0,70,20,80)],50,"identical exact inputs")
    check(cached.get("decomposition_cache_hits",0) == 2,"unchanged exact obstacle and head cached")
    var changed := compare(p,[rect(0.00000001,70,20,80)],50,"actual tiny vertex change")
    check(changed.get("decomposition_cache_hits",0) == 1,"tiny actual vertex invalidates only changed obstacle")
    check(changed.get("decomposition_cache_entries",100) <= 2,"cache bounded to current polygons and head")
    var rotated := Geometry.transformed(rect(0.00000001,70,20,80),Vector2.ZERO,0.00001)
    var angle_audit := compare(p,[rotated],50,"tiny actual angle invalidates geometry")
    check(angle_audit.get("decomposition_cache_hits",0) == 1,"angle change invalidates obstacle, not unchanged head")
    var incoming_change := compare(Geometry.transformed(p,Vector2.ZERO,0.00001),[rotated],50,"tiny incoming angle invalidates head")
    check(incoming_change.get("decomposition_cache_hits",0) == 1,"head angle change invalidates head, not unchanged obstacle")
    print(JSON.stringify({"suite":"v2 inlet computation equivalence","checks":checks,"failures":failures}))
    quit(0 if failures == 0 else 1)

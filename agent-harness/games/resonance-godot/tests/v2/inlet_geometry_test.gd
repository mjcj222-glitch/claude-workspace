extends SceneTree
## Constructed layouts and independent actual-polygon checks, not inlet formulas.
const Inlet = preload("res://scripts/v2/inlet_geometry.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; print("FAIL: ",message)
func rect(x0: float,y0: float,x1: float,y1: float) -> PackedVector2Array:
    return PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)])
func choose(p: PackedVector2Array, obstacles: Array, sample: float, width: float = 100) -> Dictionary:
    return Inlet.choose(p,obstacles,sample,width,100,-20,1)
func safe(p: PackedVector2Array, obstacles: Array, result: Dictionary, width: float = 100) -> void:
    check(not result.is_empty(),"constructed admissible entrance exists")
    if result.is_empty(): return
    var actual := Geometry.transformed(p,Vector2(result.x,result.y),0)
    for v in actual: check(v.x >= 1 and v.x <= width-1 and v.y <= -1,"actual birth hull within walls and above board")
    for obstacle in obstacles: check(Geometry.distance(actual,obstacle) >= 1,"actual hull separation rechecked independently")
func run() -> void:
    var compact := Inlet._merge([Inlet._line(0,100,50,50)],[Inlet._line(20,30,80,80),Inlet._line(60,70,90,90)])
    check(compact.size() == 1 and Inlet._depth(compact,25) == 50,"irrelevant branch endpoints coalesce only the identical original affine branch")
    var p := rect(-10,-10,10,10)
    var empty := choose(p,[],37)
    safe(p,[],empty)
    check(not empty.is_empty() and empty.x == 37 and empty.y == -20 and empty.depth == 90,"empty floor plateau retains sampled x")
    var side := choose(p,[],-9)
    check(not side.is_empty() and side.x == 11,"sample projects to exact permitted wall boundary")
    check(choose(p,[rect(0,-40,100,0)],50).is_empty(),"full birth aperture blocked")
    check(choose(p,[rect(0,5,100,100)],50).is_empty(),"first hit leaving top negative rejected")
    var endpoint := choose(rect(-1,-1,1,1),[rect(-10,20,1,30)],-5)
    check(not endpoint.is_empty() and endpoint.x > 2 and endpoint.depth == 99,"isolated wall-domain tangent is a hit, open cell keeps floor depth")
    var roofs: Array = [rect(0,40,39,100),rect(61,40,100,100)]
    var gap := choose(p,roofs,0)
    safe(p,roofs,gap)
    check(not gap.is_empty() and gap.x == 50 and gap.depth == 90,"open deep cell uses interior midpoint, tangency endpoints cannot pass")
    var tangent: Array = [rect(0,40,40,100),rect(60,40,100,100)]
    var tangency := choose(p,tangent,50)
    check(not tangency.is_empty() and tangency.depth == 30,"exact side tangency counts as first hit")
    var a := PackedVector2Array([Vector2(0,20),Vector2(100,120),Vector2(100,140),Vector2(0,140)])
    var b := PackedVector2Array([Vector2(0,120),Vector2(100,20),Vector2(100,140),Vector2(0,140)])
    var crossing := choose(rect(-1,-1,1,1),[a,b],10)
    safe(rect(-1,-1,1,1),[a,b],crossing)
    check(not crossing.is_empty() and crossing.x == 50 and crossing.depth == 68,"lower envelope maximum occurs at geometric crossing")
    var concave := PackedVector2Array([Vector2(0,-40),Vector2(20,-40),Vector2(20,60),Vector2(40,60),Vector2(40,-40),Vector2(60,-40),Vector2(60,100),Vector2(0,100)])
    var small := rect(-2,-2,2,2)
    var notch := choose(small,[concave],30,60)
    safe(small,[concave],notch,60)
    check(not notch.is_empty() and notch.x == 30 and notch.depth == 58,"concave opening retained rather than whole-hull convex approximation")
    var first := choose(p,[],50)
    var actual_birth := Geometry.transformed(p,Vector2(first.get("x",50),first.get("y",-20)),0)
    var second := choose(p,[actual_birth],50)
    safe(p,[actual_birth],second)
    check(not second.is_empty() and second.x != first.get("x",50),"second same-step birth recomputes real occupied aperture")
    for hull in range(4):
        var irregular := Geometry.transformed(Geometry.polygon(hull,0.97),Vector2.ZERO,0.713)
        var result := Inlet.choose(irregular,[],310,600,600,-60,1)
        safe(irregular,[],result,600)
        check(not result.is_empty() and result.x == 310,"rotated actual hull empty plateau and bounded height")
    print(JSON.stringify({"suite":"v2 finite aperture geometry","checks":checks,"failures":failures}))
    quit(0 if failures == 0 else 1)

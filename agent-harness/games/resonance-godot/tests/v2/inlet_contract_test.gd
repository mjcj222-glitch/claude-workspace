extends SceneTree
const G=preload("res://scripts/v2/inlet_geometry.gd")
var checks:=0
var failures:=0
func rect(x0:float,y0:float,x1:float,y1:float)->PackedVector2Array:return PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)])
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",message)
func same(a:Variant,b:Variant)->bool:return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func _initialize()->void:call_deferred("run")
func run()->void:
    var incoming:=rect(-10,-10,10,10)
    var obstacles:Array=[rect(0,-100,39,100),rect(61,-100,100,100)]
    var audit:Dictionary={"details":true}
    var result:=G.choose(incoming,obstacles,50,100,100,-20,1,audit)
    check(not result.is_empty(),"touching OPEN spans preserve isolated x50 actual1px clearance")
    if not result.is_empty():check(result.x==50 and result.y == -20 and result.depth==90,"exact singleton entrance and floor firsthit")
    obstacles.append(rect(49,-100,51,100))
    check(G.choose(incoming,obstacles,50,100,100,-20,1).is_empty(),"third interval INTERIOR legitimately closes singleton")
    check(same(G._open_union([[0,50],[50,50],[50,100]]),[[0,50],[50,100]]),"zero span cannot bridge puncture")
    check(same(G._open_union([[0,50],[50,100],[49,51]]),[[0,100]]),"third open interior closes puncture")
    check(G._open_union([[50,50]]).is_empty(),"zero length open interval blocks nothing")
    var covered_audit:Dictionary={}
    check(G.choose(incoming,[rect(-100,-100,200,100)],50,100,100,-20,1,covered_audit).is_empty(),"whole birth domain genuinely blocked")
    check(covered_audit.get("certificate","")=="birth_cover" and covered_audit.get("diagnostics_complete",true)==false,"certified birth-domain empty ends construction with honest incomplete diagnostics")
    var roof_audit:Dictionary={}
    check(G.choose(incoming,[rect(-100,0,200,1)],50,100,100,-20,1,roof_audit).is_empty(),"whole firsthit strictly too high")
    check(roof_audit.get("certificate","")=="above_board","strict complete-domain firsthit certificate")
    var boundary:=G.choose(incoming,[rect(-100,20,200,21)],50,100,100,-20,1)
    check(not boundary.is_empty() and boundary.depth==10,"firsthit equality remains fully inboard and cannot certify empty")
    check(not G._birth_covered([[0,11],[11,100]],11,89),"equality/puncture at closed domain edge prevents birth certificate")
    check(not G._birth_covered([[0,50],[50,100]],11,89),"singleton interior puncture prevents certificate")
    check(G._birth_covered([[0,51],[49,100]],11,89),"strict true overlapping union covers closed domain")
    check(not G._birth_covered([[11,100]],11,89) and not G._birth_covered([[0,89]],11,89),"both closed legal endpoints require strict blocked membership")
    var equality:Dictionary=G._line(11,89,10,10);equality.geometric_ymax=10
    check(not G._too_high([equality],11,89,10),"equal threshold cannot certify")
    var low:Dictionary=G._line(11,89,9,9);low.geometric_ymax=9
    check(G._too_high([low],11,89,10),"strict source and evaluated upper bounds certify")
    var gap_a:Dictionary=G._line(11,49,9,9);gap_a.geometric_ymax=9
    var gap_b:Dictionary=G._line(50,89,9,9);gap_b.geometric_ymax=9
    check(not G._too_high([gap_a,gap_b],11,89,10),"uncovered tiny domain interval cannot certify")
    print(JSON.stringify({"checks":checks,"failures":failures}))
    quit(1 if failures else 0)

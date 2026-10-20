extends SceneTree
const S=preload("res://scripts/v2/selection_rules.gd")
const Old=preload("res://tests/v2/fixtures/selection_reference.gd")
const F=preload("res://tests/v2/fixtures.gd")
const Geometry=preload("res://scripts/v2/geometry.gd")
var checks:=0
var failures:=0
var evaluator=S.new()
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",message)
func _initialize()->void:call_deferred("run")
func existence(snapshot:Dictionary)->bool:
    for item in snapshot.pieces:
        if not Old.preview(snapshot,int(item.id),0).is_empty():return true
    return false
func run()->void:
    var corpus:Array=[]
    for type in ["red","yellow","blue","heart"]:
        for n in [1,2,3,4]:corpus.append(F.chain(n,type))
    for tier in [1,2,3]:corpus.append(F.chain(1,"blue",{1:tier}));corpus.append(F.chain(3,"blue",{2:tier}))
    for gap in [1.0,1.5,1.75,1.751]:
        var snap:=F.chain(3);snap.pieces[2].x=F.circle_step()+F.circle_diameter()+gap;corpus.append(snap)
    var natural:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v2/visible_contact_snapshots.json"))
    corpus.append(natural.initial);corpus.append(natural.actual_release)
    var late:Array=[]
    for i in range(42):late.append(F.tile(i+1,"blue" if i==41 else "red",0,Vector2(i*200,100),1 if i==41 else 0))
    var late_snapshot:=F.snapshot(late);corpus.append(late_snapshot)
    var none:=late_snapshot.duplicate(true);none.pieces[41].bomb_tier=0;corpus.append(none)
    var api:bool=evaluator.get_script().get_script_method_list().any(func(m):return m.name=="has_selection")
    check(api,"call-local has_selection API exists")
    for index in range(corpus.size()):
        var snapshot:Dictionary=corpus[index]
        var before:=snapshot.duplicate(true)
        for item in snapshot.pieces:check(S.preview(snapshot,int(item.id),23)==Old.preview(snapshot,int(item.id),23),"complete original plan every seed case"+str(index))
        check(S.preview(snapshot,-404,23).is_empty(),"invalid seed remains rejected")
        if api:
            var expected:=existence(snapshot)
            var actual:bool=evaluator.call("has_selection",snapshot)
            check(actual==expected,"exact existence and seed evaluation result case"+str(index))
        check(snapshot==before,"all previews/existence are pure")
    if api:
        check(not evaluator.call("has_selection",F.snapshot([])),"empty existence rejected")
        var changed:=late_snapshot.duplicate(true);changed.pieces[41].match_type="heart";changed.pieces[41].bomb_tier=0
        check(not evaluator.call("has_selection",changed),"changed types use fresh call-local context")
    print(JSON.stringify({"checks":checks,"failures":failures,"corpus":corpus.size()}));quit(1 if failures else 0)

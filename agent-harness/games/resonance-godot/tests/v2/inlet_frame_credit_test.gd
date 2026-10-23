extends SceneTree
class Board:
    extends "res://scripts/v2/board.gd"
    var attempts:=0
    func _admit_available()->void:
        var prior=get("_attempt_frame")
        super._admit_available()
        if get("_attempt_frame")!=prior:attempts+=1
    func begin_measure()->void:attempts=0

var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",message)
func _initialize()->void:call_deferred("run")
func count(board)->int:return board.attempts
func tick(board)->void:board._physics_process(1.0/120.0)
func run()->void:
    var board=Board.new();root.add_child(board);board.set_physics_process(false);board.begin_measure()
    var signals:Array=[];board.settled.connect(func(_s):signals.append(true))
    var batch:Array=board.make_refill(42);var state:=str(board.rng.state);var version:int=board.version
    board.apply_clear([],batch)
    check(board.pieces.is_empty() and board._pending_batch.size()==42 and count(board)==0,"all42 off-boundary activation defers query and birth")
    if not board.get_property_list().any(func(prop):return prop.name=="_attempt_frame"):
        check(false,"real Board owns process-frame admission credit")
        board.free();print(JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
    check(board.settling and board.refill_phase=="incoming" and board.elapsed==0 and board.version==version+1,"activation immediately owns original clock and single version")
    board._admit_available()
    check(count(board)==0 and board._attempt_frame==-1,"off-boundary skip spends no credit")
    tick(board);tick(board);tick(board)
    check(count(board)==1 and board.pieces.size()==1 and board._pending_batch.size()==41,"one successful attempt across actual same-process catchup callbacks")
    check(board.elapsed>0.024 and signals.is_empty() and board.settling,"skipped callbacks advance total physics clock without partial settled")
    check(str(board.rng.state)==state and board.next_id==43 and board._pending_batch==batch.slice(1) and board.by_id(1)!=null,"credit never redraws or reorders immutable batch")
    var frame:int=Engine.get_process_frames()
    while Engine.get_process_frames()==frame:await process_frame
    tick(board)
    check(count(board)==2,"next actual process frame permits one new current-world query")
    board._clear_bodies();board.begin_measure()
    var obstacle:Dictionary=board.make_refill(1)[0];obstacle.x=300;obstacle.y=-60;obstacle.size=50;obstacle.angle=0
    board._spawn(obstacle)
    board.apply_clear([],board.make_refill(2));board.refill_phase="incoming"
    tick(board);tick(board);tick(board)
    check(count(board)==1 and board.pieces.size()==1 and board._pending_batch.size()==2,"blocked attempt spends shared catchup credit")
    frame=Engine.get_process_frames()
    while Engine.get_process_frames()==frame:await process_frame
    tick(board)
    check(count(board)==2 and board._pending_batch.size()==2,"blocked head is recomputed once next actual frame")
    board._clear_bodies()
    check(board._attempt_frame==-1 and board._pending_batch.is_empty(),"reset clears credit and pending ownership")
    board.apply_clear([],board.make_refill(2));tick(board)
    board.apply_clear([],board.make_refill(2))
    check(board._attempt_frame==-1 and board._pending_batch.size()==2,"every replacement batch owns fresh credit")
    var saved:Dictionary=board.checkpoint();saved.snapshot.pieces=[]
    board.restore(saved)
    check(board._attempt_frame==-1 and board._pending_batch.is_empty() and not board.settling,"restore clears credit and pending without later work")
    board.new_board(73)
    check(board._attempt_frame==-1 and board._pending_batch.is_empty(),"new board resets inherited operation ownership")
    board._clear_bodies();board.apply_clear([],board.make_refill(2));board.elapsed=12;tick(board)
    check(board.refill_phase=="error" and board._attempt_frame==-1 and board._pending_batch.is_empty(),"original artificial deadline clears credit and pending")
    var before:int=board.pieces.size();tick(board);board._admit_available()
    check(board.pieces.size()==before,"error schedules no delayed birth")
    var completions:Array=[];board.recovery_settlement_finished.connect(func():completions.append(true));board._recovering=true
    board.free()
    check(completions.size()==1,"retirement preserves inherited recovery completion exactly once")
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(1 if failures else 0)

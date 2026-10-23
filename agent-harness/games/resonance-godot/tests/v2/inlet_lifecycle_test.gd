extends SceneTree
## Consecutive real batches and cancellation. Birth observations never change production behavior.
const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
class AuditBoard:
    extends "res://scripts/v2/board.gd"
    var births: Array = []
    func _spawn(item: Dictionary, restored: bool = false):
        var body = super._spawn(item,restored)
        births.append(body.snapshot())
        return body
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; print("FAIL: ",message)
func wait_board(board: Node) -> void:
    for tick in range(1800):
        if not board.settling: return
        await physics_frame
    check(false,"physical operation stays bounded")
func pick(board: Node) -> Dictionary:
    var snapshot: Dictionary = board.capture()
    for item in snapshot.pieces:
        var plan := Selection.preview(snapshot,int(item.id),1)
        if not plan.is_empty() and plan.removed_ids.size() <= 8: return plan
    return {}
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args(): quit(1); return
    var board = AuditBoard.new()
    root.add_child(board)
    board.new_board(73)
    await wait_board(board)
    var settlements: Array = []
    board.settled.connect(func(s): settlements.append(s.duplicate(true)))
    for cycle in range(3):
        var plan := pick(board)
        check(not plan.is_empty(),"reused board has legal action")
        if plan.is_empty(): break
        var batch: Array = board.make_refill(plan.removed_ids.size())
        var immutable := batch.duplicate(true)
        var rng_before: String = board.checkpoint().rng_state
        var next_before: int = board.next_id
        var version_before: int = board.version
        var signals_before := settlements.size()
        board.births.clear()
        board.apply_clear(plan.removed_ids,batch)
        while board.settling:
            check(board.version == version_before+1,"admission never adds board versions")
            check(settlements.size() == signals_before,"no intermediate partial settlement")
            await physics_frame
        check(board.refill_phase == "settled" and board.pieces.size() == 42 and board.supported(board.capture()) and board.elapsed <= 12,"consecutive physical refill has final42 support bounds deadline")
        check(settlements.size() == signals_before+1,"one final settlement for complete batch")
        check(batch == immutable and board.checkpoint().rng_state == rng_before and board.next_id == next_before,"batch IDs and RNG are allocated only once")
        check(board.births.size() == batch.size(),"each original batch member born once")
        for index in range(board.births.size()):
            var born: Dictionary = board.births[index]
            var poly:=Geometry.transformed(Geometry.polygon(born.hull_id,born.size),Vector2(born.x,born.y),born.angle)
            check(Array(poly).all(func(point):return point.x>=Config.CONTACT_EPS and point.x<=Config.BOARD_WIDTH-Config.CONTACT_EPS and point.y<=-Config.CONTACT_EPS),"finite-aperture birth keeps entire actual hull above board and inside width")
            for key in ["id","hull_id","match_type","size","angle","bomb_tier"]:
                check(born[key] == batch[index][key],"sampled birth field preserved: "+key)
        print(JSON.stringify({"cycle":cycle,"removed_ids":plan.removed_ids,"elapsed":board.elapsed,"births":board.births.size()}))
    var stable: Dictionary = board.checkpoint().duplicate(true)
    for mode in ["restore","new_board","timeout"]:
        var plan := pick(board)
        var batch: Array = board.make_refill(plan.removed_ids.size())
        board.apply_clear(plan.removed_ids,batch)
        if mode == "restore": board.restore(stable)
        elif mode == "new_board": board.new_board(73)
        else:
            board.elapsed = Config.SETTLE_TIMEOUT
            board._physics_process(1.0/120.0)
            check(board.refill_phase == "error" and not board.settling,"actual timeout branch stops pending admission")
        check(board._pending_batch.is_empty() and board._pending_openings.is_empty() and board._admitted_count == 0,"replacement/timeout clears pending batch and admission cursor")
        if mode == "new_board": await wait_board(board)
        elif mode == "timeout": board.restore(stable)
    board.free()
    print(JSON.stringify({"suite":"v2 inlet consecutive batches and cancellation fixtures","checks":checks,"failures":failures}))
    quit(0 if failures == 0 else 1)

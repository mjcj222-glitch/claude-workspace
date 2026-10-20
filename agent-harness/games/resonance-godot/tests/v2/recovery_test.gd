extends SceneTree
## Recovery must never generate a batch, grant a reward, or save a broken board.
const Board = preload("res://scripts/v2/board.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
const RunV2 = preload("res://scripts/v2/run_rules.gd")
const Config = preload("res://scripts/v2/config.gd")
const Expedition = preload("res://scripts/v2/expedition.gd")
const BattleScene = preload("res://scenes/v2/battle.tscn")
class ObservedBoard:
    extends "res://scripts/v2/board.gd"
    var refills := 0
    var drops := 0
    var permutations := 0
    func apply_types(changes: Dictionary) -> Dictionary:
        permutations += 1
        return super.apply_types(changes)
    func make_refill(count: int) -> Array:
        refills += 1
        return super.make_refill(count)
    func _start_settling() -> void:
        drops += 1
        super._start_settling()
class FixtureExpedition:
    extends "res://scripts/v2/expedition.gd"
    var fixture_path := ""
    func save_checkpoint(_path: String = Config.SAVE_PATH) -> Error:
        return super.save_checkpoint(fixture_path)
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func legal(snapshot: Dictionary) -> bool:
    for p in snapshot.pieces:
        if not Selection.preview(snapshot,p.id,1).is_empty(): return true
    return false
func counts(snapshot: Dictionary) -> Dictionary:
    var out := {}
    for p in snapshot.pieces: out[p.match_type] = int(out.get(p.match_type,0))+1
    return out
func physical(snapshot: Dictionary) -> Array:
    var out: Array = []
    for p in snapshot.pieces:
        out.append([p.id,p.hull_id,p.size,p.x,p.y,p.angle,p.bomb_tier])
    return out
func wait_ready(owner: Node) -> bool:
    for tick in range(4200):
        if owner.phase in ["READY","FINISHED","ERROR"]: return owner.phase != "ERROR"
        await physics_frame
    return false
func blocked(board: Node) -> Dictionary:
    # Preserve a real supported physical pile; assign surfaces so no component
    # exceeds two. Reject any fixture construction failure explicitly.
    var snap: Dictionary = board.capture()
    var edges := Geometry.graph(snap)
    var assigned := {}
    for p in snap.pieces:
        for type in Config.TYPES:
            assigned[p.id] = type
            var seen: Array = [p.id]
            var cursor := 0
            while cursor < seen.size():
                for other in edges[seen[cursor]]:
                    if assigned.get(other,"") == type and not seen.has(other): seen.append(other)
                cursor += 1
            if seen.size() < 3: break
        p.match_type = assigned[p.id]
        p.bomb_tier = 0
    check(not legal(snap),"fixture has no valid group or solo bomb")
    return snap
func restore_snapshot(board: Node, snap: Dictionary) -> void:
    var record: Dictionary = board.checkpoint()
    record.snapshot = snap
    board.restore(record)
func run() -> void:
    var probe = Board.new()
    check(probe.has_method("recover_if_blocked"),"Board exposes finite blocked-board recovery")
    probe.free()
    if failures:
        finish()
        return
    var data := OS.get_environment("XDG_DATA_HOME")
    check(data.is_absolute_path() and "/xdg/task9-" in data,"explicit isolated Task9 XDG")
    var board = ObservedBoard.new()
    root.add_child(board)
    board.new_board(41)
    while board.settling: await physics_frame
    var natural: Dictionary = board.checkpoint()
    var no_change: Dictionary = await board.recover_if_blocked()
    check(no_change.status == "unchanged" and board.checkpoint() == natural,"legal board is byte-for-byte unchanged")
    var snap := blocked(board)
    restore_snapshot(board,snap)
    var before: Dictionary = board.checkpoint()
    var refill_count: int = board.refills
    var drop_count: int = board.drops
    var recovered: Dictionary = await board.recover_if_blocked()
    check(recovered.status == "recovered" and legal(recovered.snapshot),"blocked real supported board gains legal selection")
    check(counts(recovered.snapshot) == counts(before.snapshot),"type counts conserved")
    check(physical(recovered.snapshot) == physical(before.snapshot),"swap stage preserves exact IDs hulls sizes poses angles and bombs")
    check(board.refills == refill_count and board.drops == drop_count,"successful swap has no refill or physical redrop")
    check(board.checkpoint().rng_state == before.rng_state and board.next_id == before.next_id,"recovery consumes no main RNG or identities")
    check(recovered.snapshot.version > before.snapshot.version,"recovery monotonically advances board version")
    var expected: Array = recovered.snapshot.pieces.duplicate(true)
    board.restore(before)
    recovered = await board.recover_if_blocked()
    check(recovered.snapshot.pieces == expected,"same blocked snapshot recovers deterministically without main RNG")
    board.restore(natural)
    snap = blocked(board)
    snap.pieces[0].match_type = "blue"
    snap.pieces[0].bomb_tier = 1
    restore_snapshot(board,snap)
    before = board.checkpoint()
    no_change = await board.recover_if_blocked()
    check(no_change.status == "unchanged" and board.checkpoint() == before,"solo bomb prevents recovery")
    # Contactless fixture cannot be repaired by any type permutation. All
    # existing bodies are retained for the one real redrop.
    board.restore(natural)
    snap = blocked(board)
    for i in range(snap.pieces.size()):
        snap.pieces[i].x = 1000+i*200
        snap.pieces[i].y = -200
    restore_snapshot(board,snap)
    before = board.checkpoint()
    var identities: Array = board.pieces.duplicate()
    drop_count = board.drops
    recovered = await board.recover_if_blocked()
    check(board.permutations <= Config.RECOVERY_ATTEMPTS,"deterministic swap attempts stay within configured eight")
    check(board.drops == drop_count+1,"impossible contact triple causes at most one real redrop")
    check(board.pieces == identities and counts(board.capture()) == counts(before.snapshot),"redrop retains SAME42 body identities and exact type counts")
    check(board.refills == refill_count and board.checkpoint().rng_state == before.rng_state,"redrop never allocates/refills/draws RNG")
    check(recovered.status in ["recovered","error"],"redrop returns honest finite result")
    board.restore(before)
    var cancelled: Array = []
    collect_recovery(board,cancelled)
    check(board.settling,"cancellation fixture owns a real pending redrop")
    board.restore(natural)
    check(cancelled.size() == 1 and cancelled[0].status == "error" and not board.settling,"restore resolves old async recovery without stale success")
    for tick in range(60): await physics_frame
    check(cancelled.size() == 1 and board.capture().pieces == natural.snapshot.pieces,"cancelled recovery never mutates restored layout after physics frames")
    await failure_and_resume(data,natural)
    board.free()
    finish()
func collect_recovery(board: Node, out: Array) -> void:
    out.append(await board.recover_if_blocked())
func failure_and_resume(data: String, _natural: Dictionary) -> void:
    var expedition = FixtureExpedition.new()
    expedition.fixture_path = data.path_join("fixture-recovery-v2.json")
    root.add_child(expedition)
    check(await wait_ready(expedition.battle),"Expedition real initial board ready")
    check(expedition.save_checkpoint() == OK,"explicit normal fixture checkpoint saved")
    var last: Dictionary = expedition.last_good_checkpoint()
    var good_bytes := FileAccess.get_file_as_bytes(expedition.fixture_path)
    var owner: Node = expedition.battle
    var snap := blocked(owner.board)
    for i in range(snap.pieces.size()):
        snap.pieces[i].x = 1000+i*200
        snap.pieces[i].y = -200
    owner.phase = "RESTORING"
    restore_snapshot(owner.board,snap)
    owner.phase = "SETTLING"
    # Controlled nonzero accounting witness: recovery must preserve everything,
    # including active bomber generation and already accrued turn resources.
    owner.state.party = ["hero","bomber"]
    owner.state.bomb_buff = {"active":true,"paid_cost":6,"generated_count":2,"refunded":false}
    owner.state.energy = 2
    owner.state.actions_left = 2
    owner.state.pending_damage = 7
    owner.state.pending_heal = 3
    owner.state.team_skill_used = true
    owner.action_count = 2
    owner.refill_batch_count = 3
    owner._generated_bombs = 5
    var state_before: Dictionary = owner.state.duplicate(true)
    var board_before: Dictionary = owner.board.checkpoint()
    var checkpoints: Array = []
    owner.checkpoint_available.connect(func():checkpoints.append(true))
    owner._on_settled(owner.board.capture())
    check(owner.phase == "RECOVERING" and owner.board.settling,"actual async recovery owns phase before readiness")
    check(owner.export_checkpoint().is_empty() and expedition.save_checkpoint() == ERR_BUSY,"recovering state refuses save")
    check(expedition.last_good_checkpoint() == last and checkpoints.is_empty(),"no blocked-board READY checkpoint overwrites last good")
    # Exercise the real physical timeout, not a mocked recovery return.
    owner.board.elapsed = Config.SETTLE_TIMEOUT+0.01
    owner.board._physics_process(1.0/120.0)
    await process_frame
    check(owner.phase == "ERROR","actual redrop settle failure ends ERROR")
    check(owner.state == state_before and owner.action_count == 2 and owner.refill_batch_count == 3,"recovery conserves all combat resources and counters")
    check(owner.board.checkpoint().rng_state == board_before.rng_state and owner._generated_bombs == 5,"recovery leaves RNG and bomber accounting unchanged")
    check(owner.export_checkpoint().is_empty() and expedition.save_checkpoint() == ERR_BUSY,"ERROR refuses save")
    check(expedition.last_good_checkpoint() == last and checkpoints.is_empty(),"error retains copied full last-good record")
    check(FileAccess.get_file_as_bytes(expedition.fixture_path) == good_bytes,"recovering/error never replace last-good fixture bytes")
    owner.board.settled.emit(owner.board.capture())
    check(owner.phase == "ERROR" and checkpoints.is_empty(),"late settlement cannot reopen error or emit checkpoint")
    var button = owner.view.get_node_or_null("RecoveryResume")
    check(button != null,"error exposes explicit last-good resume UI")
    if button != null: button.pressed.emit()
    check(expedition.battle != owner and await wait_ready(expedition.battle),"real resume_checkpoint replaces owner and returns playable READY")
    check(expedition.battle.state.hp == last.battle.hp and expedition.battle.snapshot.pieces == last.board.snapshot.pieces,"last-good resume preserves normal resources and layout")
    check(legal(expedition.battle.snapshot),"resumed owner exposes legal normal action")
    var current: Node = expedition.battle
    expedition._on_battle_error("obsolete",owner,expedition.generation-1,str(expedition.run.stage))
    check(current.view.get_node_or_null("RecoveryResume") == null,"obsolete error owner cannot add resume UI")
    # A second failure must not duplicate buttons; ordinary physical errors
    # share the explicit last-good resume path.
    current._on_settle_failed("ordinary settle failure")
    current._on_settle_failed("duplicate settle failure")
    check(current.phase == "ERROR" and current.view.get_node_or_null("RecoveryResume") != null,"ordinary settlement error also offers idempotent resume")
    check(expedition.resume_checkpoint(last),"resume normal checkpoint for owner replacement during recovery")
    var retiring: Node = expedition.battle
    retiring.phase = "RESTORING"
    snap = blocked(retiring.board)
    for i in range(snap.pieces.size()):
        snap.pieces[i].x = 1000+i*200
        snap.pieces[i].y = -200
    restore_snapshot(retiring.board,snap)
    retiring.phase = "SETTLING"
    var old_signals: Array = []
    retiring.checkpoint_available.connect(func():old_signals.append("checkpoint"))
    retiring.recovery_failed.connect(func(_reason):old_signals.append("error"))
    var cancellations: Array = []
    retiring.board.recovery_settlement_finished.connect(func():cancellations.append(true))
    retiring._on_settled(retiring.board.capture())
    check(retiring.phase == "RECOVERING","old owner is genuinely awaiting redrop before new_run")
    expedition.new_run(73)
    check(await wait_ready(expedition.battle),"replacement new_run settles normally after retiring recovery")
    for tick in range(60): await physics_frame
    check(cancellations.size() == 1,"retirement completes pending recovery exactly once")
    check(old_signals.is_empty() and expedition.battle.phase == "READY" and expedition.battle.view.get_node_or_null("RecoveryResume") == null,"retired recovery cannot mutate replacement owner after physics frames")
    expedition.new_run(73)
    var fresh: Node = expedition.battle
    fresh._on_settle_failed("initial failure")
    var restart = fresh.view.get_node_or_null("RecoveryRestart")
    check(expedition.last_good_checkpoint().is_empty() and restart != null,"fresh failure honestly offers explicit new-run when no last good exists")
    expedition.queue_free()
    await process_frame
    var ended = BattleScene.instantiate()
    root.add_child(ended)
    ended.start_battle({"enemy_id":"hall1","seed":41,"hp":72,"energy":4,"party":["hero"],"hero_limit":3,"reduced":true})
    await wait_ready(ended)
    var old: Dictionary = ended.export_checkpoint()
    ended.phase = "RESTORING"
    restore_snapshot(ended.board,blocked(ended.board))
    ended.state.status = "victory"
    ended.phase = "SETTLING"
    var version: int = ended.board.version
    ended._on_settled(ended.board.capture())
    check(ended.phase == "FINISHED" and ended.board.version == version,"finished blocked board skips all recovery")
    ended.restore_checkpoint(old)
    var stale := Combat.preview(ended.snapshot,ended.state,7)
    ended._show_preview(stale,-2)
    var stale_version: int = ended.board.version
    ended.phase = "RESTORING"
    restore_snapshot(ended.board,blocked(ended.board))
    ended.phase = "SETTLING"
    ended._on_settled(ended.board.capture())
    check(ended.phase == "READY" and ended.displayed_plan.is_empty() and ended._pointer == -999,"recovery cancels old held input before READY")
    check(ended.board.version > stale_version and not ended.commit_preview(stale),"old preview cannot commit after recovery")
    ended.queue_free()
    await process_frame
func finish() -> void:
    print(JSON.stringify({"suite":"v2 finite recovery","checks":checks,"failures":failures}))
    quit(0 if failures == 0 else 1)

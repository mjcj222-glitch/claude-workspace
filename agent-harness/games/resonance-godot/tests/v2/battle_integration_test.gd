extends SceneTree
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const Battle = preload("res://scenes/v2/battle.tscn")
class AuditBoard:
    extends "res://scripts/v2/board.gd"
    var batches: Array = []
    var physics_trace: Array = []
    var trace_left := 0
    var was_restored := false
    func new_board(seed_value: int) -> void:
        was_restored = false
        super.new_board(seed_value)
    func restore(saved: Dictionary) -> void:
        super.restore(saved)
        was_restored = true
        physics_trace.clear()
    func _start_settling() -> void:
        if was_restored: trace_left = 5
        was_restored = false
        super._start_settling()
    func _physics_process(delta: float) -> void:
        if trace_left > 0:
            physics_trace.append({"engine_frame":Engine.get_physics_frames(),"snapshot":capture(),"phase":refill_phase,"bodies":pieces.map(func(p):return [p.identity,p.position.x,p.position.y,p.rotation,p.linear_velocity.x,p.linear_velocity.y,p.angular_velocity,p.continuous_cd,p.freeze_mode,p.freeze])})
            trace_left -= 1
        super._physics_process(delta)
    func make_refill(count: int) -> Array:
        var batch := super.make_refill(count)
        batches.append(batch.duplicate(true))
        return batch
const JAM_CHECKPOINT := {
    "next_id": 43,
    "rng_seed": "41",
    "rng_state": "-2010290312403082923",
    "snapshot": {
        "pieces": [
            {
                "angle": 0.687531054019928,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 1,
                "match_type": "red",
                "size": 1.02471113204956,
                "x": 41.8191146850586,
                "y": 558.441589355469
            },
            {
                "angle": 0.0408968552947044,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 2,
                "match_type": "red",
                "size": 0.9777552485466,
                "x": 138.20881652832,
                "y": 559.988586425781
            },
            {
                "angle": -2.07099556922913,
                "bomb_tier": 0,
                "hull_id": 3,
                "id": 3,
                "match_type": "heart",
                "size": 0.997373461723328,
                "x": 251.155197143555,
                "y": 563.77783203125
            },
            {
                "angle": 1.57074797153473,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 4,
                "match_type": "blue",
                "size": 1.0225123167038,
                "x": 358.700256347656,
                "y": 560.5322265625
            },
            {
                "angle": 2.93721747398376,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 5,
                "match_type": "blue",
                "size": 1.02032482624054,
                "x": 462.719085693359,
                "y": 556.591125488281
            },
            {
                "angle": 9.94516085484065e-05,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 6,
                "match_type": "yellow",
                "size": 0.969917058944702,
                "x": 552.115600585938,
                "y": 558.454833984375
            },
            {
                "angle": -2.24076890945435,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 7,
                "match_type": "heart",
                "size": 0.974547028541565,
                "x": 62.158130645752,
                "y": 485.601013183594
            },
            {
                "angle": -0.537828147411346,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 8,
                "match_type": "yellow",
                "size": 1.01030802726746,
                "x": 195.514038085938,
                "y": 506.621917724609
            },
            {
                "angle": 2.51282525062561,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 9,
                "match_type": "red",
                "size": 0.993706405162811,
                "x": 269.335479736328,
                "y": 488.368072509766
            },
            {
                "angle": 1.4998767375946,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 10,
                "match_type": "red",
                "size": 0.990004539489746,
                "x": 349.951629638672,
                "y": 480.533813476562
            },
            {
                "angle": 2.28938460350037,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 11,
                "match_type": "red",
                "size": 0.970870852470398,
                "x": 429.749877929688,
                "y": 482.585113525391
            },
            {
                "angle": -1.36649799346924,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 12,
                "match_type": "red",
                "size": 0.980858266353607,
                "x": 516.680114746094,
                "y": 486.42578125
            },
            {
                "angle": 0.892838299274445,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 13,
                "match_type": "yellow",
                "size": 0.971493899822235,
                "x": 127.33610534668,
                "y": 433.312927246094
            },
            {
                "angle": 1.17432749271393,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 14,
                "match_type": "blue",
                "size": 1.00926065444946,
                "x": 210.360992431641,
                "y": 427.433685302734
            },
            {
                "angle": 0.158396512269974,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 15,
                "match_type": "blue",
                "size": 0.972000300884247,
                "x": 295.743560791016,
                "y": 413.045074462891
            },
            {
                "angle": 1.96058714389801,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 16,
                "match_type": "blue",
                "size": 1.00349950790405,
                "x": 383.900329589844,
                "y": 408.527893066406
            },
            {
                "angle": -0.593482434749603,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 17,
                "match_type": "yellow",
                "size": 1.00134575366974,
                "x": 475.210418701172,
                "y": 423.964599609375
            },
            {
                "angle": -2.09233570098877,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 18,
                "match_type": "red",
                "size": 1.01593399047852,
                "x": 558.693603515625,
                "y": 416.366271972656
            },
            {
                "angle": -1.91700172424316,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 19,
                "match_type": "yellow",
                "size": 0.969763219356537,
                "x": 47.719539642334,
                "y": 405.730438232422
            },
            {
                "angle": 1.593141913414,
                "bomb_tier": 0,
                "hull_id": 3,
                "id": 20,
                "match_type": "heart",
                "size": 1.0013130903244,
                "x": 146.244293212891,
                "y": 366.169311523438
            },
            {
                "angle": -2.1650505065918,
                "bomb_tier": 0,
                "hull_id": 3,
                "id": 21,
                "match_type": "heart",
                "size": 1.03130912780762,
                "x": 246.075164794922,
                "y": 345.870269775391
            },
            {
                "angle": 2.68527007102966,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 22,
                "match_type": "blue",
                "size": 1.03070747852325,
                "x": 339.081817626953,
                "y": 332.697326660156
            },
            {
                "angle": 3.07093667984009,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 23,
                "match_type": "blue",
                "size": 0.997795879840851,
                "x": 449.287841796875,
                "y": 341.286743164062
            },
            {
                "angle": -1.89776134490967,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 24,
                "match_type": "red",
                "size": 1.02835381031036,
                "x": 557.954772949219,
                "y": 333.072418212891
            },
            {
                "angle": 0.525940835475922,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 25,
                "match_type": "yellow",
                "size": 1.01165878772736,
                "x": 48.2696723937988,
                "y": 320.029052734375
            },
            {
                "angle": 1.71684432029724,
                "bomb_tier": 0,
                "hull_id": 3,
                "id": 26,
                "match_type": "heart",
                "size": 0.974984884262085,
                "x": 180.042770385742,
                "y": 303.342498779297
            },
            {
                "angle": -1.63921689987183,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 27,
                "match_type": "blue",
                "size": 1.0245064496994,
                "x": 258.978057861328,
                "y": 267.458770751953
            },
            {
                "angle": -0.0743105486035347,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 28,
                "match_type": "blue",
                "size": 1.00046122074127,
                "x": 336.427642822266,
                "y": 247.268249511719
            },
            {
                "angle": 1.49531412124634,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 29,
                "match_type": "blue",
                "size": 0.965116620063782,
                "x": 414.428955078125,
                "y": 267.551940917969
            },
            {
                "angle": 0.425255209207535,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 30,
                "match_type": "yellow",
                "size": 0.99403578042984,
                "x": 495.519653320312,
                "y": 273.529418945312
            },
            {
                "angle": 1.17478692531586,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 31,
                "match_type": "red",
                "size": 0.989324927330017,
                "x": 40.5488586425781,
                "y": 245.355453491211
            },
            {
                "angle": 1.7674458026886,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 32,
                "match_type": "blue",
                "size": 1.00722122192383,
                "x": 181.34489440918,
                "y": 227.943008422852
            },
            {
                "angle": 1.59461557865143,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 33,
                "match_type": "red",
                "size": 1.01150619983673,
                "x": 263.277679443359,
                "y": 186.042572021484
            },
            {
                "angle": -1.25539040565491,
                "bomb_tier": 0,
                "hull_id": 2,
                "id": 34,
                "match_type": "yellow",
                "size": 1.01183104515076,
                "x": 339.730285644531,
                "y": 166.933364868164
            },
            {
                "angle": 0.105227068066597,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 35,
                "match_type": "red",
                "size": 0.978997051715851,
                "x": 411.072235107422,
                "y": 190.001342773438
            },
            {
                "angle": 2.8790557384491,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 36,
                "match_type": "blue",
                "size": 0.977377653121948,
                "x": 557.483764648438,
                "y": 226.727600097656
            },
            {
                "angle": 0.701118886470795,
                "bomb_tier": 0,
                "hull_id": 3,
                "id": 37,
                "match_type": "heart",
                "size": 0.995793402194977,
                "x": 37.1055641174316,
                "y": 167.271118164062
            },
            {
                "angle": 0.116646908223629,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 38,
                "match_type": "red",
                "size": 0.982269406318665,
                "x": 106.308959960938,
                "y": 198.886993408203
            },
            {
                "angle": -2.94767451286316,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 39,
                "match_type": "blue",
                "size": 0.977682828903198,
                "x": 189.186004638672,
                "y": 151.075546264648
            },
            {
                "angle": 0.0409591384232044,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 40,
                "match_type": "blue",
                "size": 1.03126955032349,
                "x": 278.255737304688,
                "y": 105.020034790039
            },
            {
                "angle": 1.94130265712738,
                "bomb_tier": 0,
                "hull_id": 0,
                "id": 41,
                "match_type": "red",
                "size": 1.01264905929565,
                "x": 431.567016601562,
                "y": 111.127624511719
            },
            {
                "angle": 0.99990701675415,
                "bomb_tier": 0,
                "hull_id": 1,
                "id": 42,
                "match_type": "blue",
                "size": 1.03498780727386,
                "x": 492.59619140625,
                "y": 169.100036621094
            }
        ],
        "version": 21
    }
}
const JAM_BATCH := [
    {
        "angle": -0.769721031188965,
        "bomb_tier": 0,
        "hull_id": 0,
        "id": 43,
        "match_type": "red",
        "size": 0.991022348403931,
        "x": 47.301509141922,
        "y": -60.0
    },
    {
        "angle": -2.08228826522827,
        "bomb_tier": 0,
        "hull_id": 2,
        "id": 44,
        "match_type": "yellow",
        "size": 0.964563131332397,
        "x": 148.562723636627,
        "y": -60.0
    },
    {
        "angle": -1.86173117160797,
        "bomb_tier": 0,
        "hull_id": 1,
        "id": 45,
        "match_type": "blue",
        "size": 1.01446497440338,
        "x": 249.069260835648,
        "y": -60.0
    },
    {
        "angle": -0.177093982696533,
        "bomb_tier": 0,
        "hull_id": 0,
        "id": 46,
        "match_type": "red",
        "size": 0.981375217437744,
        "x": 349.908240556717,
        "y": -60.0
    }
]
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var battle = Battle.instantiate()
    root.add_child(battle)
    battle.board.free()
    battle.board = AuditBoard.new()
    battle.view.bind_board(battle.board)
    battle.board.settled.connect(battle._on_settled)
    battle.board.settle_failed.connect(battle._on_settle_failed)
    battle.start_battle({"enemy_id":"hall1","seed":41,"hp":60,"energy":4,"party":["hero"],"hero_limit":3,"reduced":true})
    for frame in range(1600):
        if battle.phase in ["READY","ERROR"]: break
        await physics_frame
    check(battle.phase == "READY", "start reaches physical settled READY")
    check(battle.board.pieces.size() == 42,"real board has 42 bodies")
    check(not battle.export_checkpoint().is_empty(),"completed waiting state exports checkpoint")
    if battle.phase == "READY" and OS.get_cmdline_user_args().has("--phase-only"):
        await phase_lifecycle(battle)
    elif battle.phase == "READY" and OS.get_cmdline_user_args().has("--replay-only"):
        await replay_jam(battle)
    elif battle.phase == "READY":
        if not OS.get_cmdline_user_args().has("--lifecycle-only"):
            await exercise(battle)
            await extras(battle)
        if not OS.get_cmdline_user_args().has("--skip-lifecycle"):
            await lifecycle_regressions(battle)
            if not OS.get_cmdline_user_args().has("--lifecycle-only"):
                await replay_jam(battle)
                await repeated_restores(battle)
                await phase_lifecycle(battle)
                await final_refund_case(battle)
                await transient_lifecycle(battle)
    battle.free()
    print(JSON.stringify({"suite":"v2 battle integration","checks":checks,"failures":failures}))
    quit(1 if failures else 0)
func legal(battle: Node, low: int = 3, high: int = 8) -> Dictionary:
    var best := {}
    for piece in battle.snapshot.pieces:
        var plan := Combat.preview(battle.snapshot,battle.state,int(piece.id))
        if not plan.is_empty() and plan.removed_ids.size() >= low and plan.removed_ids.size() <= high and (best.is_empty() or plan.removed_ids.size() > best.removed_ids.size()):
            best = plan
    return best
func point(battle: Node, id: int) -> Vector2:
    var tile = battle.board.by_id(id)
    return battle.view.get_node("BoardViewport").board_to_logical(tile.position)
func touch(position: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.position = root.get_final_transform() * position
    event.pressed = pressed
    event.index = index
    event.canceled = canceled
    Input.parse_input_event(event)
    for frame in range(3): await process_frame
func drag(position: Vector2, index: int = 0) -> void:
    var event := InputEventScreenDrag.new()
    event.position = root.get_final_transform() * position
    event.index = index
    Input.parse_input_event(event)
    for frame in range(3): await process_frame
func wait_ready(battle: Node) -> void:
    for frame in range(1800):
        if battle.phase in ["READY","FINISHED","ERROR"]: break
        await physics_frame
    if battle.phase == "ERROR": print("SETTLE_DIAGNOSTIC ",JSON.stringify({"elapsed":battle.board.elapsed,"supported":battle.board.supported(battle.board.capture()),"locks":battle.lock_measurements,"pieces":battle.board.capture()}))
    check(battle.phase != "ERROR","actual refill settles without timeout")
func exercise(battle: Node) -> void:
    var plan := legal(battle)
    check(not plan.is_empty(),"seed41 has legal ordinary3–8 removal")
    if plan.is_empty(): return
    var pos := point(battle,int(plan.seed_id))
    var owner_before: Dictionary = battle.board.checkpoint()
    await touch(pos,true)
    check(battle.displayed_plan == plan,"native touch shows exact Combat ActionPlan")
    check(battle.export_checkpoint().is_empty(),"held preview cannot export")
    await touch(pos,true,1)
    await touch(pos,false,1)
    check(battle.displayed_plan == plan,"secondary pointer cannot consume hold")
    await drag(Vector2(0,0))
    await drag(pos)
    await touch(pos,false)
    check(battle.action_count == 0,"outside reentry permanently cancels hold")
    check(battle.board.checkpoint() == owner_before and battle.refill_batch_count == 0,"actual owner RNG nextID poses unchanged on preview invalid cancel")
    await touch(pos,true)
    root.size_changed.emit()
    await touch(pos,false)
    check(battle.action_count == 0,"viewport resize cancels native hold")
    await touch(pos,true)
    battle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    await touch(pos,false)
    check(battle.action_count == 0,"native focus notification cancels hold")
    await touch(pos,true)
    await touch(pos,false,0,true)
    check(battle.action_count == 0,"OS canceled touch spends nothing")
    await touch(pos,true)
    battle.state.revision += 1
    await touch(pos,false)
    check(battle.action_count == 0,"stale combat version rejected")
    await touch(pos,true)
    battle.board.apply_types({int(plan.seed_id):"heart"})
    await touch(pos,false)
    check(battle.action_count == 0,"stale board version rejected")
    check(battle.board.rng.state == int(owner_before.rng_state) and battle.board.next_id == owner_before.next_id and battle.refill_batch_count == 0,"invalid versions never allocate actual refill")
    battle.start_battle({"enemy_id":"hall1","seed":41,"hp":60,"energy":4,"party":["hero"],"hero_limit":3,"reduced":true})
    await wait_ready(battle)
    owner_before = battle.board.checkpoint()
    plan = legal(battle)
    pos = point(battle,int(plan.seed_id))
    await touch(pos,true)
    var shown: Dictionary = battle.displayed_plan.duplicate(true)
    var forged := shown.duplicate(true)
    forged.direct_damage += 99
    check(not battle.commit_preview(forged),"public commit rejects altered displayed content")
    await touch(pos,false)
    check(battle.action_count == 1,"native release commits once")
    await touch(pos,false)
    check(not battle.commit_preview(shown),"same ActionPlan cannot commit twice")
    check(battle.export_checkpoint().is_empty(),"falling state cannot export")
    var pending_revision: int = battle.state.revision
    battle.board.settled.emit(owner_before.snapshot)
    check(battle.state.revision == pending_revision and battle.state.refill_pending and battle.phase == "SETTLING","foreign stale settled during pending action cannot finish")
    await touch(pos,true)
    await touch(pos,false)
    await wait_ready(battle)
    var absent: Array = []
    for piece in owner_before.snapshot.pieces:
        if battle.board.by_id(int(piece.id)) == null: absent.append(int(piece.id))
    check(absent == shown.removed_ids,"actual absent original IDs exactly match displayed union")
    check(battle.refill_batch_count == 1 and battle.action_count == 1,"one action produces one refill batch")
    check(battle.board.pieces.size() == 42 and not battle.state.refill_pending,"42 bodies after exactly one finish")
    var revision: int = battle.state.revision
    battle.board.settled.emit(battle.board.capture())
    check(battle.state.revision == revision,"duplicate settled cannot finish twice")
    check(battle.state.pending_damage == shown.direct_damage+shown.blast_damage,"displayed accrual adopted")
    if battle.phase == "ERROR": return
    var record: Dictionary = battle.export_checkpoint()
    battle.restore_checkpoint(record)
    check(battle.state.revision > revision and battle.phase == "READY","restore advances version and never resolves refill")
    # Real held portrait -> destination -> held target; conversions never refill.
    var portrait := battle.view.get_node("Party/Hero") as Control
    var portrait_point := portrait.get_global_rect().get_center()
    await touch(portrait_point,true)
    await touch(portrait_point,false)
    check(battle.selected_skill == "hero","hero portrait selects target mode")
    var destination := battle.view.get_node("Bars/Destinations/Blue") as Control
    await touch(destination.get_global_rect().get_center(),true)
    await touch(destination.get_global_rect().get_center(),false)
    var target_id := -1
    for tile in battle.snapshot.pieces:
        if tile.match_type in ["red","yellow"] and tile.bomb_tier == 0: target_id = tile.id; break
    var expected := Skills.preview(battle.snapshot,battle.state,"hero",target_id,"blue")
    var before_skill: Dictionary = battle.board.checkpoint()
    var before_actions: int = battle.state.actions_left
    await touch(point(battle,target_id),true)
    check(battle.displayed_plan == expected,"held target shows exact stored SkillPlan")
    await touch(point(battle,target_id),false)
    check(battle.state.team_skill_used and battle.state.energy == record.state.energy-4,"skill spends cost and team permission once")
    check(battle.state.actions_left == before_actions and battle.refill_batch_count == 1,"transform spends no action and never finishes refill")
    check(battle.phase == "CUTIN","hero own transform locks cutin")
    await touch(pos,true)
    await touch(pos,false)
    await wait_ready(battle)
    check(not battle.view.get_node("CutinLayer").visible,"hero hidden after0.7s")
    for old in before_skill.snapshot.pieces:
        var now: Dictionary = battle.board.by_id(int(old.id)).snapshot()
        check(now.x == old.x and now.y == old.y and now.angle == old.angle and now.hull_id == old.hull_id and now.size == old.size,"transform preserves physical pose/hull")
    check(battle.board.rng.state == int(before_skill.rng_state) and battle.board.next_id == before_skill.next_id,"transform does not allocate or draw RNG")
func key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
    for frame in range(3): await process_frame
func portrait_hold(battle: Node, actor: String, inside: bool = true) -> void:
    var control := battle.view.get_node("Party/"+actor.capitalize()) as Control
    var pos := control.get_global_rect().get_center()
    await touch(pos,true)
    await touch(pos if inside else Vector2.ZERO,false)
func fresh(battle: Node, seed_value: int = 73, party: Array = ["hero","bomber","gardener"]) -> void:
    battle.start_battle({"enemy_id":"gate","seed":seed_value,"hp":50,"energy":10,"party":party,"hero_limit":3,"reduced":true})
    await wait_ready(battle)
func extras(battle: Node) -> void:
    await fresh(battle)
    var owner: Dictionary = battle.board.checkpoint()
    await portrait_hold(battle,"bomber",false)
    check(battle.state.energy == 10 and not battle.state.team_skill_used and battle.board.checkpoint() == owner,"bomber outside portrait cancellation is pure")
    var portrait := battle.view.get_node("Party/Bomber") as Control
    await touch(portrait.get_global_rect().get_center(),true)
    check(battle.displayed_plan.actor_id == "bomber" and battle.view.get_node("PreviewLine").text.contains("환불"),"held bomber shows refill/refund condition")
    await touch(portrait.get_global_rect().get_center(),false)
    check(battle.state.bomb_buff.active and battle.state.energy == 4 and battle.state.actions_left == 3,"inside bomber release activates without action")
    var plan := legal(battle)
    await touch(point(battle,plan.seed_id),true)
    await touch(point(battle,plan.seed_id),false)
    await wait_ready(battle)
    var newborn: Array = battle.snapshot.pieces.filter(func(p):return int(p.id)>=int(owner.next_id) and p.match_type=="blue")
    check(not newborn.is_empty(),"seed73 actual refill generated blue witness")
    for tile in newborn:
        check(tile.bomb_tier > 0 and battle.board.by_id(tile.id) != null,"new blue decorated bomb survives original chain")
    check(battle.state.bomb_buff.generated_count == newborn.size(),"actual generated count adopted exactly once")
    await fresh(battle,73,["hero","bomber"])
    await portrait_hold(battle,"hero")
    var red_button := battle.view.get_node("Bars/Destinations/Red") as Control
    await touch(red_button.get_global_rect().get_center(),true)
    await touch(red_button.get_global_rect().get_center(),false)
    check(battle.destination == "red","hero destination remains reachable with recruited companion")
    battle.cancel_input()
    await fresh(battle)
    owner = battle.board.checkpoint()
    await portrait_hold(battle,"gardener")
    var id := -1
    for tile in battle.snapshot.pieces:
        if tile.match_type != "heart": id=tile.id; break
    var expected := Skills.preview(battle.snapshot,battle.state,"gardener",id)
    await touch(point(battle,id),true)
    check(battle.displayed_plan == expected,"gardener hold exact target preview")
    await touch(point(battle,id),false)
    check(battle.state.energy == 6 and battle.state.pending_heal == 0 and battle.state.actions_left == 3,"garden converts without healing/action")
    for target in expected.changes:
        check(battle.board.by_id(target).match_type == "heart","garden actual displayed type changes")
    check(battle.refill_batch_count == 0 and battle.board.rng.state == int(owner.rng_state),"garden no refill/randomness")
    await fresh(battle,991,["hero"])
    plan = legal(battle)
    battle.keyboard_id = int(plan.seed_id)
    await key(KEY_ENTER,true)
    check(battle.displayed_plan == plan,"keyboard press uses same ActionPlan")
    await key(KEY_ESCAPE,true)
    await key(KEY_ENTER,false)
    check(battle.action_count == 0,"keyboard escape cancels authority")
    await key(KEY_ENTER,true)
    await key(KEY_ENTER,false)
    await wait_ready(battle)
    check(battle.action_count == 1 and battle.refill_batch_count == 1,"keyboard release consumes same authority once")
    # Controlled fixture: existing natural poses/hulls, blue type and tier3 only.
    await fresh(battle,41,["hero"])
    var changes := {}
    for tile in battle.snapshot.pieces: changes[tile.id]="blue"
    battle.snapshot = battle.board.apply_types(changes)
    for tile in battle.board.pieces: tile.bomb_tier=3; tile.queue_redraw()
    battle.snapshot = battle.board.apply_types({20:"heart"})
    plan = Combat.preview(battle.snapshot,battle.state,1)
    check(plan.healing_raw == 3,"many overlapping bomb circles count the same heart once")
    check(plan.removed_ids.size() == 42,"controlled existing-bomb union covers42")
    var ended: Array = []
    battle.finished.connect(func(outcome):ended.append(outcome))
    battle.state.actions_left = 1
    battle.state.pending_heal = 0
    battle.state.pending_damage = 0
    battle.state.enemy_hp = 1 # Controlled terminal fixture; rewards still come from the real plan.
    battle.state.revision += 1
    plan = Combat.preview(battle.snapshot,battle.state,1)
    await touch(point(battle,1),true)
    await touch(point(battle,1),false)
    await wait_ready(battle)
    check(battle.phase == "FINISHED" and ended.size() == 1,"terminal third refill emits finished once")
    check(battle.state.hp == 53 and battle.state.enemy_hp == 0,"healing before lethal attack no enemy counter")
    check(battle.refill_batch_count == 1 and battle.board.pieces.size() == 42,"large union exactly one real refill")
    var types: Array = battle.event_log.map(func(e):return e.type)
    check(types.find("healed") < types.find("player_attack") and not types.has("enemy_attack"),"real settlement ordered heal attack terminal")
    var terminal: Dictionary = battle.export_checkpoint()
    battle.restore_checkpoint(terminal)
    battle.board.settled.emit(battle.board.capture())
    check(ended.size() == 1 and battle.state.hp == 53,"terminal restore and duplicate settle never repeat outcome/heal")
    print("CONTROLLER_LOCKS ",JSON.stringify(battle.lock_measurements))

func lifecycle_regressions(battle: Node) -> void:
    for restored in ([false] if OS.get_cmdline_user_args().has("--natural-only") else ([true] if OS.get_cmdline_user_args().has("--restored-only") else [true,false])):
        await fresh(battle,41,["hero"])
        var original: Dictionary = battle.export_checkpoint()
        if restored:
            battle.restore_checkpoint(original)
            for frame in range(60): await physics_frame
        else:
            battle.snapshot = battle.board.apply_types({7:"heart"})
            for frame in range(60): await physics_frame
        var plan := Combat.preview(battle.snapshot,battle.state,7 if restored else 8)
        if plan.is_empty():
            check(false,"lifecycle reproduction has a valid plan")
            continue
        check(plan.removed_ids == ([7,8,13,19,25] if restored else [8,13,19,25]),"durable original legal5/restored and legal4/no-restore repro")
        var before: Dictionary = battle.board.checkpoint()
        await touch(point(battle,plan.seed_id),true)
        # Movement insideBoard must preserve the original displayed plan.
        var other := 42
        await drag(point(battle,other))
        check(battle.displayed_plan == plan,"moving inside retains original plan")
        await touch(point(battle,other),false)
        check(battle.action_count == 1,"release over different inside tile commits original plan")
        if battle.action_count == 0:
            # Continue physical repro independently of inside-release failure.
            await touch(point(battle,plan.seed_id),true)
            await touch(point(battle,plan.seed_id),false)
        var trace: Array = []
        for tick in range(1800):
            if battle.phase in ["READY","FINISHED","ERROR"]:break
            if tick < 8:
                trace.append({"tick":tick,"speed":battle.board.pieces.map(func(p):return p.linear_velocity.length()),"snapshot":battle.board.capture()})
            await physics_frame
        var audit := {"fixture":"restored5" if restored else "natural4_after_type_change","before":before,"plan":plan,"actual_supplied_batch":battle.board.batches.back(),"physics_trace":battle.board.physics_trace,"trace":trace,"after":battle.board.checkpoint(),"phase":battle.phase,"elapsed":battle.board.elapsed,"locks":battle.lock_measurements}
        var output := OS.get_environment("XDG_DATA_HOME").path_join("lifecycle-"+("restored5" if restored else "natural4")+".json")
        var file := FileAccess.open(output,FileAccess.WRITE)
        file.store_string(JSON.stringify(audit))
        check(battle.phase == "READY","legal lifecycle refill settles: "+output)
        check(battle.board.pieces.all(func(p):return p.continuous_cd==RigidBody2D.CCD_MODE_CAST_SHAPE),"all restored survivors and newborns retain original shape CCD")

func replay_jam(battle: Node) -> void:
    await fresh(battle,41,["hero"])
    battle.restore_checkpoint({"board":JAM_CHECKPOINT,"reduced":true,"state":Combat.fresh({"enemy_id":"gate","hp":50,"energy":10,"party":["hero"]})})
    for frame in range(60): await physics_frame
    var plan := Combat.preview(battle.snapshot,battle.state,8)
    check(plan.removed_ids == [8,13,19,25],"retained exact native legal4 witness")
    var before: Dictionary = battle.board.checkpoint()
    await touch(point(battle,8),true)
    await touch(point(battle,8),false)
    check(JSON.stringify(battle.board.batches.back()) == JSON.stringify(JAM_BATCH),"replay supplies original recorded batch at JSON precision")
    await wait_ready(battle)
    check(battle.phase == "READY" and battle.board.supported(battle.board.capture()),"exact legal4 witness settles with supported in-bound hulls")
    check(battle.board.pieces.size() == 42 and battle.refill_batch_count == 1,"replayed exact4 produces one42-body refill")
    check(before.rng_state != battle.board.checkpoint().rng_state,"only committed batch advances real RNG")

func repeated_restores(battle: Node) -> void:
    await fresh(battle,73,["hero"])
    for cycle in range(3):
        var record: Dictionary = battle.export_checkpoint()
        battle.restore_checkpoint(record)
        for frame in range(30): await physics_frame
        var plan := legal(battle)
        check(not plan.is_empty(),"repeat restore has legal3–8 action")
        if plan.is_empty():return
        var before: Dictionary = battle.board.checkpoint()
        await touch(point(battle,plan.seed_id),true)
        await touch(point(battle,plan.seed_id),false)
        await wait_ready(battle)
        var file := FileAccess.open(OS.get_environment("XDG_DATA_HOME").path_join("repeat-%d.json"%cycle),FileAccess.WRITE)
        file.store_string(JSON.stringify({"cycle":cycle,"before":before,"plan":plan,"batch":battle.board.batches.back(),"after":battle.board.checkpoint(),"phase":battle.phase,"elapsed":battle.board.elapsed}))
        check(battle.phase == "READY" and battle.board.supported(battle.snapshot),"repeat restore→action physical support")
        if battle.phase != "READY":return
        check(battle.board.pieces.all(func(p):return p.continuous_cd==RigidBody2D.CCD_MODE_CAST_SHAPE),"repeat restored CCD always remains2")

func phase_lifecycle(battle: Node) -> void:
    await fresh(battle,41,["hero"])
    var plan := legal(battle)
    var before_version: int = battle.board.version
    var signals: Array = []
    var listener = func(value):signals.append(value)
    battle.board.settled.connect(listener)
    await touch(point(battle,plan.seed_id),true)
    await touch(point(battle,plan.seed_id),false)
    check(battle.board.pieces.size() == 42-plan.removed_ids.size(),"immutable batch waits for genuine survivor collapse")
    check(battle.board.get("refill_phase") == "collapse","removal enters locked collapse phase")
    var last_elapsed := -1.0
    var monotonic_clock := true
    var one_version := true
    var phases: Array = []
    var previous := ""
    for frame in range(1800):
        var current := str(battle.board.get("refill_phase"))
        if current != previous:
            phases.append({"phase":current,"elapsed":battle.board.elapsed,"count":battle.board.pieces.size(),"snapshot":battle.board.capture(),"modes":battle.board.pieces.map(func(p):return [p.identity,p.continuous_cd,p.freeze_mode,p.linear_velocity.x,p.linear_velocity.y,p.angular_velocity])})
            previous=current
        monotonic_clock = monotonic_clock and battle.board.elapsed >= last_elapsed
        last_elapsed=battle.board.elapsed
        one_version = one_version and battle.board.version == before_version+1
        if not battle.board.settling:break
        await physics_frame
    check(monotonic_clock and one_version,"collapse/incoming share continuous clock and one boardversion")
    check(phases.any(func(p):return p.phase=="incoming" and p.elapsed>0 and p.count>42-plan.removed_ids.size() and p.count<=42) and phases.any(func(p):return p.phase=="settled" and p.count==42),"admission starts after collapse and reaches one final42-body settlement")
    check(battle.phase == "READY" and signals.size() == 1 and battle.refill_batch_count == 1 and battle.board.pieces.size() == 42 and battle.board._pending_batch.is_empty() and battle.board.supported(battle.board.capture()),"one final42 supported settle and no intermediate READY/refill event")
    var file := FileAccess.open(OS.get_environment("XDG_DATA_HOME").path_join("phase-lifecycle.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"phases":phases,"lock":battle.lock_measurements}))
    battle.board.settled.disconnect(listener)
    # Replacing a collapsing battle must discard its pending old IDs and batch.
    var record: Dictionary = battle.export_checkpoint()
    plan=legal(battle)
    await touch(point(battle,plan.seed_id),true)
    await touch(point(battle,plan.seed_id),false)
    battle.restore_checkpoint(record)
    for frame in range(60):await physics_frame
    check(battle.phase=="READY" and battle.board.pieces.size()==42 and battle.board.rng.state==int(record.board.rng_state) and not battle.state.refill_pending,"restore discards pending batch without delayed spawn or finish")
    plan=legal(battle)
    await touch(point(battle,plan.seed_id),true)
    await touch(point(battle,plan.seed_id),false)
    await fresh(battle,73,["hero"])
    check(battle.board.next_id==43 and battle.action_count==0 and battle.refill_batch_count==0 and battle.board.pieces.size()==42,"new_board clears pending old batch and phase lifecycle")

func final_refund_case(battle: Node) -> void:
    # Controlled final-action context; seed1 independently draws red/yellow/yellow
    # next. No caller changes the actual RNG, generation weights or batch types.
    await fresh(battle,1,["hero","bomber"])
    var edges := Geometry.graph(battle.snapshot)
    var group: Array = [int(battle.snapshot.pieces[0].id)]
    var cursor := 0
    while cursor < group.size() and group.size() < 3:
        for neighbor in edges[group[cursor]]:
            if not group.has(neighbor) and group.size() < 3:group.append(neighbor)
        cursor += 1
    var changes := {}
    for p in battle.snapshot.pieces:changes[p.id]="red" if group.has(p.id) else "heart"
    battle.snapshot=battle.board.apply_types(changes)
    battle.state.actions_left=1
    battle.state.enemy_hp=1
    battle.state.revision+=1
    await portrait_hold(battle,"bomber")
    var plan := Combat.preview(battle.snapshot,battle.state,group[0])
    check(plan.direct_ids.size()==3 and plan.refill_tier==1,"final-action bomber uses actual3-group refill tier")
    await touch(point(battle,group[0]),true)
    await touch(point(battle,group[0]),false)
    await wait_ready(battle)
    check(battle.board.batches.back().all(func(p):return p.match_type!="blue"),"actual final batch independently has zero blue")
    var refunds: Array=battle.event_log.filter(func(e):return e.type=="energy_refunded")
    check(refunds.size()==1 and refunds[0].paid_cost==6 and refunds[0].energy_effective==5,"zero-blue last-refill refunds paid6 exactly once capped")
    check(battle.phase=="FINISHED" and battle.state.energy==10 and battle.state.team_skill_used and battle.state.bomb_buff.refunded and not battle.state.bomb_buff.active,"terminal refund keeps team use and cappedenergy")
    var record: Dictionary=battle.export_checkpoint()
    battle.restore_checkpoint(record)
    battle.board.settled.emit(battle.board.capture())
    check(battle.state.energy==10 and battle.state.team_skill_used,"completed restore never refunds last batch again")

func transient_lifecycle(battle: Node) -> void:
    for transition in ["start","restore"]:
        for transient in ["cutin","compression","blast"]:
            await fresh(battle,41,["hero"])
            battle.reduced=false
            var record: Dictionary=battle.export_checkpoint()
            if transient=="cutin":
                await portrait_hold(battle,"hero")
                var destination_control:=battle.view.get_node("Bars/Destinations/Blue") as Control
                await touch(destination_control.get_global_rect().get_center(),true)
                await touch(destination_control.get_global_rect().get_center(),false)
                await touch(point(battle,1),true)
                await touch(point(battle,1),false)
                check(battle.view.get_node("CutinLayer").active,"real own hero cutin is active before "+transition)
            else:
                battle.snapshot=battle.board.apply_types({1:"blue"})
                battle.board.by_id(1).bomb_tier=1
                battle.board.by_id(1).queue_redraw()
                battle.snapshot=battle.board.capture()
                await touch(point(battle,1),true)
                await touch(point(battle,1),false)
                if transient=="blast":
                    for frame in range(20):await physics_frame
                var effects=battle.view.get_node("BoardViewport").effects
                check(not effects.compression_contours.is_empty() if transient=="compression" else not effects.bursts.is_empty(),"real "+transient+" is active before "+transition)
            if transition=="restore":battle.restore_checkpoint(record)
            else:battle.start_battle({"enemy_id":"hall1","seed":73,"hp":72,"energy":4,"party":["hero"],"hero_limit":3,"reduced":false})
            var cutin=battle.view.get_node("CutinLayer")
            var effects=battle.view.get_node("BoardViewport").effects
            check(not cutin.active and not cutin.visible and not cutin.get_node("Hero").visible,"all old cutin state hidden on "+transition+" from "+transient)
            check(effects.compression_contours.is_empty() and effects.compression_time<0 and effects.bursts.is_empty(),"all old board effect state cleared on "+transition+" from "+transient)
            await wait_ready(battle)
            check(battle.phase=="READY" and not battle.state.refill_pending,"old callbacks do not finish/refill new state")

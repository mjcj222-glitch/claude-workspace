extends SceneTree
const Rules = preload("res://scripts/combat_rules.gd")
const Geometry = preload("res://scripts/piece_geometry.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var battle: Node
var checks := 0
var failures := 0
var max_overlap_area := 0.0
var max_settle := 0.0
var settles := 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func wait_ready() -> bool:
    for tick in range(1800):
        await physics_frame
        if battle.phase in ["READY","ENDED"]:
            inspect_board()
            return true
        if battle.phase=="ERROR":
            check(false,"settlement timed out")
            return false
    check(false,"waiting timeout")
    return false
func inspect_board() -> void:
    settles += 1
    max_settle = maxf(max_settle,battle.board.last_settle_seconds)
    check(battle.board.pieces.size()==42,"42 pieces after refill")
    check(battle.board.supported(battle.snapshot),"every stable piece is connected to floor support")
    for p in battle.board.pieces:
        check(p.polygon==p.collider.polygon,"visual and collision polygon are identical")
        check(p.global_transform.get_scale().is_equal_approx(Vector2.ONE),"no rigid-body parent scaling")
        check(p.contains(p.global_position),"center is touchable")
    var polygons: Array = []
    for p in battle.board.pieces: polygons.append(Geometry.transformed(p.polygon,p.position,p.rotation))
    for i in range(polygons.size()):
        for j in range(i):
            if battle.board.pieces[i].position.distance_to(battle.board.pieces[j].position)>112: continue
            for overlap in Geometry2D.intersect_polygons(polygons[i],polygons[j]):
                max_overlap_area = maxf(max_overlap_area,Geometry.area(overlap))
    check(max_overlap_area<32.0,"no deep polygon overlap; engine contact slop is separately measured")
func run() -> void:
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    check(battle.phase=="SETTLING" and battle.skills[0].disabled,"falling controls are disabled")
    check(battle.skills[0].text.contains("낙하 중"),"falling label is truthful")
    if not await wait_ready(): quit(1);return
    var saved := {"version":1,"engine":"4.6.3","snapshot":battle.snapshot,"state":battle.state,"next_id":battle.board.next_id,"rng_state":str(battle.board.rng.state),"seed":battle.seed_value,"reduced":false}
    var decoded := SaveStore.decode(JSON.stringify(saved))
    check(not decoded.is_empty(),"valid native snapshot round-trip")
    var malformed: Dictionary = saved.duplicate(true)
    malformed.state.hp = -1
    check(SaveStore.decode(JSON.stringify(malformed)).is_empty(),"negative HP rejected")
    malformed = saved.duplicate(true)
    malformed.snapshot[1].id = malformed.snapshot[0].id
    check(SaveStore.decode(JSON.stringify(malformed)).is_empty(),"duplicate body IDs rejected")
    malformed = saved.duplicate(true)
    malformed.erase("rng_state")
    check(SaveStore.decode(JSON.stringify(malformed)).is_empty(),"missing RNG rejected safely")
    malformed = saved.duplicate(true)
    malformed.snapshot[1].x = malformed.snapshot[0].x
    malformed.snapshot[1].y = malformed.snapshot[0].y
    check(SaveStore.decode(JSON.stringify(malformed)).is_empty(),"overlapping corrupted snapshot rejected")
    var poses: Array = battle.board.capture()
    for tick in range(70): await physics_frame
    check(battle.board.capture()==poses,"stable displayed positions stay fixed for selection")
    var point: Vector2 = battle.board.pieces[0].global_position
    battle.pointer_down(point,0)
    battle.pointer_down(battle.board.pieces[1].global_position,1)
    check(battle.press_pointer==0,"second pointer cannot replace active preview")
    battle.pointer_up(point,1)
    check(battle.phase=="READY" and battle.action_log.is_empty(),"wrong pointer release cannot commit")
    var cancel := InputEventScreenTouch.new()
    cancel.canceled = true
    cancel.index = 0
    battle._unhandled_input(cancel)
    check(battle.press_id==-1 and battle.preview_plan.is_empty(),"canceled touch clears preview")
    battle.pointer_down(point,0)
    battle.pointer_up(point+Vector2(30,0),0)
    check(battle.action_log.is_empty(),"drag release does not commit")
    var taps: int = battle.state.taps
    for skill in range(3):
        if Rules.can_skill(battle.snapshot,battle.state,skill):
            var ids: Array = battle.snapshot.map(func(t):return int(t.id))
            battle.use_skill(skill)
            check(battle.state.taps==taps,"skill does not consume a tap")
            if not await wait_ready(): quit(1);return
            check(battle.snapshot.map(func(t):return int(t.id))==ids,"skill preserves all body IDs")
    check(battle.state.ready==[4,4,4],"all three skills can be used before first tap")
    var chosen: int = battle.snapshot[0].id
    var predicted: Dictionary = Rules.preview(battle.snapshot,battle.edges,chosen,battle.state)
    var prior_ids: Array = battle.snapshot.map(func(t):return int(t.id))
    battle.show_preview(chosen)
    check(battle.preview_plan.removed==predicted.removed,"shown IDs equal snapshot prediction")
    var old_actions: int = battle.action_log.size()
    battle.commit(chosen)
    battle.commit(chosen)
    battle.use_skill(0)
    check(battle.skills[0].disabled,"resolving skill control is disabled")
    if not await wait_ready(): quit(1);return
    check(battle.action_log.size()==old_actions+1,"duplicate action is rejected")
    var now_ids: Array = battle.snapshot.map(func(t):return int(t.id))
    var removed: Array = prior_ids.filter(func(i):return not now_ids.has(i))
    removed.sort()
    var expected: Array = predicted.removed.duplicate()
    expected.sort()
    check(removed==expected,"actual absent original IDs exactly match preview")
    for seed_value in [41,73,991]:
        battle.start_new(seed_value)
        if not await wait_ready(): quit(1);return
        for action in range(4):
            var candidate: int = battle.snapshot[action].id
            battle.commit(candidate)
            if not await wait_ready(): quit(1);return
    print(JSON.stringify({"suite":"native physics, controls and save","checks":checks,"failures":failures,"settled_boards":settles,"max_overlap_area":max_overlap_area,"max_settle_seconds":max_settle,"physics_determinism_claimed":false}))
    quit(0 if failures==0 else 1)

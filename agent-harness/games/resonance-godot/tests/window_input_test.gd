extends SceneTree
const Rules = preload("res://scripts/combat_rules.gd")
const NativeInput = preload("res://tools/native_input.gd")
var battle: Node
var failures := 0
var checks := 0
var received: Array = []

class Observer extends Node:
    var events: Array
    func _input(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
            events.append(event.position)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func wait_ready() -> bool:
    for tick in range(1800):
        await physics_frame
        if battle.phase in ["READY", "ENDED"]: return true
        if battle.phase == "ERROR": return false
    return false
func touch(point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.pressed = pressed
    event.position = NativeInput.window_point(root,point)
    Input.parse_input_event(event)
func run() -> void:
    var observer := Observer.new()
    observer.events = received
    root.add_child(observer)
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    if not await wait_ready(): quit(1); return
    var id_value: int = battle.snapshot[0].id
    var point: Vector2 = battle.board.by_id(id_value).global_position
    var expected: Array = Rules.preview(battle.snapshot,battle.edges,id_value,battle.state).removed.duplicate()
    var before: Array = battle.snapshot.map(func(p): return int(p.id))
    touch(point,true)
    # Buffered events are delivered after the process_frame signal.
    for frame in range(4): await process_frame
    check(not received.is_empty() and received.back().distance_to(point)<0.1,"screen input maps to the visible piece")
    check(battle.press_id==id_value,"touch selects the intended ID")
    check(battle.preview_plan.get("removed",[])==expected,"preview contains the expected IDs")
    print(JSON.stringify({"window":root.size,"viewport":root.get_visible_rect(),"final_transform":root.get_final_transform(),"logical_point":point,"received":received}))
    touch(point,false)
    if not await wait_ready(): check(false,"refill settles")
    var after: Array = battle.snapshot.map(func(p): return int(p.id))
    var absent: Array = before.filter(func(id): return not after.has(id))
    absent.sort()
    expected.sort()
    check(absent==expected,"actual absent IDs equal the preview")
    check(battle.action_log.size()==1,"one input produces one committed action")
    check(battle.board.pieces.size()==42 and battle.board.supported(battle.snapshot),"42 supported pieces after input")
    print(JSON.stringify({"suite":"window input","window":root.size,"checks":checks,"failures":failures,"actions":battle.action_log.size()}))
    quit(0 if failures==0 else 1)

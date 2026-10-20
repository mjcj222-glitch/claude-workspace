extends SceneTree
const Rules = preload("res://scripts/combat_rules.gd")
var battle: Node
func _initialize() -> void: call_deferred("run")
func pause_frames(count: int) -> void:
    for i in range(count): await process_frame
func wait_ready() -> bool:
    for i in range(1000):
        await process_frame
        if battle.phase in ["READY","ENDED"]: return true
        if battle.phase=="ERROR": return false
    return false
func click_button(button: Button) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = button.get_global_rect().get_center()
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = button.get_global_rect().get_center()
    event.pressed = false
    Input.parse_input_event(event)
func choose(id_value: int) -> bool:
    var point: Vector2 = battle.board.by_id(id_value).global_position
    var touch := InputEventScreenTouch.new()
    touch.position = point
    touch.index = 0
    touch.pressed = true
    Input.parse_input_event(touch)
    await pause_frames(70)
    touch = InputEventScreenTouch.new()
    touch.position = point
    touch.index = 0
    touch.pressed = false
    Input.parse_input_event(touch)
    return await wait_ready()
func run() -> void:
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    if not await wait_ready(): quit(1);return
    await pause_frames(60)
    await click_button(battle.skills[0])
    if not await wait_ready(): quit(1);return
    await pause_frames(45)
    var chosen := -1
    var count := 0
    for item in battle.snapshot:
        var plan := Rules.preview(battle.snapshot,battle.edges,int(item.id),battle.state)
        if item.color!=3 and plan.initial.size()>count:
            count = plan.initial.size()
            chosen = int(item.id)
    print("showcase first chain "+str(count))
    if not await choose(chosen): quit(1);return
    await pause_frames(45)
    var mega := -1
    for item in battle.snapshot:
        if item.kind=="mega": mega = int(item.id);break
    if mega==-1: print("No naturally earned mega in showcase");quit(1);return
    if not await choose(mega): quit(1);return
    await pause_frames(40)
    await click_button(battle.skills[2])
    if not await wait_ready(): quit(1);return
    var heal := -1
    var healing := -1
    for item in battle.snapshot:
        var plan := Rules.preview(battle.snapshot,battle.edges,int(item.id),battle.state)
        if plan.healing>healing: healing = plan.healing;heal = int(item.id)
    if not await choose(heal): quit(1);return
    await pause_frames(90)
    print(JSON.stringify({"showcase":"actual native rendered inputs, first turn only","actions":battle.action_log,"status":battle.state.status,"count":battle.board.pieces.size(),"turn":battle.state.turn}))
    quit(0)

extends SceneTree
const Rules = preload("res://scripts/combat_rules.gd")
const NativeInput = preload("res://tools/native_input.gd")
const REQUEST := "res://evidence/local-integration/os-request.json"
const ACK := "res://evidence/local-integration/os-ack.json"
var battle: Node
var sequence := 0
var failures := 0
var checks := 0
var results: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func wait_ready() -> bool:
    for frame in range(1800):
        await physics_frame
        if battle.phase in ["READY","ENDED"]: return true
        if battle.phase=="ERROR": return false
    return false
func request(payload: Dictionary) -> void:
    sequence += 1
    payload["sequence"] = sequence
    var file := FileAccess.open(REQUEST,FileAccess.WRITE)
    file.store_string(JSON.stringify(payload))
    file.close()
    var deadline := Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        await process_frame
        if FileAccess.file_exists(ACK):
            var ack = JSON.parse_string(FileAccess.get_file_as_string(ACK))
            if ack is Dictionary and ack.get("sequence",-1)==sequence:
                for frame in range(6): await process_frame
                return
    check(false,"OS input bridge timed out")
func mouse(point: Vector2, pressed: bool) -> void:
    var screen: Vector2 = Vector2(root.position)+NativeInput.window_point(root,point)
    await request({"kind":"mouse","x":roundi(screen.x),"y":roundi(screen.y),"pressed":pressed})
func click(button: Button) -> void:
    var point := button.get_global_rect().get_center()
    await mouse(point,true)
    await mouse(point,false)
func screenshot(name: String) -> void:
    await RenderingServer.frame_post_draw
    await request({"kind":"capture","name":name,"x":root.position.x,"y":root.position.y,"width":root.size.x,"height":root.size.y})
func run() -> void:
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    if not await wait_ready(): quit(1); return
    for size_value in [Vector2i(360,640),Vector2i(390,844),Vector2i(720,1280),Vector2i(1280,900)]:
        root.size = size_value
        root.position = Vector2i(40,40)
        for frame in range(15): await process_frame
        var start_checks := checks
        await click(battle.skills[0])
        if not await wait_ready(): check(false,"skill settles"); break
        print(JSON.stringify({"window":root.size,"skill_counter":battle.skill_counter,"skill_ready":battle.state.ready,"actions":battle.action_log}))
        check(battle.skill_counter>0 and battle.state.ready[0]==4,"OS mouse activates the skill button")
        check(battle.state.taps==3,"skill does not consume a tap")
        var best: Dictionary = {}
        var selected := -1
        for item in battle.snapshot:
            var plan := Rules.preview(battle.snapshot,battle.edges,int(item.id),battle.state)
            if best.is_empty() or plan.initial.size()>best.initial.size():
                best = plan
                selected = int(item.id)
        var point: Vector2 = battle.board.by_id(selected).global_position
        var previous: Array = battle.snapshot.map(func(item): return int(item.id))
        await mouse(point,true)
        check(battle.press_id==selected,"OS mouse selects the visible piece after resize")
        check(battle.preview_plan.get("removed",[])==best.removed,"OS preview IDs match the rules")
        await screenshot("os-"+str(size_value.x)+"x"+str(size_value.y)+"-preview.png")
        await mouse(point,false)
        if not await wait_ready(): check(false,"OS mouse refill settles"); break
        var remaining: Array = battle.snapshot.map(func(item): return int(item.id))
        var absent: Array = previous.filter(func(id): return not remaining.has(id))
        absent.sort()
        var expected: Array = best.removed.duplicate()
        expected.sort()
        check(absent==expected,"OS actual removed IDs match preview")
        check(battle.board.pieces.size()==42 and battle.board.supported(battle.snapshot),"OS refill has 42 supported pieces without escape")
        check(battle.state.taps==2,"OS release commits exactly once")
        await screenshot("os-"+str(size_value.x)+"x"+str(size_value.y)+"-refill.png")
        await click(battle.restart_button)
        if not await wait_ready(): check(false,"restart settles"); break
        check(battle.state.hp==180 and battle.state.taps==3 and battle.action_log.is_empty(),"OS restart restores the battle")
        results.append({"window":[size_value.x,size_value.y],"checks":checks-start_checks,"preview_removed_ids":expected})
    print(JSON.stringify({"suite":"actual X11 mouse and live resize","checks":checks,"failures":failures,"windows":results}))
    quit(0 if failures==0 else 1)

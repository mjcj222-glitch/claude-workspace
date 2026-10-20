extends SceneTree
const Rules = preload("res://scripts/combat_rules.gd")
const NativeInput = preload("res://tools/native_input.gd")
var battle: Node
var label := "final"
func _initialize() -> void:
    call_deferred("run")
func wait_ready() -> bool:
    for i in range(1800):
        await process_frame
        if battle.phase in ["READY","ERROR","ENDED"]: return battle.phase != "ERROR"
    return false
func capture(filename: String) -> void:
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png("res://evidence/"+filename.replace("first",label))
    print("capture "+filename+" "+str(error))
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--label="): label = arg.substr(8)
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    if not await wait_ready():
        print("Initial settle failed")
        quit(1)
        return
    await capture("native-first-board.png")
    var best: Dictionary = {}
    var selected := -1
    for item in battle.snapshot:
        var plan := Rules.preview(battle.snapshot,battle.edges,int(item.id),battle.state)
        if best.is_empty() or plan.initial.size()>best.initial.size():
            best = plan
            selected = int(item.id)
    var piece: Node = battle.board.by_id(selected)
    var touch := InputEventScreenTouch.new()
    touch.position = NativeInput.window_point(root,piece.global_position)
    touch.index = 0
    touch.pressed = true
    Input.parse_input_event(touch)
    for i in range(40): await process_frame
    if battle.press_id != selected or battle.preview_plan.get("removed",[]) != best.removed:
        print("INPUT_PREVIEW_FAILED")
        quit(1)
        return
    await capture("native-first-preview.png")
    touch = InputEventScreenTouch.new()
    touch.position = NativeInput.window_point(root,piece.global_position)
    touch.index = 0
    touch.pressed = false
    Input.parse_input_event(touch)
    for i in range(30): await process_frame
    await capture("native-first-fall.png")
    if not await wait_ready():
        print("Refill failed")
        quit(1)
        return
    await capture("native-first-refill.png")
    if battle.action_log.size() != 1 or battle.board.pieces.size() != 42:
        print("INPUT_COMMIT_FAILED")
        quit(1)
        return
    print(JSON.stringify({"phase":battle.phase,"count":battle.board.pieces.size(),"actions":battle.action_log,"skill_buttons":[battle.skills[0].text,battle.skills[1].text,battle.skills[2].text]}))
    for i in range(30): await process_frame
    quit(0)

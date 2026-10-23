extends SceneTree
## Physical board validation only; uses real View + Board + Selection modules.
const Board = preload("res://scripts/v2/board.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var view: Node
var board: Node
var output := ""
var seed_value := 41
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for tick in range(count): await process_frame
func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    var path := output.path_join(label+".png")
    var error := root.get_texture().get_image().save_png(path)
    var board_error: int = view.get_node("BoardViewport").viewport.get_texture().get_image().save_png(output.path_join(label+"-board.png"))
    var snapshot_file := FileAccess.open(output.path_join(label+"-snapshot.json"),FileAccess.WRITE)
    snapshot_file.store_string(JSON.stringify(board.capture()))
    print(JSON.stringify({"capture":path,"error":error,"board_error":board_error,"frame":Engine.get_process_frames()}))
func run() -> void:
    var args := OS.get_cmdline_user_args()
    output = args[args.find("--output")+1]
    if args.has("--seed"): seed_value=int(args[args.find("--seed")+1])
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(720,1280)
    view = load("res://scenes/v2/battle_view.tscn").instantiate()
    root.add_child(view)
    board=Board.new()
    view.bind_board(board)
    view.show_state(Fixtures.combat(),["hero"])
    board.new_board(seed_value)
    await frames(20)
    await capture("initial-fall")
    for tick in range(900):
        if not board.settling: break
        await process_frame
    if board.last_snapshot.pieces.is_empty():
        push_error("initial settlement failed")
        quit(1)
        return
    await capture("initial-settled")
    var snapshot: Dictionary=board.capture()
    var plan := {}
    for p in snapshot.pieces:
        var candidate := Selection.preview(snapshot,p.id,1)
        if not candidate.is_empty() and (plan.is_empty() or candidate.direct_ids.size()>plan.direct_ids.size()): plan=candidate
    if plan.is_empty():
        push_error("no legal removal")
        quit(1)
        return
    view.show_selection(snapshot,plan)
    await frames(60)
    await capture("connection-preview")
    view.show_selection(snapshot,{})
    var batch: Array=board.make_refill(plan.removed_ids.size())
    board.apply_clear(plan.removed_ids,batch)
    print(JSON.stringify({"legal_plan":plan,"refill_count":batch.size(),"seed":seed_value}))
    await frames(7)
    await capture("removal-neighbor-roll")
    await frames(14)
    await capture("refill-falling")
    for tick in range(900):
        if not board.settling: break
        await process_frame
    await capture("refill-settled")
    print(JSON.stringify({"supported":board.supported(board.capture()),"count":board.capture().pieces.size(),"last_settle_seconds":board.last_settle_seconds}))
    await frames(75)
    quit(0 if board.supported(board.capture()) else 1)

extends SceneTree
## Real-render checkpoint fixtures. Values come from Board and SelectionV2.
const Board = preload("res://scripts/v2/board.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
var view: Node
var board: Node
var fixture := "base"
var output := "res://evidence/v2-local/checkpoint-a"
var captures: Array = []
var failures := 0
var reduced := false
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in range(count): await process_frame
func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    var path := output.path_join(fixture+("-reduced" if reduced else "")+"-"+label+".png")
    var result := root.get_texture().get_image().save_png(path)
    captures.append({"path":path,"error":result,"frame":Engine.get_process_frames(),"hero_visible":view.get_node("CutinLayer/Hero").visible,"hero_position":str(view.get_node("CutinLayer/Hero").position),"reduced":reduced})
    print(JSON.stringify(captures[-1]))
func run() -> void:
    var args := OS.get_cmdline_user_args()
    reduced = args.has("--reduced")
    var index := args.find("--fixture")
    if index >= 0 and index+1 < args.size(): fixture = args[index+1]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    root.size = Vector2i(720,1280)
    view = load("res://scenes/v2/battle_view.tscn").instantiate()
    root.add_child(view)
    board = Board.new()
    view.bind_board(board)
    view.show_state(Fixtures.combat(),["hero"])
    board.new_board(121)
    await frames(12)
    await capture("start-fall")
    await frames(24)
    await capture("falling")
    for i in range(1800):
        if not board.settling: break
        await physics_frame
    if board.settling or board.last_snapshot.pieces.is_empty():
        push_error("fixture board did not settle")
        quit(1)
        return
    if fixture == "bombs":
        view.get_node("Bars").get_child(view.get_node("Bars").get_child_count()-1).text = "렌더링 시험 장면 · 42개 고정 배치 · 물리 시드 보드 아님"
        var tiles: Array = []
        for row in range(7):
            for col in range(6):
                var type: String = "blue" if row < 4 and col < 4 else ["red","yellow","blue","heart"][(row+col)%4]
                var tier: int = col if row < 4 and col < 4 else 0
                tiles.append(Fixtures.tile(row*6+col+1,type,row if row < 4 else col%4,Vector2(54+98*col,51+82*row),tier))
        board.restore({"snapshot":Fixtures.snapshot(tiles,board.version),"next_id":43,"rng_seed":"121","rng_state":"121"})
        await frames(3)
        await capture("tiers")
        var pixels: Image = view.get_node("BoardViewport").viewport.get_texture().get_image()
        var top := pixels.get_pixel(32,39)
        var bottom := pixels.get_pixel(32,63)
        if top.r <= bottom.r + 0.02:
            print("FAIL: glossy upper face must visibly reflect more light than lower face")
            failures += 1
        var tier2 := pixels.get_pixelv(_ink_pixel(board.by_id(3),Vector2(19,0)))
        var tier3 := pixels.get_pixelv(_ink_pixel(board.by_id(4),Vector2(19,0)))
        if not (tier2.r > tier2.b + 0.15):
            print("FAIL: tier 2 has a distinct gold rim")
            failures += 1
        if not (tier3.r > tier3.g + 0.15):
            print("FAIL: tier 3 has a distinct coral rim")
            failures += 1
        for row in range(4):
            var badge := pixels.get_pixelv(_ink_pixel(board.by_id(row*6+2),Vector2(11,16)))
            if not badge.b > badge.r + 0.20:
                print("FAIL: smaller blue wave badge remains readable on hull "+str(row))
                failures += 1
    var snapshot: Dictionary = board.capture()
    var plan: Dictionary = {}
    for piece in snapshot.pieces:
        var candidate := Selection.preview(snapshot,int(piece.id),1)
        if not candidate.is_empty() and candidate.direct_ids.size() > plan.get("direct_ids",[]).size(): plan = candidate
    if fixture == "bombs": plan = Selection.preview(snapshot,2,1)
    view.show_selection(snapshot,plan)
    await frames(3)
    await capture("selection")
    if fixture == "clip":
        # Real circles cross all four viewport edges. The same effects API is
        # used for selection blasts and committed explosions.
        var circles := [{"id":1,"x":8.0,"y":8.0,"radius":Geometry.diameter_unit()*2.2},{"id":2,"x":592.0,"y":592.0,"radius":Geometry.diameter_unit()*2.2}]
        view.get_node("BoardViewport").effects.play_blast(circles)
        await frames(8)
        await capture("explosion-edges")
        await frames(20)
        view.show_selection(snapshot,{})
        var ids: Array = plan.get("removed_ids",[])
        board.apply_clear(ids,board.make_refill(ids.size()))
        await frames(8)
        await capture("refill-start")
        await frames(24)
        await capture("refill-falling")
        for i in range(1800):
            if not board.settling: break
            await physics_frame
        await frames(3)
        await capture("refill-settled")
    if fixture == "cutin":
        view.get_node("CutinLayer").play(reduced)
        await frames(12)
        await capture("hero-active")
        await frames(18)
        await capture("hero-active-late")
        await frames(18)
        await capture("hero-return")
    await frames(15)
    print(JSON.stringify({"fixture":fixture,"piece_count":board.capture().pieces.size(),"board_version":board.version,"captures":captures,"targets":plan.get("removed_ids",[]).size()}))
    print(JSON.stringify({"render_checks_failures":failures}))
    quit(0 if failures == 0 else 1)

func _ink_pixel(piece: Node, point: Vector2) -> Vector2i:
    var canonical := Geometry.Base.polygon(Geometry.HULL_MAP[piece.hull_id],1.0)
    var ink_scale := sqrt(Geometry.area(piece.polygon)/Geometry.area(canonical))
    return Vector2i((piece.position+point*ink_scale).round())

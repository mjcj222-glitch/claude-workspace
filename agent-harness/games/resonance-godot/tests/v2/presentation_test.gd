extends SceneTree
const Board = preload("res://scripts/v2/board.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func run() -> void:
    var view = load("res://scenes/v2/battle_view.tscn").instantiate()
    root.add_child(view)
    await process_frame
    view.show_state(Fixtures.combat(), ["hero"])
    check(view.get_node("Party").get_child_count() == 1, "solo start has exactly one small portrait")
    check(view.get_node("Party").get_child(0).get_child(0).size == Vector2(62,62), "portrait texture obeys its small display bounds")
    check(view.get("hp_bar").size.y <= 8 and view.get("enemy_hp_bar").size.y <= 8, "HP bars stay thin after theme minimums")
    check(view.get_node("EnemyStage").get_child(0).size == Vector2(672,280), "backdrop stays within enemy stage")
    var cutin = view.get_node("CutinLayer")
    check(not cutin.get_node("Hero").visible, "full hero is hidden at rest")
    check(cutin.get_node("Hero").size == Vector2(360,360), "cutin texture stays within its temporary stage")
    var viewport = view.get_node("BoardViewport")
    check(viewport.size.x == viewport.size.y, "displayed board stays square")
    for p in [Vector2(40,550), Vector2(360,870), Vector2(679,1189)]:
        check(viewport.board_to_logical(viewport.logical_to_board(p)).distance_to(p) < 0.1, "logical coordinate round trip")
    check(viewport.contains_logical(Vector2(360,870)), "board center accepts input")
    check(not viewport.contains_logical(Vector2(360,400)), "portrait and bars reject board input")
    var board = Board.new()
    view.bind_board(board)
    check(board.get_parent() is SubViewport, "physics board lives inside real SubViewport")
    check(board.scale == Vector2.ONE, "physical parent keeps unit scale")
    if board.get_parent() is SubViewport:
        check(board.get_parent().size == Vector2i(600,600), "physics and effects use 600 square target")
        check(board.get_parent().world_2d != root.world_2d, "board physics has isolated world")
    var snapshot := Fixtures.snapshot([Fixtures.tile(1,"red",0,Vector2(200,300)),Fixtures.tile(2,"yellow",2,Vector2(280,300))])
    var plan := {"direct_ids":[1],"extra_ids":[2],"removed_ids":[1,2],"blast_circles":[]}
    view.show_selection(snapshot, plan)
    var effects = viewport.get("effects")
    check(effects != null, "effects share the clipped viewport")
    if effects != null:
        check(effects.get_parent() == board.get_parent(), "effects and physical bodies share render clipping")
        check(effects.direct_ids == [1] and effects.extra_ids == [2], "direct and extra membership remain distinct")
        check(effects.direct_color != effects.extra_color, "outline styles distinguish direct and extra")
        check(not effects.direct_contours.is_empty() and not effects.extra_contours.is_empty(), "marks surround real hulls")
    if effects != null:
        var original_direct: Array = effects.direct_ids.duplicate()
        plan.direct_ids.append(999)
        check(effects.direct_ids == original_direct, "caller mutation cannot change the shown membership")
        plan.direct_ids.erase(999)
        effects.show_selection(Fixtures.chain(3), {"direct_ids":[1,2,3]})
        check(effects.direct_contours.size() == 1, "connected pieces receive a single outer group contour")
        view.show_selection(snapshot,plan)
    check(view.get_node("PreviewLine").text.contains("2"), "selection-only preview shows actual target count")
    check(not view.get_node("PreviewLine").text.contains("피해"), "selection-only preview invents no combat outcome")
    var action := plan.duplicate(true)
    action.merge({"direct_damage":6,"blast_damage":1,"healing_effective":3,"energy_effective":1})
    view.show_plan(snapshot, action)
    check(view.get_node("PreviewLine").text.contains("7") and view.get_node("PreviewLine").text.contains("3"), "action preview reads supplied damage and effective healing")
    view.show_selection(snapshot,{})
    if effects != null:
        check(effects.direct_ids.is_empty() and effects.extra_ids.is_empty(), "cancel clears every selection mark")
    cutin.play(false)
    check(cutin.get_node("Hero").visible, "own skill briefly shows full hero")
    await create_timer(0.35).timeout
    check(cutin.get_node("Hero").visible, "cutin remains visible during its 0.7 second window")
    await create_timer(0.40).timeout
    check(not cutin.get_node("Hero").visible and not cutin.visible, "cutin fully disappears after 0.7 seconds")
    cutin.play(true)
    check(cutin.get_node("Hero").visible, "reduced motion supports still cutin")
    await create_timer(0.75).timeout
    check(not cutin.get_node("Hero").visible and not cutin.visible, "reduced cutin also returns to hidden")
    print(JSON.stringify({"suite":"v2 presentation","checks":checks,"failures":failures}))
    view.free()
    quit(0 if failures == 0 else 1)

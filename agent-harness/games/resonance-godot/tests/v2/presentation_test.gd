extends SceneTree
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Config = preload("res://scripts/v2/config.gd")
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
    var stage: Rect2 = view.get_node("EnemyStage").get_global_rect()
    check(stage.encloses(view.get_node("EnemyStage").get_child(0).get_global_rect()), "backdrop is contained by the actual enemy stage")
    check(Config.TYPE_COLORS.red.h < 0.08 and Config.TYPE_COLORS.heart.h > 0.85, "normal red is warm red/orange while hearts remain pink")
    var cutin = view.get_node("CutinLayer")
    check(not cutin.get_node("Hero").visible, "full hero is hidden at rest")
    check(stage.encloses(cutin.get_global_rect()), "cutin backdrop is inside enemy stage")
    check(stage.encloses(cutin.get_node("Hero").get_global_rect()), "entire hero rectangle is inside enemy stage")
    check(not cutin.get_global_rect().intersects(view.get_node("Party").get_global_rect()), "cutin never intersects party controls")
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
        check(effects.direct_contours.size() == 3 and effects.direct_ids == [1,2,3], "whole group remains marked by contained per-hull selection contours")
        view.show_selection(snapshot,plan)
    check(view.get_node("PreviewLine").text.contains("2"), "selection-only preview shows actual target count")
    check(not view.get_node("PreviewLine").text.contains("피해"), "selection-only preview invents no combat outcome")
    var action := plan.duplicate(true)
    action.merge({"direct_damage":6,"blast_damage":1,"healing_effective":3,"energy_effective":1})
    view.show_plan(snapshot, action)
    check(view.get_node("PreviewLine").text.contains("7") and view.get_node("PreviewLine").text.contains("3"), "action preview reads supplied damage and effective healing")
    var solo_snapshot := Fixtures.chain(1,"blue",{1:1})
    var solo_plan := Combat.preview(solo_snapshot,Fixtures.combat(),1)
    view.show_plan(solo_snapshot,solo_plan)
    check(view.get_node("PreviewLine").text == "폭탄 1 + 추가0  ·  피해0+0=0  ·  회복0  ·  기력0", "solo detonation has exact bomb1 label and no direct-color reward")
    var active := Fixtures.combat()
    active.bomb_buff.active = true
    for example in [
        {"n":3,"tier":1,"line":"직접3 + 추가0  ·  피해6+0=6  ·  회복0  ·  기력1 · 다음 파랑 소형"},
        {"n":5,"tier":2,"line":"직접5 + 추가0  ·  피해16+0=16  ·  회복0  ·  기력2 · 다음 파랑 중형"},
        {"n":8,"tier":3,"line":"직접8 + 추가0  ·  피해34+0=34  ·  회복0  ·  기력4 · 다음 파랑 대형"}]:
        var example_snapshot := Fixtures.chain(example.n)
        var actual_plan := Combat.preview(example_snapshot,active,1)
        var original_plan := actual_plan.duplicate(true)
        view.show_plan(example_snapshot,actual_plan)
        check(actual_plan.refill_tier == example.tier and view.get_node("PreviewLine").text == example.line,"active bomber line shows exact supplied refill tier")
        check(actual_plan == original_plan,"view does not mutate authoritative tier plan")
    view.show_plan(Fixtures.chain(8),Combat.preview(Fixtures.chain(8),Fixtures.combat(),1))
    check(not view.get_node("PreviewLine").text.contains("다음 파랑"),"inactive bomber has no future tier promise")
    view.show_selection(snapshot,{})
    if effects != null:
        check(effects.direct_ids.is_empty() and effects.extra_ids.is_empty(), "cancel clears every selection mark")
    cutin.play(false)
    check(cutin.get_node("Hero").visible, "own skill briefly shows full hero")
    await create_timer(0.35).timeout
    check(stage.encloses(cutin.get_node("Hero").get_global_rect()), "moving hero stays inside enemy stage")
    check(cutin.get_node("Hero").visible, "cutin remains visible during its 0.7 second window")
    await create_timer(0.40).timeout
    check(not cutin.get_node("Hero").visible and not cutin.visible, "cutin fully disappears after 0.7 seconds")
    cutin.play(true)
    check(cutin.get_node("Hero").visible, "reduced motion supports still cutin")
    var still_position: Vector2 = cutin.get_node("Hero").position
    var still_modulate: Color = cutin.get_node("Hero").modulate
    await create_timer(0.35).timeout
    check(cutin.get_node("Hero").position == still_position and cutin.get_node("Hero").modulate == still_modulate, "reduced cutin has no translation or fading")
    check(cutin.find_children("*", "GPUParticles2D", true, false).is_empty() and cutin.find_children("*", "CPUParticles2D", true, false).is_empty(), "reduced cutin has no particle emitters")
    check(stage.encloses(cutin.get_node("Hero").get_global_rect()), "still reduced hero stays inside enemy stage")
    await create_timer(0.40).timeout
    check(not cutin.get_node("Hero").visible and not cutin.visible, "reduced cutin also returns to hidden")
    view.show_state(Fixtures.combat(), ["hero","bomber"])
    view.get_node("Party").get_child(1).pressed.emit()
    view.show_plan(snapshot,action)
    check(not cutin.visible and not cutin.get_node("Hero").visible, "companion request and ordinary plan presentation never dispatch hero cutin")
    var pressured := Fixtures.combat("gate",6,40,4)
    check(pressured.intent.kind == "strong" and pressured.intent.pressure == 12,"sixth gate turn fixture has strong attack and pressure")
    view.show_state(pressured,["hero","gardener"])
    var large := Fixtures.chain(12)
    var weakening := Combat.preview(large,pressured,1)
    view.show_plan(large,weakening)
    check(weakening.weaken_intent and view.get_node("PreviewLine").text.contains("약화"),"large group presentation carries weakening promise")
    var applied := Combat.apply_action(pressured,weakening)
    view.show_state(applied.state,["hero","gardener"])
    check(applied.state.intent.kind == "normal" and applied.state.intent.pressure == 12 and view.labels.intent.text.contains("28(+12)"),"weakened intent label uses normal base16 plus retained pressure12")
    check(view.get_node("Party").get_child_count() == 2 and view.get_node("Party/Gardener") != null,"two-member party fixture renders gardener as the second portrait")
    for portrait in view.get_node("Party").get_children():
        check(not stage.intersects(portrait.get_global_rect()),"actual recruited portrait remains below enemy-only upper stage")
    print(JSON.stringify({"suite":"v2 presentation","checks":checks,"failures":failures}))
    view.free()
    quit(0 if failures == 0 else 1)

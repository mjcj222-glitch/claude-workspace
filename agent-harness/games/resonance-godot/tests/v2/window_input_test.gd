extends SceneTree
## Synthetic touch is engine injection. The subclass drives OS mouse through XTest.
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Config = preload("res://scripts/v2/config.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const NativeInput = preload("res://tools/native_input.gd")
var battle: Node
var checks := 0
var failures := 0
var results: Array = []
var capture_dir := ""
var source := "engine-injected synthetic touch/cancel/focus notification; real window resize when graphical"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ",message)
func frames(count: int = 4) -> void:
    for frame in range(count): await process_frame
func wait_ready() -> bool:
    for frame in range(2400):
        if battle.phase == "READY": return true
        if battle.phase == "ERROR": return false
        await process_frame
    return false
func resize_window(size_value: Vector2i) -> void:
    root.size = size_value
    await frames(10)
func press(point: Vector2) -> void:
    NativeInput.touch(root,point,true)
    await frames()
func release(point: Vector2) -> void:
    NativeInput.touch(root,point,false)
    await frames()
func move(point: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = 0
    event.position = NativeInput.window_point(root,point)
    Input.parse_input_event(event)
    await frames()
func cancel() -> void:
    NativeInput.touch(root,Vector2.ZERO,false,0,true)
    await frames()
func focus_out() -> void:
    battle.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    await frames()
func capture(name_value: String) -> void:
    if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
        await frames(1)
        return
    await RenderingServer.frame_post_draw
    var pixels := root.get_texture().get_image()
    check(pixels.get_width() > 100 and pixels.get_height() > 100,"render capture contains graphical viewport pixels")
    print(JSON.stringify({"capture":name_value,"window":[root.size.x,root.size.y],"rendered_content":[pixels.get_width(),pixels.get_height()],"source":"engine viewport render; black letterbox margins excluded"}))
    check(pixels.save_png(capture_dir+"/"+name_value+".png") == OK,"window pixels saved")
func point_for(id: int) -> Vector2:
    return battle.view.get_node("BoardViewport").board_to_logical(battle.board.by_id(id).position)
func fingerprint() -> Dictionary:
    var checkpoint: Dictionary = battle.board.checkpoint()
    return {"state":battle.state.duplicate(true),"actions":battle.action_count,"rng_state":checkpoint.rng_state,"rng_seed":checkpoint.rng_seed,
        "version":battle.board.version,"ids":battle.snapshot.pieces.map(func(p): return int(p.id))}
func best_plan() -> Dictionary:
    var best := {}
    for piece in battle.snapshot.pieces:
        var plan := Combat.preview(battle.snapshot,battle.state,int(piece.id))
        if not plan.is_empty() and (best.is_empty() or plan.removed_ids.size() > best.removed_ids.size()): best = plan
    return best
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args():
        check(false,"test/recording requires explicit --no-save")
        quit(1)
        return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
    for size_value in [Vector2i(360,640),Vector2i(390,844),Vector2i(720,1280),Vector2i(1280,900)]:
        await resize_window(size_value)
        root.position = Vector2i(40,40)
        battle = load("res://scenes/v2/battle.tscn").instantiate()
        root.add_child(battle)
        battle.start_battle({"enemy_id":"hall1","seed":121,"party":["hero"],"hero_limit":3})
        check(await wait_ready(),"physical initial board ready")
        if battle.phase != "READY": break
        await frames(12)
        check(root.size == size_value,"actual window reports requested resolution")
        var start := checks
        var plan := best_plan()
        check(not plan.is_empty(),"legal visible group exists")
        if plan.is_empty(): break
        var point := point_for(int(plan.seed_id))
        var before := fingerprint()
        await press(point)
        check(battle.displayed_plan == plan,"press maps to visible piece/plan at "+str(size_value))
        var same_group := point_for(int(plan.direct_ids.back()))
        await move(same_group)
        check(battle.displayed_plan == plan,"moving within group keeps original displayed membership")
        await move(Vector2(360,500))
        await move(point)
        await release(point)
        check(fingerprint() == before and battle.displayed_plan.is_empty(),"held outside and reentry cancels without cost/RNG/action")
        await press(point)
        await cancel()
        await release(point)
        check(fingerprint() == before,"cancel consumes no resources or owner RNG")
        await press(point)
        await focus_out()
        await release(point)
        check(fingerprint() == before,"focus loss cancels held input")
        await press(point)
        await resize_window(size_value + Vector2i(8,8))
        await release(point)
        check(fingerprint() == before,"live resize while held cancels")
        await resize_window(size_value)
        await frames(10)
        await press(point)
        # Explicit stale-version boundary fixture; not a normal-play win.
        battle.board.version += 1
        var stale_before := fingerprint()
        await release(point)
        check(fingerprint() == stale_before,"stale board version cannot commit")
        battle.snapshot = battle.board.capture()
        plan = best_plan()
        point = point_for(int(plan.seed_id))
        await press(point)
        battle.state.revision += 1
        stale_before = fingerprint()
        await release(point)
        check(fingerprint() == stale_before,"stale combat version cannot commit")
        plan = best_plan()
        point = point_for(int(plan.seed_id))
        var previous: Array = battle.snapshot.pieces.map(func(p): return int(p.id))
        var actions_before: int = battle.action_count
        await press(point)
        var displayed: Dictionary = battle.displayed_plan.duplicate(true)
        check(displayed == plan,"final displayed authoritative plan")
        await capture("preview-"+str(size_value.x)+"x"+str(size_value.y))
        await release(point)
        check(await wait_ready(),"actual physical refill finishes")
        var remaining: Array = battle.snapshot.pieces.map(func(p): return int(p.id))
        var actual: Array = previous.filter(func(id): return not remaining.has(id))
        actual.sort()
        check(actual == displayed.removed_ids,"displayed and actually removed IDs agree")
        check(battle.action_count == actions_before+1 and battle.refill_batch_count == 1,"release commits one action and one refill")
        check(battle.board.pieces.size() == 42 and battle.board.supported(battle.snapshot),"refill leaves 42 supported pieces")
        await capture("refill-"+str(size_value.x)+"x"+str(size_value.y))
        # A real hero skill boundary invalidates an older action plan.
        var stored := best_plan()
        var old_state: Dictionary = battle.state.duplicate(true)
        var old_board: Dictionary = battle.board.checkpoint()
        var skill := {}
        for piece in battle.snapshot.pieces:
            if piece.match_type == "heart" or int(piece.bomb_tier) != 0: continue
            var destination: String = "yellow" if piece.match_type != "yellow" else "red"
            skill = Skills.preview(battle.snapshot,battle.state,"hero",int(piece.id),destination)
            if not skill.is_empty(): break
        check(not skill.is_empty(),"hero available after actual legal action")
        if not skill.is_empty():
            var portrait: Vector2 = battle.view.get_node("Party/Hero").get_global_rect().get_center()
            await press(portrait)
            await release(portrait)
            var destination_point: Vector2 = battle.view.get_node("Bars/Destinations/"+str(skill.destination).capitalize()).get_global_rect().get_center()
            await press(destination_point)
            await release(destination_point)
            var target := point_for(int(skill.seed_id))
            await press(target)
            check(battle.displayed_plan == skill,"actual pointer displays legal skill plan")
            await release(target)
            check(battle.phase == "CUTIN","hero dispatches own cutin")
            await capture("cutin-"+str(size_value.x)+"x"+str(size_value.y))
            check(await wait_ready(),"hero returns after its cutin")
            check(battle.state.energy == old_state.energy-4 and battle.state.actions_left == old_state.actions_left,"skill costs exactly4 and no action")
            check(battle.board.checkpoint().rng_state == old_board.rng_state,"hero boundary consumes no owner RNG")
            var after_skill := fingerprint()
            check(not battle.commit_preview(stored) and fingerprint() == after_skill,"pre-skill action preview cannot replay or charge")
            for piece in old_board.snapshot.pieces:
                var body = battle.board.by_id(int(piece.id))
                check(body.hull_id == piece.hull_id and body.size_factor == piece.size and body.position == Vector2(piece.x,piece.y) and body.rotation == piece.angle,"conversion preserves hull size pose")
            check(not battle.view.get_node("CutinLayer").visible,"hero returns to enemy-only upper stage")
        await feedback_layout(size_value)
        results.append({"window":[size_value.x,size_value.y],"checks":checks-start,"displayed_removed_ids":displayed.removed_ids,"actual_removed_ids":actual,"source":source})
        battle.queue_free()
        await frames()
    print(JSON.stringify({"suite":"v2 window input","source":source,"checks":checks,"failures":failures,"windows":results}))
    quit(0 if failures == 0 else 1)

func feedback_layout(size_value: Vector2i) -> void:
    # Controlled presentation boundary after the existing real action/skill checks.
    # Native/OS input still presses the actual current board and Bomber portrait.
    battle.state=Combat.fresh({"enemy_id":"hall1","hp":60,"energy":10,"party":["hero","bomber"]})
    battle.state.pending_heal=6
    var graph := Geometry.graph(battle.snapshot,Config.MATCH_CONTACT_EPS)
    var group: Array=[int(battle.snapshot.pieces[0].id)]
    var cursor := 0
    while cursor<group.size() and group.size()<3:
        for id in graph[group[cursor]]:
            if group.size()<3 and not group.has(id): group.append(id)
        cursor+=1
    var changes := {}
    for piece in battle.snapshot.pieces: changes[int(piece.id)]="heart" if group.has(int(piece.id)) else "red"
    battle.snapshot=battle.board.apply_types(changes)
    battle._render_state()
    var point := point_for(group[0])
    await press(point)
    check(battle.displayed_plan.get("healing_raw",-1)==9 and battle.displayed_plan.get("healing_effective",-1)==6,"actual input displays raw9/effective6 with pending6")
    var preview: Label=battle.view.get_node("PreviewLine")
    var metrics := preview.get_theme_font("font").get_multiline_string_size(preview.text,HORIZONTAL_ALIGNMENT_LEFT,-1,preview.get_theme_font_size("font_size"))
    check(preview.text.contains("누적+9") and preview.text.contains("실효+6") and metrics.x<=preview.size.x and metrics.y<=preview.size.y,"healing distinction fits native result region")
    await capture("healing-pending-"+str(size_value.x)+"x"+str(size_value.y))
    await cancel()
    await release(point)
    var portrait: Vector2=battle.view.get_node("Party/Bomber").get_global_rect().get_center()
    await press(portrait)
    await release(portrait)
    check(battle.state.bomb_buff.active,"actual OS/synthetic portrait release activates Bomber")
    # Settlement-boundary fixture: real event arithmetic, no claimed physical refill.
    battle.state.actions_left=0
    battle.state.refill_pending=true
    battle.state.energy=5
    battle._pending_refill=true
    battle._pending_epoch=battle._epoch
    battle._pending_board_version=battle.board.version
    battle._generated_bombs=0
    battle.phase="SETTLING"
    battle._on_settled(battle.board.capture())
    check(await wait_ready(),"active refund returns to actual input owner")
    var footer: Label=battle.view.labels.footer
    check(footer.text.contains("환불") and footer.text.contains("+5") and footer.text.contains("지불6"),"actual capped refund remains visible after recovery/render")
    check(footer.get_theme_font("font").get_string_size(footer.text,HORIZONTAL_ALIGNMENT_LEFT,-1,footer.get_theme_font_size("font_size")).x<=footer.size.x,"refund notice fits native footer")
    await capture("refund-active-"+str(size_value.x)+"x"+str(size_value.y))

extends "res://tests/v2/full_expedition_test.gd"
## Real rendered normal run plus explicitly labelled feature fixtures. Never count fixtures as wins.
const FONT = preload("res://assets/NotoSansCJK-Regular.ttc")
var output := ""
var captures: Array = []
var captured := {}
var fixture_records: Array = []
var label: Label
var serial := 0
var fixture_serial := 0
var chosen_route := "risk"
var chosen_recruit := "bomber"
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args():
        check(false,"test/recording requires explicit --no-save")
        quit(1)
        return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
        if arg.begins_with("--route="): chosen_route = arg.trim_prefix("--route=")
        if arg.begins_with("--recruit="): chosen_recruit = arg.trim_prefix("--recruit=")
    if output.is_empty():
        output = "res://evidence/v2-local/final-expedition"
    if FileAccess.file_exists(output+"/capture-index.json"):
        check(false,"capture directory already contains a run; use a fresh --capture-dir")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    label = Label.new()
    label.position = Vector2(40,1245)
    label.add_theme_font_override("font",FONT)
    label.add_theme_font_size_override("font_size",14)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.z_index = 100
    root.add_child(label)
    capture_enabled = true
    var start_wall := Time.get_ticks_usec()
    var start_frame := Engine.get_physics_frames()
    var timing_only := "--timing-only" in OS.get_cmdline_user_args()
    if timing_only:
        await ordinary_timing_probe()
    elif "--fixtures-only" not in OS.get_cmdline_user_args():
        check(chosen_route in ["safe","risk"] and chosen_recruit in ["bomber","gardener","skip"],"recorded route/recruit is legal")
        if failures > 0: quit(1); return
        label.text = "NORMAL · seed41 · %s/%s · live controller + physical refill" % [chosen_route,chosen_recruit]
        var trace := await play(41,chosen_route,chosen_recruit)
        print("RECORDED_NORMAL_TRACE ",JSON.stringify(trace))
        write_json(output+"/recorded-normal-trace.json",trace)
        check(trace.stage == "completed" and trace.battles_won == 3,"recorded normal expedition wins")
        if failures > 0:
            print("STOP FIRST RECORDED NORMAL FAILURE; no feature-fixture substitution")
            quit(1)
            return
    if not timing_only and "--normal-only" not in OS.get_cmdline_user_args():
        await feature_fixtures()
    var timing := {"wall_seconds":float(Time.get_ticks_usec()-start_wall)/1000000.0,
        "simulation_seconds":float(Engine.get_physics_frames()-start_frame)/Engine.physics_ticks_per_second,
        "process_frames":Engine.get_process_frames(),"nominal_movie_seconds_at60":float(Engine.get_process_frames())/60.0}
    write_json(output+"/capture-index.json",{"source":"Godot graphical viewport; normal gameplay and labelled controlled fixtures", "captures":captures,"fixtures":fixture_records,"timing":timing})
    print(JSON.stringify({"suite":"v2 recorded expedition","checks":checks,"failures":failures,"timing":timing}))
    quit(0 if failures == 0 else 1)

func capture_frame(name_value: String, owner: Node = null, plan: Dictionary = {}) -> void:
    await RenderingServer.frame_post_draw
    var path := output+"/"+name_value+".png"
    check(root.get_texture().get_image().save_png(path) == OK,"capture writes decoded pixels")
    var item := {"file":name_value+".png","process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"label":label.text}
    if is_instance_valid(owner):
        item["phase"] = owner.phase
        item["state"] = owner.state.duplicate(true)
        item["plan"] = plan.duplicate(true)
        item["snapshot"] = owner.board.capture()
    captures.append(item)

func observe(phase_name: String, owner: Node, plan: Dictionary) -> void:
    if not is_instance_valid(owner):
        if phase_name != "ready":
            await capture_frame("normal-"+phase_name+"-"+str(serial))
            serial += 1
        return
    var key: String = str(owner.state.enemy_id)+"-"+phase_name
    if phase_name == "ready" and not captured.has(key):
        captured[key] = true
        await capture_frame("normal-"+key,owner,plan)
    elif phase_name == "cutin":
        for frame in range(10): await process_frame
        await capture_frame("normal-cutin-"+str(serial),owner,plan)
        serial += 1
    elif phase_name == "preview" and (not plan.get("fired_bomb_ids",[]).is_empty() or plan.get("mode","") == "heart" or not captured.has(key)):
        captured[key] = true
        await capture_frame("normal-preview-"+str(serial),owner,plan)
        serial += 1
    elif phase_name == "settled" and not captured.has(key):
        captured[key] = true
        await capture_frame("normal-"+key,owner,plan)
    await process_frame

func fixture_ready(owner: Node) -> bool:
    for frame in range(6000):
        if owner.phase in ["READY","FINISHED"]: return true
        if owner.phase == "ERROR":
            print("STOP FIRST RECORDED PHYSICAL ERROR")
            quit(1)
            return false
        await process_frame
    return false

func fresh_fixture(seed_value: int = 121) -> Node:
    var owner = load("res://scenes/v2/battle.tscn").instantiate()
    root.add_child(owner)
    owner.start_battle({"enemy_id":"gate","seed":seed_value,"hp":40,"energy":10,"party":["hero","bomber","gardener"],"hero_limit":5})
    for frame in range(12): await process_frame
    await capture_frame("fixture-entry-"+str(seed_value)+"-"+str(fixture_serial),owner)
    fixture_serial += 1
    check(await fixture_ready(owner),"fixture initial physical board ready")
    return owner

func fixture_action(owner: Node, plan: Dictionary, name_value: String) -> void:
    var previous: Array = owner.snapshot.pieces.map(func(p): return int(p.id))
    var point: Vector2 = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(int(plan.seed_id)).position)
    owner._press(point,17)
    check(owner.displayed_plan == plan,"fixture uses actual displayed plan")
    await capture_frame(name_value+"-preview",owner,owner.displayed_plan)
    var shown: Dictionary = owner.displayed_plan.duplicate(true)
    owner._release(point,17)
    for frame in range(14): await process_frame
    await capture_frame(name_value+"-refill-start",owner,shown)
    check(await fixture_ready(owner),"fixture real physical refill completes")
    var after: Array = owner.snapshot.pieces.map(func(p): return int(p.id))
    var actual: Array = previous.filter(func(id): return not after.has(id))
    actual.sort()
    check(actual == shown.removed_ids,"fixture displayed and removed IDs agree")
    fixture_records.append({"name":name_value,"controlled":true,"displayed_plan":shown,"actual_removed_ids":actual,"state":owner.state.duplicate(true),"events":owner.event_log.duplicate(true),"locks":owner.lock_measurements.duplicate(true)})
    await capture_frame(name_value+"-settled",owner,shown)

func feature_fixtures() -> void:
    label.text = "CONTROLLED PARTY FIXTURE · seed121 poses · actual gardener skill / heart preview"
    var owner = await fresh_fixture()
    var gardener := {}
    for piece in owner.snapshot.pieces:
        gardener = Skills.preview(owner.snapshot,owner.state,"gardener",int(piece.id))
        if not gardener.is_empty(): break
    var before_skill: Dictionary = owner.state.duplicate(true)
    var rng_before: String = owner.board.checkpoint().rng_state
    await input_skill(owner,gardener)
    check(owner.displayed_plan == gardener,"actual gardener target displays legal changes")
    await capture_frame("fixture-gardener-preview",owner,gardener)
    var target: Vector2 = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(int(gardener.seed_id)).position)
    owner._release(target,17)
    check(await fixture_ready(owner),"gardener returns without hero cutin")
    check(owner.state.energy == before_skill.energy-4 and owner.state.actions_left == before_skill.actions_left and owner.board.checkpoint().rng_state == rng_before,"actual gardener pays4 without action/RNG consumption")
    check(not owner.view.get_node("CutinLayer").visible,"gardener does not display hero full body")
    var hulls := {}
    for id in gardener.changes:
        var body = owner.board.by_id(int(id))
        hulls[body.hull_id] = true
        check(body.match_type == "heart","actual gardener converted target to heart")
    check(hulls.size() >= 2,"same converted heart type is visible on different physical hulls")
    await capture_frame("fixture-gardener-converted",owner,gardener)
    var heart := Combat.preview(owner.snapshot,owner.state,int(gardener.seed_id))
    check(not heart.is_empty() and heart.mode == "heart" and heart.direct_damage == 0 and heart.energy_raw == 0 and heart.healing_effective > 0,"actual converted heart group independently previews healing without damage/energy")
    owner._press(target,17)
    check(owner.displayed_plan == heart,"actual pointer displays independent heart group")
    await capture_frame("fixture-independent-hearts",owner,heart)
    owner.cancel_input()
    fixture_records.append({"name":"fixture-gardener-and-heart","controlled":true,"skill_plan":gardener,"heart_plan":heart,"before":before_skill,"after":owner.state.duplicate(true)})
    owner.queue_free()
    await process_frame

    label.text = "CONTROLLED VISUAL FIXTURE · real seed121 poses · solo bomb chain / three radii"
    owner = await fresh_fixture()
    var original: Dictionary = owner.board.checkpoint()
    var center_id := -1
    var center_distance := INF
    for piece in owner.snapshot.pieces:
        var distance := Vector2(piece.x,piece.y).distance_squared_to(Vector2(300,300))
        if distance < center_distance:
            center_distance = distance
            center_id = int(piece.id)
    for tier in [1,2,3]:
        label.text = "CONTROLLED VISUAL FIXTURE · seed121 poses · bomb radius tier%d" % tier
        var one := original.duplicate(true)
        for piece in one.snapshot.pieces:
            piece.match_type = "blue" if int(piece.id) == center_id else "yellow"
            piece.bomb_tier = tier if int(piece.id) == center_id else 0
        owner.board.restore(one)
        owner.snapshot = owner.board.capture()
        var single := Combat.preview(owner.snapshot,owner.state,center_id)
        var point: Vector2 = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(center_id).position)
        owner._press(point,17)
        check(owner.displayed_plan == single and single.fired_bomb_ids == [center_id] and single.blast_circles.size() == 1,"single actual bomb preview supplies one radius")
        check(is_equal_approx(float(single.blast_circles[0].radius),Geometry.diameter_unit()*float(Config.BOMB_RADIUS_MULTIPLIERS[tier])),"displayed tier radius uses configured fixed D multiplier")
        await capture_frame("fixture-radius-tier"+str(tier),owner,single)
        owner.cancel_input()
    owner.board.restore(original)
    owner.snapshot = owner.board.capture()
    label.text = "CONTROLLED VISUAL FIXTURE · real seed121 poses · solo bomb chain / three radii"
    var graph := Geometry.graph(owner.snapshot,Config.MATCH_CONTACT_EPS)
    var d := Geometry.diameter_unit()
    var bombs: Array = []
    for a in owner.snapshot.pieces:
        for b in owner.snapshot.pieces:
            if int(a.id) == int(b.id) or graph[int(a.id)].has(int(b.id)): continue
            var ab := Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y))
            if ab > d*2.2: continue
            for c in owner.snapshot.pieces:
                if c.id in [a.id,b.id] or graph[int(a.id)].has(int(c.id)) or graph[int(b.id)].has(int(c.id)): continue
                if Vector2(a.x,a.y).distance_to(Vector2(c.x,c.y)) > d*2.2 and Vector2(b.x,b.y).distance_to(Vector2(c.x,c.y)) <= d*1.6:
                    bombs = [int(a.id),int(b.id),int(c.id)]
                    break
            if not bombs.is_empty(): break
        if not bombs.is_empty(): break
    check(bombs.size() == 3,"actual physical poses admit noncontact chained bombs")
    if bombs.size() == 3:
        var saved: Dictionary = owner.board.checkpoint()
        for piece in saved.snapshot.pieces:
            var index := bombs.find(int(piece.id))
            piece.match_type = "blue" if index >= 0 else "yellow"
            piece.bomb_tier = 3-index if index >= 0 else 0
        owner.board.restore(saved)
        owner.snapshot = owner.board.capture()
        var plan := Combat.preview(owner.snapshot,owner.state,bombs[0])
        check(plan.mode == "solo_bomb" and plan.fired_bomb_ids.size() == 3 and plan.direct_color_count == 0,"solo explosion chains all three existing bombs")
        await fixture_action(owner,plan,"fixture-three-radii-chain")
    owner.queue_free()
    await process_frame

    label.text = "CONTROLLED VISUAL FIXTURE · seed121 · turn6 strong→normal keeps pressure12"
    owner = await fresh_fixture()
    var changes := {}
    for piece in owner.snapshot.pieces: changes[int(piece.id)] = "red"
    owner.snapshot = owner.board.apply_types(changes)
    owner.state.turn = 6
    owner.state.intent = Combat.intent("gate",6)
    owner.state.revision += 1
    owner._render_state()
    var weakening := Combat.preview(owner.snapshot,owner.state,int(owner.snapshot.pieces[0].id))
    check(weakening.weaken_intent,"controlled42 group weakens actual displayed strong intent")
    await fixture_action(owner,weakening,"fixture-pressure-weakening")
    check(owner.state.intent.kind == "normal" and owner.state.intent.pressure == 12,"pressure retained after controller commit")
    owner.queue_free()
    await process_frame

    label.text = "CONTROLLED FINAL-ACTION FIXTURE · seed1 · natural zero-blue final refill / refund"
    owner = await fresh_fixture(1)
    graph = Geometry.graph(owner.snapshot,Config.MATCH_CONTACT_EPS)
    var group: Array = [int(owner.snapshot.pieces[0].id)]
    for id in group:
        for neighbor in graph[id]:
            if group.size() < 3 and not group.has(neighbor): group.append(neighbor)
        if group.size() == 3: break
    changes = {}
    for piece in owner.snapshot.pieces: changes[int(piece.id)] = "red" if group.has(int(piece.id)) else "heart"
    owner.snapshot = owner.board.apply_types(changes)
    owner.state.actions_left = 1
    owner.state.enemy_hp = 1
    owner.state.revision += 1
    owner._render_state()
    var bomber := Skills.preview(owner.snapshot,owner.state,"bomber")
    await input_skill(owner,bomber)
    owner._release(owner.view.get_node("Party/Bomber").get_global_rect().get_center(),17)
    var final_plan := Combat.preview(owner.snapshot,owner.state,group[0])
    await fixture_action(owner,final_plan,"fixture-last-refill-refund")
    var new_pieces: Array = owner.snapshot.pieces.filter(func(p): return int(p.id) >= 43)
    check(new_pieces.size() == 3 and new_pieces.all(func(p): return p.match_type != "blue"),"actual seed1 final physical batch has no blue")
    var refunds: Array = owner.event_log.filter(func(e): return e.type == "energy_refunded")
    check(owner.phase == "FINISHED" and refunds.size() == 1 and refunds[0].paid_cost == 6 and refunds[0].energy_effective == 5 and owner.state.energy == 10,"last actual refill precedes one capped refund and terminal victory")
    owner.queue_free()
    await process_frame

func wait_owner(expedition: Node, owner: Node, monitor: bool = false) -> bool:
    var previous := ""
    for frame in range(6000):
        if not is_instance_valid(owner) or expedition.battle != owner: return true
        if owner.phase == "READY": return true
        if owner.phase == "ERROR":
            print("STOP FIRST RECORDED PHYSICAL ERROR")
            quit(1)
            return false
        var phase_key: String = str(owner.state.enemy_id)+"-"+owner.board.refill_phase
        if owner.board.settling and not captured.has(phase_key) and phase_key != previous:
            captured[phase_key] = true
            previous = phase_key
            await capture_frame("normal-"+phase_key,owner)
        await process_frame
    return false

func ordinary_timing_probe() -> void:
    check(not "--fixed-fps" in OS.get_cmdline_args() and not "--write-movie" in OS.get_cmdline_args(),"ordinary wall timing requires real clock without fixed-fps/movie mode")
    var timings: Array = []
    for seed_value in [41,73,991,20261020,121]:
        label.text = "ORDINARY CONTROLLER TIMING · seed%d · real window / no fixed FPS" % seed_value
        var owner = load("res://scenes/v2/battle.tscn").instantiate()
        root.add_child(owner)
        owner.start_battle({"enemy_id":"gate","seed":seed_value,"party":["hero"],"hero_limit":3})
        check(await fixture_ready(owner),"ordinary timing real initial board settles")
        var plan := {}
        for piece in owner.snapshot.pieces:
            var candidate := Combat.preview(owner.snapshot,owner.state,int(piece.id))
            if not candidate.is_empty() and candidate.removed_ids.size() >= 3 and candidate.removed_ids.size() <= 8 and (plan.is_empty() or candidate.removed_ids.size() > plan.removed_ids.size()): plan = candidate
        check(not plan.is_empty(),"ordinary timing has actual legal3–8 removal")
        if plan.is_empty(): owner.queue_free(); await process_frame; continue
        var previous: Array = owner.snapshot.pieces.map(func(p): return int(p.id))
        var point: Vector2 = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(int(plan.seed_id)).position)
        owner._press(point,17)
        check(owner.displayed_plan == plan,"ordinary actual displayed plan")
        await capture_frame("timing-seed"+str(seed_value)+"-preview",owner,plan)
        var wall_begin := Time.get_ticks_usec()
        var frame_begin := Engine.get_physics_frames()
        owner._release(point,17)
        var samples := 0
        var max_process := 0.0
        var max_physics := 0.0
        var process_sum := 0.0
        for frame in range(6000):
            if owner.phase in ["READY","ERROR"]: break
            await process_frame
            samples += 1
            var process_seconds := Performance.get_monitor(Performance.TIME_PROCESS)
            max_process = maxf(max_process,process_seconds)
            process_sum += process_seconds
            max_physics = maxf(max_physics,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
        var wall := float(Time.get_ticks_usec()-wall_begin)/1000000.0
        var simulation := float(Engine.get_physics_frames()-frame_begin)/Engine.physics_ticks_per_second
        var remaining: Array = owner.snapshot.pieces.map(func(p): return int(p.id))
        var actual: Array = previous.filter(func(id): return not remaining.has(id))
        actual.sort()
        check(owner.phase == "READY" and owner.board.pieces.size() == 42 and owner.board.supported(owner.snapshot),"ordinary real refill reaches supported42 READY")
        check(actual == plan.removed_ids and owner.refill_batch_count == 1,"ordinary actual removal equals preview and one batch")
        var row := {"seed":seed_value,"source":"real graphical Battle controller; normal seeded initial resources; no fixed FPS; one legal3–8 action, not full expedition win", "displayed_plan":plan,"actual_removed_ids":actual,"phase":owner.phase,"wall_seconds":wall,"simulation_seconds":simulation,"lock_measurements":owner.lock_measurements.duplicate(true),"process_samples":samples,"engine_process_seconds_mean":process_sum/maxi(1,samples),"engine_process_seconds_max":max_process,"engine_physics_process_seconds_max":max_physics}
        timings.append(row)
        print("ORDINARY_TIMING ",JSON.stringify(row))
        await capture_frame("timing-seed"+str(seed_value)+"-settled",owner,plan)
        owner.queue_free()
        await process_frame
    write_json(output+"/ordinary-timing.json",{"checks":checks,"failures":failures,"cases":timings})

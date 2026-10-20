extends SceneTree
## Normal-play witnesses: current-board greedy lookahead, real controller, real physics.
## No checkpoint restoration, resource writes, future refill/RNG inspection, or terminal fixtures.
const Config = preload("res://scripts/v2/config.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Expedition = preload("res://scenes/v2/expedition.tscn")
var checks := 0
var failures := 0
var traces: Array = []
var last_terminal := {}
var capture_enabled := false
var trace_dir := ""
var physical_history: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ",message)
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args():
        check(false,"test/recording requires explicit --no-save")
        quit(1)
        return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--trace-dir="): trace_dir = arg.trim_prefix("--trace-dir=")
    for route in ([] if "--defeat-only" in OS.get_cmdline_user_args() else ["safe","risk"]):
        for recruit in ["bomber","gardener","skip"]:
            var trace := await play(41,route,recruit)
            traces.append(trace)
            check(trace.stage == "completed" and trace.battles_won == 3,"three normal victories: "+route+"/"+recruit)
            check(trace.resource_overrides.is_empty(),"normal trace has no resource overrides")
            print("NORMAL_TRACE ",JSON.stringify(trace))
            if not trace_dir.is_empty(): write_json(trace_dir+"/"+route+"-"+recruit+".json",trace)
    var defeat := await play(41,"risk","skip",true)
    traces.append(defeat)
    check(defeat.stage == "lost" and defeat.get("restart_checked",false),"normal defeat and real restart")
    print("DEFEAT_TRACE ",JSON.stringify(defeat))
    if not trace_dir.is_empty(): write_json(trace_dir+"/defeat-restart.json",defeat)
    print(JSON.stringify({"suite":"v2 six normal expeditions and defeat/restart","checks":checks,"failures":failures,"trials":traces.map(func(t): return {"seed":t.seed,"route":t.route,"recruit":t.recruit,"stage":t.stage,"battles_won":t.battles_won})}))
    quit(0 if failures == 0 else 1)

func write_json(path: String, value: Variant) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null: check(false,"trace output opens"); return
    file.store_string(JSON.stringify(value,"  ")+"\n")

func wait_owner(expedition: Node, owner: Node, monitor: bool = false) -> bool:
    var previous := ""
    for frame in range(6000):
        if monitor and is_instance_valid(owner):
            var current: String = owner.phase+"/"+owner.board.refill_phase
            if current != previous:
                physical_history.append({"frame":Engine.get_physics_frames(),"telemetry":physical_failure(owner,{}),"checkpoint":owner.board.checkpoint(),"pending_batch":owner.board._pending_batch.duplicate(true)})
                previous = current
        if not is_instance_valid(owner) or expedition.battle != owner: return true
        if owner.phase == "READY": return true
        if owner.phase == "ERROR": return false
        await process_frame
    return false

func terminal(outcome: Dictionary, owner: Node) -> void:
    last_terminal = {"outcome":outcome.duplicate(true),"state":owner.state.duplicate(true),
        "snapshot":owner.snapshot.duplicate(true),"events":owner.event_log.duplicate(true),
        "locks":owner.lock_measurements.duplicate(true)}

func play(seed_value: int, route: String, recruit: String, weak: bool = false) -> Dictionary:
    var start_usec := Time.get_ticks_usec()
    var start_frame := Engine.get_physics_frames()
    var expedition = Expedition.instantiate()
    expedition.seed = seed_value
    root.add_child(expedition)
    var trace := {"seed":seed_value,"battle_seeds":expedition.run.battle_seeds.duplicate(),"route":route,"recruit":recruit,
        "strategy":"minimum damage; no skills" if weak else "current contact graph; maximize damage + effective healing weighted by HP; hero one-step type lookahead; bomber when available",
        "resource_overrides":[],"steps":[],"results":[],"battles_won":0,"stage":"battle1"}
    var steps := 0
    while expedition.run.stage not in ["completed","lost"] and steps < 150:
        if expedition.run.stage in ["route_choice","recruit_choice"]:
            await observe(expedition.run.stage,null,{})
            var choice: String = route if expedition.run.stage == "route_choice" else recruit
            expedition.choice_panel.get_node("Choices/"+choice.capitalize()).pressed.emit()
            trace.steps.append({"choice":choice,"run":expedition.run.duplicate(true)})
            continue
        var owner = expedition.battle
        if not await wait_owner(expedition,owner):
            trace["error"] = "physical/controller readiness failed: "+owner.phase
            check(false,str(trace.error))
            break
        if expedition.battle != owner: continue
        if not owner.finished.is_connected(terminal.bind(owner)): owner.finished.connect(terminal.bind(owner))
        await observe("ready",owner,{})
        var picked := choose(owner,weak)
        if picked.is_empty():
            check(false,"solver found no legal current action")
            trace["error"] = "no legal current action"
            break
        var before: Dictionary = owner.state.duplicate(true)
        var board_before: Dictionary = owner.snapshot.duplicate(true)
        var immutable_checkpoint: Dictionary = owner.export_checkpoint().duplicate(true)
        physical_history = []
        var plan: Dictionary = picked.plan
        if plan.has("actor_id"):
            await input_skill(owner,plan)
        else:
            var point: Vector2 = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(int(plan.seed_id)).position)
            owner._press(point,17)
        check(owner.displayed_plan == plan,"controller displayed legal solver plan: expected %s actual %s" % [plan,owner.displayed_plan])
        var displayed: Dictionary = owner.displayed_plan.duplicate(true)
        await observe("preview",owner,displayed)
        var release_point: Vector2
        if plan.get("actor_id","") == "bomber": release_point = owner.view.get_node("Party/Bomber").get_global_rect().get_center()
        else: release_point = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(int(plan.seed_id)).position)
        owner._release(release_point,17)
        if owner.phase == "CUTIN": await observe("cutin",owner,displayed)
        await observe("released",owner,displayed)
        if not await wait_owner(expedition,owner,weak):
            check(false,"committed action finishes physical refill/cutin")
            trace["error"] = "post-action physical/controller failure"
            trace["failure_details"] = physical_failure(owner,displayed)
            trace["pre_action_checkpoint"] = immutable_checkpoint
            trace["physical_history"] = physical_history.duplicate(true)
            trace["failed_step_index"] = steps
            trace["run_at_failure"] = expedition.run.duplicate(true)
            break
        var after: Dictionary
        var board_after: Dictionary
        var final: bool = not is_instance_valid(owner) or expedition.battle != owner
        if final:
            after = last_terminal.state.duplicate(true)
            board_after = last_terminal.snapshot.duplicate(true)
        else:
            after = owner.state.duplicate(true)
            board_after = owner.snapshot.duplicate(true)
        var actual: Array = []
        var remaining: Array = board_after.pieces.map(func(p): return int(p.id))
        for piece in board_before.pieces:
            if not remaining.has(int(piece.id)): actual.append(int(piece.id))
        actual.sort()
        if not plan.has("actor_id"):
            check(actual == displayed.removed_ids,"actual removed IDs equal displayed plan")
            check(board_after.pieces.size() == 42,"real refill restores 42")
        else:
            check(actual.is_empty() and after.actions_left == before.actions_left,"skill preserves pieces and action count")
        trace.steps.append({"battle":str(before.enemy_id),"before":before,"displayed_plan":displayed,
            "actual_removed_ids":actual,"after":after,"board_version_after":board_after.version})
        steps += 1
        if final:
            trace.results.append(last_terminal.duplicate(true))
            if after.status == "victory": trace.battles_won += 1
        else:
            await observe("settled",owner,displayed)
    trace.stage = expedition.run.stage
    trace["final_run"] = expedition.run.duplicate(true)
    trace["wall_seconds"] = float(Time.get_ticks_usec()-start_usec)/1000000.0
    trace["simulation_seconds"] = float(Engine.get_physics_frames()-start_frame)/Engine.physics_ticks_per_second
    if weak and trace.stage == "lost":
        expedition.choice_panel.get_node("Choices/Restart").pressed.emit()
        var restarted = expedition.battle
        var ready := await wait_owner(expedition,restarted)
        trace["restart_checked"] = ready and expedition.run.stage == "battle1" and restarted.state.hp == 72 and restarted.state.energy == 4 and restarted.state.party == ["hero"] and restarted.action_count == 0
    await observe("terminal",null,{})
    expedition.queue_free()
    await process_frame
    return trace

func input_skill(owner: Node, plan: Dictionary) -> void:
    var portrait: Vector2 = owner.view.get_node("Party/"+str(plan.actor_id).capitalize()).get_global_rect().get_center()
    owner._press(portrait,17)
    if plan.actor_id == "bomber": return
    owner._release(portrait,17)
    await process_frame
    if plan.actor_id == "hero":
        var destination_button = owner.view.get_node("Bars/Destinations/"+str(plan.destination).capitalize())
        var destination_point: Vector2 = destination_button.get_global_rect().get_center()
        owner._press(destination_point,17)
        owner._release(destination_point,17)
    var point: Vector2 = owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(int(plan.seed_id)).position)
    owner._press(point,17)

func observe(_phase: String, _owner: Node, _plan: Dictionary) -> void:
    await process_frame

func score(plan: Dictionary, state: Dictionary, weak: bool = false) -> float:
    var damage := float(plan.get("direct_damage",0)+plan.get("blast_damage",0))
    if weak: return -damage + float(plan.get("healing_effective",0))*0.01
    var need := 0.25 if int(state.hp) > 55 else (0.9 if int(state.hp) > 30 else 1.8)
    if int(state.pending_damage) >= int(state.enemy_hp): damage *= 0.1
    return damage + float(plan.get("healing_effective",0))*need + float(plan.get("energy_effective",0))*0.3

func action_plans(snapshot: Dictionary, state: Dictionary, edges: Dictionary) -> Array:
    var seen := {}
    var by_id := {}
    var result: Array = []
    for p in snapshot.pieces: by_id[int(p.id)] = p
    for piece in snapshot.pieces:
        var id := int(piece.id)
        if seen.has(id): continue
        var queue: Array = [id]
        seen[id] = true
        for current in queue:
            for other in edges[current]:
                if not seen.has(other) and by_id[other].match_type == piece.match_type:
                    seen[other] = true
                    queue.append(other)
        if queue.size() >= Config.MIN_GROUP or int(piece.bomb_tier) > 0:
            var p := Combat.preview(snapshot,state,id)
            if not p.is_empty(): result.append(p)
        elif piece.match_type == "blue":
            for other in queue:
                if int(by_id[other].bomb_tier) > 0:
                    result.append(Combat.preview(snapshot,state,other))
    return result

func cheap_best(snapshot: Dictionary, state: Dictionary, edges: Dictionary) -> float:
    # Read-only type lookahead on the SAME contact graph, without future refills.
    var by_id := {}
    for p in snapshot.pieces: by_id[int(p.id)] = p
    var seen := {}
    var best := 0.0
    for p in snapshot.pieces:
        var id := int(p.id)
        if seen.has(id): continue
        var queue: Array = [id]
        seen[id] = true
        for current in queue:
            for other in edges[current]:
                if not seen.has(other) and by_id[other].match_type == p.match_type:
                    seen[other] = true
                    queue.append(other)
        var n := queue.size()
        if n < Config.MIN_GROUP: continue
        var damage := 0
        if p.match_type != "heart":
            for reward in Config.GROUP_REWARDS:
                if n >= int(reward.minimum):
                    damage = Config.DIRECT_DAMAGE_PER_PIECE*n+int(reward.damage_bonus)
                    break
        var healing := mini(Config.HEAL_PER_PIECE*n,maxi(0,Config.MAX_HP-int(state.hp)-int(state.pending_heal))) if p.match_type == "heart" else 0
        best = maxf(best,score({"direct_damage":damage,"healing_effective":healing},state))
    return best

func choose(owner: Node, weak: bool = false) -> Dictionary:
    var snapshot: Dictionary = owner.snapshot
    var state: Dictionary = owner.state
    var edges := Geometry.graph(snapshot)
    var candidates := action_plans(snapshot,state,edges)
    var best := {}
    var best_score := -INF
    for plan in candidates:
        var value := score(plan,state,weak)
        if value > best_score:
            best_score = value
            best = plan
    if weak: return {"plan":best} if not best.is_empty() else {}
    if Skills._available(state,"bomber"):
        return {"plan":Skills.preview(snapshot,state,"bomber")}
    for actor in ["hero","gardener"]:
        if not Skills._available(state,actor): continue
        if actor == "gardener" and int(state.hp) > 48: continue
        var skill_seen := {}
        for piece in snapshot.pieces:
            if int(piece.bomb_tier) != 0 or piece.match_type == "heart": continue
            for destination in (["red","yellow","blue"] if actor == "hero" else ["heart"]):
                if destination == piece.match_type: continue
                var skill := Skills.preview(snapshot,state,actor,int(piece.id),destination)
                if skill.is_empty(): continue
                var key := str(skill.changes)
                if skill_seen.has(key): continue
                skill_seen[key] = true
                var changed := snapshot.duplicate(true)
                for p in changed.pieces:
                    if skill.changes.has(int(p.id)): p.match_type = skill.changes[int(p.id)]
                var value := cheap_best(changed,state,edges)-5.0
                if value > best_score:
                    best_score = value
                    best = skill
    return {"plan":best} if not best.is_empty() else {}

func physical_failure(owner: Node, plan: Dictionary) -> Dictionary:
    var bodies: Array = []
    var bounds := Rect2()
    var first := true
    for piece in owner.board.pieces:
        var points := Geometry.transformed(piece.polygon,piece.position,piece.rotation)
        for point in points:
            if first: bounds = Rect2(point,Vector2.ZERO); first = false
            else: bounds = bounds.expand(point)
        bodies.append({"piece":piece.snapshot(),"linear_velocity":[piece.linear_velocity.x,piece.linear_velocity.y],
            "angular_velocity":piece.angular_velocity,"freeze":piece.freeze,"sleeping":piece.sleeping,"ccd":piece.continuous_cd})
    return {"phase":owner.phase,"board_elapsed":owner.board.elapsed,"refill_phase":owner.board.refill_phase,
        "board_version":owner.board.version,"remaining_count":bodies.size(),"top":bounds.position.y,
        "bounds":[bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y],"supported":owner.board.supported(owner.board.capture()),
        "stable_ticks":owner.board.stable_ticks,"preview_line":owner.view.get_node("PreviewLine").text,
        "state":owner.state.duplicate(true),"selected_plan":plan,"bodies":bodies}

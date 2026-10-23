extends SceneTree
## Configured terminal-state fixtures verify transitions, not normal-play wins.
const Config = preload("res://scripts/v2/config.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
var RunV2: GDScript
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: ",message)

func _initialize() -> void:
    call_deferred("_run")

func outcome(run: Dictionary, status: String = "victory", hp: int = 40, energy: int = 2) -> Dictionary:
    var battle := Combat.fresh(RunV2.battle_context(run))
    battle.status = status
    battle.hp = hp if status == "victory" else 0
    battle.energy = energy
    battle.enemy_hp = 0 if status == "victory" else 10
    return battle

func rejected(result: Dictionary, before: Dictionary, message: String) -> void:
    check(not result.ok and result.state == before and result.events.is_empty(),message)

func _run() -> void:
    if not ResourceLoader.exists("res://scripts/v2/run_rules.gd"):
        check(false,"RunV2 progression module exists")
        finish()
        return
    RunV2 = load("res://scripts/v2/run_rules.gd")
    if not RunV2.can_instantiate():
        check(false,"RunV2 script parses")
        finish()
        return
    choice_predecessors()
    if "--predecessor-only" in OS.get_cmdline_user_args():
        finish()
        return
    var fresh: Dictionary = RunV2.fresh(41)
    check(fresh.party == ["hero"] and fresh.hp == 72 and fresh.energy == 4 and fresh.hero_limit == 3,"solo configured start")
    check(fresh.stage == "battle1" and fresh.revision == 1 and fresh.route == "","first stage and revision")
    check(fresh.battle_seeds.size() == 3 and fresh == RunV2.fresh(41),"three reproducible local seeds fixed at creation")
    check(fresh.battle_seeds != RunV2.fresh(42).battle_seeds,"different expedition seeds")
    check(fresh.applied_choices.is_empty() and fresh.completed_battles.is_empty(),"no initial rewards")
    var context: Dictionary = RunV2.battle_context(fresh)
    check(context.enemy_id == "hall1" and context.seed == fresh.battle_seeds[0] and context.party == ["hero"],"first context")
    context.party.append("bomber")
    check(fresh.party == ["hero"],"context owns independent party")
    rejected(RunV2.choose_route(fresh,"safe"),fresh,"early route rejected")
    rejected(RunV2.choose_recruit(fresh,"bomber"),fresh,"early recruit rejected")
    var active := Combat.fresh(RunV2.battle_context(fresh))
    active.hp = 31
    active.energy = 0
    var sync: Dictionary = RunV2.sync_battle(fresh,active)
    check(sync.ok and sync.state.hp == 31 and sync.state.energy == 0,"sync only live HP and energy including zero")
    var expected := fresh.duplicate(true)
    expected.hp = 31
    expected.energy = 0
    expected.revision += 1
    check(sync.state == expected and fresh.hp == 72,"sync gives no progress reward or input mutation")
    rejected(RunV2.complete_battle(fresh,active),fresh,"active is not completed")
    var foreign := active.duplicate(true)
    foreign.enemy_id = "gate"
    rejected(RunV2.sync_battle(fresh,foreign),fresh,"wrong enemy sync")
    rejected(RunV2.complete_battle(fresh,foreign),fresh,"wrong enemy completion")
    for route in ["safe","risk"]:
        for recruit in ["bomber","gardener","skip"]:
            var run := fresh.duplicate(true)
            var first := outcome(run)
            var first_before := run.duplicate(true)
            var result: Dictionary = RunV2.complete_battle(run,first)
            check(result.ok and result.state.stage == "route_choice" and result.state.completed_battles == ["battle1"],route+recruit+" first victory")
            check(run == first_before,"completion leaves source immutable")
            run = result.state
            rejected(RunV2.complete_battle(run,first),run,"duplicate victory no reward")
            rejected(RunV2.sync_battle(run,first),run,"choice stage rejects stale sync")
            rejected(RunV2.choose_route(run,"invalid"),run,"unknown route")
            var route_before := run.duplicate(true)
            result = RunV2.choose_route(run,route)
            check(result.ok and result.state.stage == "battle2" and result.state.route == route,"route adopted")
            run = result.state
            check(run.hp == (58 if route == "safe" else 40),"route exact heal")
            check(run.hero_limit == 3 and run.applied_choices == ["route_choice"],"risk upgrade waits for win")
            check(route_before.hp == 40,"choice input immutable")
            rejected(RunV2.choose_route(run,route),run,"route repeated")
            var reopened_route := run.duplicate(true)
            reopened_route.stage = "route_choice"
            rejected(RunV2.choose_route(reopened_route,route),reopened_route,"reopened recorded route cannot heal again")
            rejected(RunV2.complete_battle(run,first),run,"old first battle cannot finish second")
            context = RunV2.battle_context(run)
            check(context.enemy_id == "hall2_"+route and context.seed == run.battle_seeds[1],"second exact route and seed")
            var next_combat := Combat.fresh(context)
            check(next_combat.turn == 1 and next_combat.actions_left == 3 and next_combat.intent.pressure == 0,"new turn actions and pressure")
            check(not next_combat.team_skill_used and not next_combat.bomb_buff.active and next_combat.pending_damage == 0 and next_combat.pending_heal == 0,"new usage buff and accrual")
            var second := outcome(run)
            result = RunV2.complete_battle(run,second)
            run = result.state
            check(result.ok and run.stage == "recruit_choice" and run.hero_limit == (4 if route == "risk" else 3),"second win grants risk once")
            rejected(RunV2.complete_battle(run,second),run,"duplicate second no upgrade")
            var reopened_battle := run.duplicate(true)
            reopened_battle.stage = "battle2"
            rejected(RunV2.complete_battle(reopened_battle,second),reopened_battle,"recorded battle cannot reward reopened stage")
            rejected(RunV2.choose_recruit(run,"hero"),run,"unknown recruit")
            result = RunV2.choose_recruit(run,recruit)
            run = result.state
            check(result.ok and run.stage == "battle3" and run.applied_choices == ["route_choice","recruit_choice"],"recruit enters boss exactly once")
            check(run.energy == (6 if recruit == "bomber" else 4),"correct recruit minimum energy")
            check(run.party == (["hero"] if recruit == "skip" else ["hero",recruit]),"at most one recruit")
            check(run.hero_limit == ((5 if route == "risk" else 4) if recruit == "skip" else (4 if route == "risk" else 3)),"combined exact hero limit")
            rejected(RunV2.choose_recruit(run,recruit),run,"reopen cannot top up")
            var reopened_recruit := run.duplicate(true)
            reopened_recruit.stage = "recruit_choice"
            reopened_recruit.energy = 0
            rejected(RunV2.choose_recruit(reopened_recruit,recruit),reopened_recruit,"recorded recruit cannot top up reopened stage")
            context = RunV2.battle_context(run)
            check(context.enemy_id == "gate" and context.seed == run.battle_seeds[2] and context.party == run.party and context.hero_limit == run.hero_limit,"boss inherits progression only")
            check(context.hp == 40 and context.energy == run.energy,"persistent resources")
            var third := outcome(run,"victory",9,1)
            result = RunV2.complete_battle(run,third)
            run = result.state
            check(result.ok and run.stage == "completed" and run.hp == 9 and run.energy == 1 and run.completed_battles == ["battle1","battle2","battle3"],"exactly three battle completion")
            check(RunV2.battle_context(run).is_empty(),"no fourth battle")
            rejected(RunV2.complete_battle(run,third),run,"final duplicate rejected")
            rejected(RunV2.choose_recruit(run,"skip"),run,"no postcompletion reward")
    var route_run: Dictionary = RunV2.complete_battle(fresh,outcome(fresh,"victory",70)).state
    check(RunV2.choose_route(route_run,"safe").state.hp == 72,"safe heal capped")
    for route in ["safe","risk"]:
        var recruiting: Dictionary = RunV2.choose_route(route_run,route).state
        recruiting = RunV2.complete_battle(recruiting,outcome(recruiting,"victory",40,8)).state
        for recruit in ["bomber","gardener","skip"]:
            check(RunV2.choose_recruit(recruiting,recruit).state.energy == 8,"topup preserves higher existing energy")
    for stage_index in range(3):
        var losing := fresh.duplicate(true)
        if stage_index > 0:
            losing = RunV2.choose_route(RunV2.complete_battle(losing,outcome(losing)).state,"risk").state
        if stage_index > 1:
            losing = RunV2.choose_recruit(RunV2.complete_battle(losing,outcome(losing)).state,"bomber").state
        var defeat := outcome(losing,"defeat")
        var lost: Dictionary = RunV2.complete_battle(losing,defeat).state
        check(lost.stage == "lost" and lost.hp == 0 and lost.hero_limit == losing.hero_limit,"defeat stops without victory reward")
        check(RunV2.battle_context(lost).is_empty(),"lost has no context")
        rejected(RunV2.complete_battle(lost,defeat),lost,"defeat repeated")
        check(RunV2.fresh(41) == fresh,"restart clears old progression")
    var pending := outcome(fresh)
    pending.refill_pending = true
    rejected(RunV2.complete_battle(fresh,pending),fresh,"unfinished physical refill cannot progress")
    await live_ownership()
    finish()

func choice_predecessors() -> void:
    var fresh: Dictionary = RunV2.fresh(41)
    var route: Dictionary = RunV2.complete_battle(fresh,outcome(fresh,"victory",20,0)).state
    for history in [[],["battle2"],["battle1","battle2","battle3"]]:
        for choice in ["safe","risk"]:
            var fixture := route.duplicate(true)
            fixture.completed_battles = history.duplicate()
            var before := fixture.duplicate(true)
            rejected(RunV2.choose_route(fixture,choice),before,"route rejects missing/wrong latest battle: %s %s" % [history,choice])
            check(fixture == before,"rejected route prerequisite leaves input unchanged")
    var second: Dictionary = RunV2.choose_route(route,"safe").state
    var recruit: Dictionary = RunV2.complete_battle(second,outcome(second,"victory",20,0)).state
    for history in [[],["battle1"],["battle1","battle2","battle3"]]:
        for choice in ["bomber","gardener","skip"]:
            var fixture := recruit.duplicate(true)
            fixture.completed_battles = history.duplicate()
            var before := fixture.duplicate(true)
            rejected(RunV2.choose_recruit(fixture,choice),before,"recruit rejects missing/wrong latest battle: %s %s" % [history,choice])
            check(fixture == before,"rejected recruit prerequisite leaves input unchanged")

func live_ownership() -> void:
    if not ResourceLoader.exists("res://scenes/v2/expedition.tscn"):
        check(false,"live expedition scene exists")
        return
    var scene = load("res://scenes/v2/expedition.tscn")
    var expedition = scene.instantiate()
    expedition.reduced = true
    root.add_child(expedition)
    check(expedition.run.party == ["hero"] and expedition.battle.state.enemy_id == "hall1","live Expedition starts solo actual Battle")
    check(expedition.battle.reduced,"reduced preference reaches Battle")
    await fresh_live_battle(expedition,0)
    var original = expedition.battle
    var old_generation: int = expedition.generation
    # Inject only complete Combat fixtures to isolate ownership and stage wiring.
    var terminal := outcome(expedition.run)
    terminal.turn = 8
    terminal.actions_left = 0
    terminal.team_skill_used = true
    terminal.bomb_buff = {"active":false,"paid_cost":6,"generated_count":3,"refunded":false}
    original.state = terminal.duplicate(true)
    original.phase = "FINISHED"
    original.finished.emit({"status":"victory","hp":40,"energy":2,"enemy_id":"hall1"})
    check(expedition.run.stage == "route_choice" and expedition.battle == null,"summary reads owner's full state then retires Battle")
    var held_route = expedition.choice_panel.get_node("Choices/Safe")
    held_route.pressed.emit()
    check(expedition.run.stage == "battle2" and expedition.battle.state.hp == 58,"live safe choice adopts reward")
    held_route.pressed.emit()
    check(expedition.run.stage == "battle2" and expedition.run.hp == 58,"old choice callback cannot reapply")
    expedition._on_battle_finished({"status":"victory","hp":40,"energy":2,"enemy_id":"hall1"},original,old_generation,"battle1")
    check(expedition.run.stage == "battle2" and expedition.run.completed_battles == ["battle1"],"stale Battle callback cannot advance new owner")
    check(expedition.battle.reduced and expedition.battle.state.party == ["hero"],"next live context preserves preference and party")
    await fresh_live_battle(expedition,1)
    var second = expedition.battle
    var next_terminal := outcome(expedition.run,"victory",33,2)
    second.state = next_terminal
    second.phase = "FINISHED"
    second.finished.emit({"status":"victory","hp":33,"energy":2,"enemy_id":"hall2_safe"})
    check(expedition.run.stage == "recruit_choice","live recruit screen")
    expedition.choice_panel.get_node("Choices/Bomber").pressed.emit()
    check(expedition.run.stage == "battle3" and expedition.battle.state.party == ["hero","bomber"] and expedition.battle.state.energy == 6,"live recruit and boss construction")
    check(expedition.battle.view.get_node("Party").get_child_count() == 2,"only actual party portraits")
    await fresh_live_battle(expedition,2)
    var boss = expedition.battle
    boss.state = outcome(expedition.run,"victory",12,1)
    boss.phase = "FINISHED"
    boss.finished.emit({"status":"victory","hp":12,"energy":1,"enemy_id":"gate"})
    check(expedition.run.stage == "completed" and expedition.battle == null and expedition.choice_panel.visible,"live completed screen without fourth Battle")
    expedition.choice_panel.get_node("Choices/Restart").pressed.emit()
    check(expedition.run.stage == "battle1" and expedition.battle.state.party == ["hero"] and expedition.run.hp == 72,"live restart resets expedition")
    # Summary must not override the authoritative owner state.
    var restarted = expedition.battle
    restarted.finished.emit({"status":"victory","hp":72,"energy":4,"enemy_id":"hall1"})
    check(expedition.run.stage == "battle1","active owner refuses forged terminal summary")
    # A real Battle.finished follows the full physical board settling.
    for frame in range(1800):
        if restarted.phase in ["READY","ERROR"]: break
        await process_frame
    check(restarted.phase == "READY","loss fixture waits for stable restarted board")
    restarted.state = outcome(expedition.run,"defeat")
    restarted.phase = "FINISHED"
    restarted.finished.emit({"status":"defeat","hp":0,"energy":2,"enemy_id":"hall1"})
    check(expedition.run.stage == "lost" and expedition.battle == null,"live loss screen")
    expedition.queue_free()
    await process_frame

func fresh_live_battle(expedition: Node, index: int) -> void:
    var owner = expedition.battle
    for frame in range(1800):
        if owner.phase in ["READY","ERROR"]: break
        await process_frame
    check(owner.phase == "READY","live battle %d settles to READY" % (index+1))
    var checkpoint: Dictionary = owner.export_checkpoint()
    if checkpoint.is_empty():
        check(false,"live fresh battle exports completed checkpoint")
        return
    check(checkpoint.board.snapshot.pieces.size() == 42 and checkpoint.board.next_id == 43,"new live board has fresh42 and IDs")
    check(int(checkpoint.board.rng_seed) == int(expedition.run.battle_seeds[index]),"live board uses preselected expedition seed")
    check(checkpoint.board.snapshot.pieces.all(func(piece): return int(piece.bomb_tier) == 0),"no inherited bombs")
    var state: Dictionary = checkpoint.state
    check(state.turn == 1 and state.actions_left == 3 and state.intent.pressure == 0,"live turn actions pressure reset")
    check(not state.team_skill_used and state.bomb_buff == {"active":false,"paid_cost":0,"generated_count":0,"refunded":false},"live skill use and entire buff reset")
    check(state.pending_damage == 0 and state.pending_heal == 0,"live accrual reset")
    check(state.hp == expedition.run.hp and state.energy == expedition.run.energy and state.party == expedition.run.party and state.hero_limit == expedition.run.hero_limit,"live permanent expedition resources retained")

func finish() -> void:
    print(JSON.stringify({"suite":"v2 Run transitions and live ownership fixtures","checks":checks,"failures":failures}))
    quit(0 if failures == 0 else 1)

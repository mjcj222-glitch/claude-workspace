extends SceneTree
## Explicit isolated fixture slots only; never touches a real save directory.
const Config = preload("res://scripts/v2/config.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const RunV2 = preload("res://scripts/v2/run_rules.gd")
const BattleScene = preload("res://scenes/v2/battle.tscn")
const ExpeditionScene = preload("res://scenes/v2/expedition.tscn")
var Store: GDScript
var checks := 0
var failures := 0
var board_fixture: Dictionary
var slot := ""

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: ",message)

func _initialize() -> void:
    call_deferred("_run")

func wait_ready(owner: Node) -> bool:
    for tick in range(4200):
        if owner.phase in ["READY","FINISHED","ERROR"]: return owner.phase != "ERROR"
        await physics_frame
    return false

func record(run: Dictionary, state: Dictionary) -> Dictionary:
    var board := board_fixture.duplicate(true)
    var index := 0 if state.enemy_id == "hall1" else (2 if state.enemy_id == "gate" else 1)
    board.rng_seed = str(run.battle_seeds[index])
    return {"version":2,"ruleset":"party-puzzle-v2-initial","run":run.duplicate(true),
        "battle":state.duplicate(true),"board":board,"reduced":true}

func roundtrip(value: Dictionary) -> Dictionary:
    return Store.decode(Store.encode(value))

func terminal(run: Dictionary, status: String = "victory") -> Dictionary:
    var state := Combat.fresh(RunV2.battle_context(run))
    state.hp = 40 if status == "victory" else 0
    state.energy = 2
    state.enemy_hp = 0 if status == "victory" else 10
    state.actions_left = 0
    state.status = status
    return state

func _run() -> void:
    if not ResourceLoader.exists("res://scripts/v2/save_store.gd"):
        check(false,"SaveV2 persistence module exists")
        finish()
        return
    Store = load("res://scripts/v2/save_store.gd")
    if not Store.can_instantiate():
        check(false,"SaveV2 parses")
        finish()
        return
    var root_path := OS.get_environment("XDG_DATA_HOME")
    if not root_path.is_absolute_path() or not "/xdg/task8-" in root_path:
        check(false,"test requires explicitly isolated absolute Task8 XDG root")
        finish()
        return
    slot = root_path.path_join("fixture-v2.json")
    var owner := BattleScene.instantiate()
    root.add_child(owner)
    var run := RunV2.fresh(41)
    owner.start_battle(RunV2.battle_context(run))
    check(await wait_ready(owner),"real initial Board settles")
    board_fixture = owner.export_checkpoint().board
    var initial := record(run,owner.state)
    check(not roundtrip(initial).is_empty(),"strict v2 full checkpoint roundtrip")
    check(typeof(roundtrip(initial).run.seed) == TYPE_INT,"JSON integral values normalized")
    var large_seed := initial.duplicate(true)
    large_seed.run = RunV2.fresh(9223372036854775807)
    large_seed.board.rng_seed = str(large_seed.run.battle_seeds[0])
    check(roundtrip(large_seed).run.seed == 9223372036854775807,"signed64 Run seed retained exactly")
    await live_midturn(owner,run)
    malformed(initial)
    choice_boundaries()
    file_transactions(initial)
    await expedition_boundaries(initial)
    await live_refund_and_terminal()
    await live_recruit_boundaries()
    owner.queue_free()
    await process_frame
    finish()

func live_midturn(owner: Node, run: Dictionary) -> void:
    for remaining in [2,1]:
        var plan := next_plan(owner)
        check(not plan.is_empty(),"restored board has next legal action")
        if plan.is_empty(): return
        owner._show_preview(plan,-2)
        check(owner.export_checkpoint().is_empty(),"held preview is not a save boundary")
        check(owner.commit_preview(plan),"actual clear committed")
        check(owner.export_checkpoint().is_empty(),"pending physical refill is not a save boundary")
        check(await wait_ready(owner),"actual clear/refill settles")
        run = RunV2.sync_battle(run,owner.state).state
        var value := {"version":2,"ruleset":"party-puzzle-v2-initial","run":run,
            "battle":owner.state,"board":owner.export_checkpoint().board,"reduced":false}
        var restored := roundtrip(value)
        check(not restored.is_empty() and restored.battle.actions_left == remaining,"midturn actions and accrual survive decode")
        if restored.is_empty(): return
        var old_plan := next_plan(owner)
        var old_board := int(owner.board.version)
        var old_revision := int(owner.state.revision)
        owner.restore_checkpoint({"state":restored.battle,"board":restored.board,"reduced":restored.reduced})
        check(owner.state.revision == old_revision+1 and owner.board.version == old_board+1,"restore increments current and saved versions")
        check(owner.displayed_plan.is_empty() and owner.session._plan.is_empty(),"restore clears held plan")
        check(not owner.commit_preview(old_plan),"pre-restore plan cannot commit")
        owner.state.revision += 20
        owner.board.version += 20
        old_board = owner.board.version
        old_revision = owner.state.revision
        owner.restore_checkpoint({"state":restored.battle,"board":restored.board,"reduced":restored.reduced})
        check(owner.state.revision == old_revision+1 and owner.board.version == old_board+1,"repeat restore never decreases versions")
    var plan := next_plan(owner)
    owner._show_preview(plan,-2)
    check(owner.commit_preview(plan),"restored third real action commits")
    check(await wait_ready(owner),"restored third action settles with real physical bodies")
    check(owner.state.turn == 2 or owner.state.status != "active","restored third action resolves exactly one turn")

func next_plan(owner: Node) -> Dictionary:
    var best := {}
    for piece in owner.snapshot.pieces:
        var plan := Combat.preview(owner.snapshot,owner.state,int(piece.id))
        if not plan.is_empty() and (best.is_empty() or plan.removed_ids.size() < best.removed_ids.size()): best = plan
    return best

func malformed(initial: Dictionary) -> void:
    for raw in ["{", "[]", "null", "{\"version\":1}"]:
        check(Store.decode(raw).is_empty(),"malformed/unknown record refused: "+raw)
    var changes := [
        ["version",3],["ruleset","other"],["reduced",1],
        ["run.stage","battle4"],["run.hp",73],["run.energy",11],["run.revision",1.5],
        ["run.party",["hero","bomber","gardener"]],["run.hero_limit",5],
        ["run.completed_battles",["battle1"]],["run.applied_choices",["route_choice"]],
        ["run.battle_seeds",[1,2,3]],["battle.hp",50],["battle.intent.pressure",99],
        ["battle.intent.total_damage",999],["battle.refill_pending",true],["battle.actions_left",0],
        ["battle.enemy_hp",999],["battle.turn",0],["battle.team_skill_used",1],
        ["battle.bomb_buff.active",true],["board.next_id",1],["board.rng_seed","01"],
        ["board.rng_state","9223372036854775808"],["board.snapshot.pieces.0.hull_id",4],
        ["board.snapshot.pieces.0.match_type","purple"],["board.snapshot.pieces.0.bomb_tier",4],
        ["board.snapshot.pieces.0.id",2],["board.snapshot.pieces.0.size",1.5],
        ["board.snapshot.pieces.0.x",99999],["board.snapshot.pieces.0.y",-200],
        ["run.completed_battles",["battle1","battle1"]],["run.party",["bomber","hero"]],
        ["run.seed","01"],["run.route","safe"],["battle.party",["hero","bomber"]],
        ["battle.bomb_buff.generated_count",-1],["battle.bomb_buff.refunded",true],
        ["battle.pending_damage",999999],["battle.pending_heal",999999],
        ["board.snapshot.pieces.0.id",1.5],["board.snapshot.version",0],
        ["board.rng_state",1],["board.snapshot.pieces.0",{}]]
    for mutation in changes:
        var value := initial.duplicate(true)
        var keys: PackedStringArray = mutation[0].split(".")
        var cursor: Variant = value
        for index in range(keys.size()-1):
            cursor = cursor[int(keys[index])] if cursor is Array else cursor[keys[index]]
        if cursor is Array: cursor[int(keys[-1])] = mutation[1]
        else: cursor[keys[-1]] = mutation[1]
        check(roundtrip(value).is_empty(),"reject "+mutation[0])
    var extra := initial.duplicate(true)
    extra.board.diameter = 99999
    check(roundtrip(extra).is_empty(),"serialized diameter cannot override fixed hull D")
    extra = initial.duplicate(true)
    extra.preview = {"seed_id":1}
    check(roundtrip(extra).is_empty(),"ephemeral preview is outside save schema")
    var overlap := initial.duplicate(true)
    for key in ["x","y","angle","hull_id","size"]:
        overlap.board.snapshot.pieces[1][key] = overlap.board.snapshot.pieces[0][key]
    check(roundtrip(overlap).is_empty(),"deep hull overlap rejected")
    var floating := initial.duplicate(true)
    for piece in floating.board.snapshot.pieces: piece.y -= 10.0
    check(roundtrip(floating).is_empty(),"unsupported board rejected")
    var converted := initial.duplicate(true)
    converted.board.snapshot.pieces[0].match_type = "blue"
    converted.board.snapshot.pieces[0].bomb_tier = 1
    check(not roundtrip(converted).is_empty(),"hull independent of converted type and blue bomb allowed")
    converted.board.snapshot.pieces[0].match_type = "heart"
    check(roundtrip(converted).is_empty(),"bomb cannot be nonblue")
    for invalid in [NAN,INF,-INF]:
        var value := initial.duplicate(true)
        value.board.snapshot.pieces[0].x = invalid
        check(Store.validate(value).is_empty(),"nonfinite geometry rejected before serialization")

func choice_boundaries() -> void:
    for route in ["safe","risk"]:
        for recruit in ["bomber","gardener","skip"]:
            var run := RunV2.fresh(41)
            var state := terminal(run)
            run = RunV2.complete_battle(run,state).state
            check(not roundtrip(record(run,state)).is_empty(),"before route "+route+recruit)
            run = RunV2.choose_route(run,route).state
            check(not roundtrip(record(run,state)).is_empty(),"after route retains completed hall1 with exact heal "+route)
            var forged := record(run,state)
            forged.run.hp -= 1
            check(roundtrip(forged).is_empty(),"reject altered route reward delta")
            state = terminal(run)
            run = RunV2.complete_battle(run,state).state
            check(not roundtrip(record(run,state)).is_empty(),"before recruit retains risk victory limit delta "+route)
            run = RunV2.choose_recruit(run,recruit).state
            check(not roundtrip(record(run,state)).is_empty(),"after recruit retains preparty hall2 "+recruit)
            var active := Combat.fresh(RunV2.battle_context(run))
            var value := record(run,active)
            check(not roundtrip(value).is_empty(),"new active context "+route+recruit)
            for generated in [0,1]:
                active = Combat.fresh(RunV2.battle_context(run))
                if recruit == "bomber":
                    active = Skills.apply(active,Skills.preview(value.board.snapshot,active,"bomber")).state
                    active.actions_left = 1
                    active.bomb_buff.generated_count = generated
                    run = RunV2.sync_battle(run,active).state
                    value = record(run,active)
                    var restored := roundtrip(value)
                    check(not restored.is_empty() and restored.battle.team_skill_used,"paid buff before final refill decoded")
                    restored.battle.refill_pending = true
                    restored.battle.actions_left = 0
                    var resolved := Combat.finish_refill(restored.battle,0)
                    check(resolved.ok and resolved.state.energy == (6 if generated == 0 else 0),"zero/one generated refund applied once")
                    run = RunV2.sync_battle(run,resolved.state).state
                    var after := roundtrip(record(run,resolved.state))
                    check(not after.is_empty(),"postrefund checkpoint decoded")
                    var repeated := Combat.finish_refill(after.battle,0)
                    check(not repeated.ok and repeated.state.energy == resolved.state.energy,"postresume refund cannot repeat")
            state = terminal(run)
            run = RunV2.complete_battle(run,state).state
            check(not roundtrip(record(run,state)).is_empty(),"completed terminal decoded")
    for stage_index in range(3):
        var run := RunV2.fresh(41)
        for index in range(stage_index):
            run = RunV2.complete_battle(run,terminal(run)).state
            run = RunV2.choose_route(run,"risk").state if index == 0 else RunV2.choose_recruit(run,"skip").state
        var state := terminal(run,"defeat")
        run = RunV2.complete_battle(run,state).state
        check(not roundtrip(record(run,state)).is_empty(),"defeat at stage "+str(stage_index))

func file_transactions(initial: Dictionary) -> void:
    var v1 := slot.get_base_dir().path_join("fixture-v1.json")
    var file := FileAccess.open(v1,FileAccess.WRITE)
    file.store_string("v1 sentinel bytes\n")
    file.close()
    var before := FileAccess.get_file_as_bytes(v1)
    check(Store.write_checkpoint(slot,initial) == OK,"atomic write explicit fixture")
    var good := FileAccess.get_file_as_bytes(slot)
    check(not Store.read_checkpoint(slot).is_empty(),"explicit fixture read")
    file = FileAccess.open(slot+".tmp",FileAccess.WRITE)
    file.store_string("{half")
    file.close()
    check(not Store.read_checkpoint(slot).is_empty(),"partial temp ignored")
    var invalid := initial.duplicate(true)
    invalid.version = 9
    check(Store.write_checkpoint(slot,invalid) != OK and FileAccess.get_file_as_bytes(slot) == good,"invalid write preserves last good")
    DirAccess.remove_absolute(slot+".tmp")
    DirAccess.make_dir_absolute(slot+".tmp")
    check(Store.write_checkpoint(slot,initial) != OK and FileAccess.get_file_as_bytes(slot) == good,"failed temporary open preserves last good")
    DirAccess.remove_absolute(slot+".tmp")
    check(FileAccess.get_file_as_bytes(v1) == before,"v1 bytes untouched")
    check(Store.read_checkpoint().is_empty(),"--no-save bypasses actual slot read")
    check(Store.write_checkpoint(Config.SAVE_PATH,initial) == OK,"--no-save bypasses actual slot write")
    check(not FileAccess.file_exists(Config.SAVE_PATH),"--no-save never creates actual slot")

func expedition_boundaries(initial: Dictionary) -> void:
    var expedition := ExpeditionScene.instantiate()
    root.add_child(expedition)
    if not expedition.has_method("resume_checkpoint"):
        check(false,"Expedition exposes explicit validated resume")
        expedition.queue_free()
        await process_frame
        return
    check(expedition.resume_checkpoint(initial),"explicit validated resume")
    check(expedition.battle.phase == "READY","active resume restores board directly")
    var run := RunV2.fresh(41)
    var state := terminal(run)
    run = RunV2.complete_battle(run,state).state
    var before := record(run,state)
    check(expedition.resume_checkpoint(before) and expedition.battle == null,"route choice resumes completed board without regrant")
    expedition._choose("safe",int(expedition.run.revision),str(expedition.run.stage),expedition.generation)
    var after: Dictionary = expedition.checkpoint_record()
    check(not after.is_empty() and after.run.stage == "battle2" and after.battle.enemy_id == "hall1","completed choice saved while fresh next Board falls")
    check(after.run.hp == 58,"safe heal exactly once at transition")
    var saved_good: Dictionary = expedition.last_good_checkpoint()
    expedition.battle._on_settle_failed("fixture initial settle failed")
    check(expedition.save_checkpoint(slot) == ERR_BUSY and expedition.last_good_checkpoint() == saved_good,"initial fall error cannot replace last good completed boundary")
    check(expedition.resume_checkpoint(after),"completed-choice resume starts next battle once")
    check(expedition.run.hp == 58 and expedition.battle.state.hp == 58,"resume preserves awarded HP")
    check(await wait_ready(expedition.battle),"resumed next battle settles")
    var next: Dictionary = expedition.checkpoint_record()
    var high_revision := int(expedition.battle.state.revision)+50
    var high_board := int(expedition.battle.board.version)+50
    expedition.battle.state.revision = high_revision
    expedition.battle.board.version = high_board
    check(expedition.resume_checkpoint(initial),"resume older active record across live owner")
    check(expedition.battle.state.revision == high_revision+1 and expedition.battle.board.version == high_board+1,"Expedition resume preserves current version floors")
    expedition.battle._show_preview(next_plan(expedition.battle),-2)
    check(expedition.checkpoint_record().is_empty(),"held preview cannot fall back to an older completed board")
    expedition.battle.cancel_input()
    check(next.battle.enemy_id == "hall2_safe" and next.battle.status == "active","new stable board replaces completed boundary")
    var held := next_plan(expedition.battle)
    expedition.battle._show_preview(held,-2)
    check(expedition.save_checkpoint(slot) == ERR_BUSY,"held checkpoint cannot be written")
    expedition.battle.cancel_input()
    var good: Dictionary = expedition.last_good_checkpoint()
    DirAccess.make_dir_absolute(slot+".tmp")
    check(expedition.save_checkpoint(slot) != OK and not expedition.save_error.is_empty(),"Expedition exposes actual fixture write failure")
    check(expedition.last_good_checkpoint() == good,"failed write retains last good full record API")
    DirAccess.remove_absolute(slot+".tmp")
    var old_run: Dictionary = expedition.run.duplicate(true)
    var corrupt := initial.duplicate(true)
    corrupt.run.stage = "missing"
    check(not expedition.resume_checkpoint(corrupt) and expedition.run == old_run,"invalid explicit resume reports error without resetting run")
    check(not expedition.save_error.is_empty(),"corrupt resume surfaces error")
    expedition.new_run(41)
    check(expedition.run.stage == "battle1" and expedition.run.hp == Config.START_HP,"explicit new run resets progress")
    expedition.queue_free()
    await process_frame


func live_refund_and_terminal() -> void:
    var run := RunV2.fresh(41)
    run = RunV2.complete_battle(run,terminal(run)).state
    run = RunV2.choose_route(run,"risk").state
    run = RunV2.complete_battle(run,terminal(run)).state
    run = RunV2.choose_recruit(run,"bomber").state
    var owner := BattleScene.instantiate()
    root.add_child(owner)
    for generated in [0,1]:
        var state := Combat.fresh(RunV2.battle_context(run))
        state = Skills.apply(state,Skills.preview(board_fixture.snapshot,state,"bomber")).state
        state.actions_left = 1
        state.pending_damage = 12
        state.pending_heal = 3
        var synced: Dictionary = RunV2.sync_battle(run,state).state
        var value := record(synced,state)
        owner.restore_checkpoint({"state":value.battle,"board":value.board,"reduced":true})
        var plan := next_plan(owner)
        # Search explicit fixture RNG states using the actual batch generator;
        # no production sampling/probability/physics rules are changed.
        var probe = load("res://scripts/v2/board.gd").new()
        probe.rng.seed = int(value.board.rng_seed)
        var found := false
        for attempt in range(300):
            var candidate := str(probe.rng.state)
            var batch: Array = probe.make_refill(plan.removed_ids.size())
            var blues := batch.filter(func(piece): return piece.match_type == "blue").size()
            if blues == generated:
                value.board.rng_state = candidate
                found = true
                break
        probe.free()
        check(found,"find deterministic actual final refill with blue count "+str(generated))
        var restored := roundtrip(value)
        check(not restored.is_empty(),"full paid buff midturn fixture validates")
        if restored.is_empty(): continue
        owner.restore_checkpoint({"state":restored.battle,"board":restored.board,"reduced":true})
        plan = next_plan(owner)
        var expected_energy := mini(Config.MAX_ENERGY,int(plan.energy_effective)+(Config.SKILL_COSTS.bomber if generated == 0 else 0))
        owner._show_preview(plan,-2)
        check(owner.commit_preview(plan),"restored paid buff final actual clear")
        check(await wait_ready(owner),"restored paid buff actual refill settles")
        check(owner.state.bomb_buff.generated_count == generated and owner.state.bomb_buff.refunded == (generated == 0),"actual blue count controls once-only refund")
        check(owner.state.energy == expected_energy,"actual restored refund energy matches final refill")
        synced = RunV2.sync_battle(run,owner.state).state
        var post := record(synced,owner.state)
        post.board = owner.export_checkpoint().board
        restored = roundtrip(post)
        check(not restored.is_empty(),"actual postrefund physical checkpoint validates")
        owner.restore_checkpoint({"state":restored.battle,"board":restored.board,"reduced":true})
        var repeated := Combat.finish_refill(owner.state,0)
        check(not repeated.ok and repeated.state.energy == expected_energy,"actual postrefund resume cannot repeat refund")
    var signal_count := [0]
    owner.finished.connect(func(_summary): signal_count[0] += 1)
    for status in ["victory","defeat"]:
        var ended := terminal(run,status)
        var ended_run: Dictionary = RunV2.complete_battle(run,ended).state
        var ended_record := roundtrip(record(ended_run,ended))
        owner.restore_checkpoint({"state":ended_record.battle,"board":ended_record.board,"reduced":true})
        await physics_frame
        check(owner.phase == "FINISHED" and owner._finished_sent,"terminal restore remains finished")
        check(signal_count[0] == 0,"terminal restore emits no repeated completion")
    owner.queue_free()
    await process_frame


func live_recruit_boundaries() -> void:
    var expedition := ExpeditionScene.instantiate()
    root.add_child(expedition)
    for recruit in ["bomber","gardener","skip"]:
        var run := RunV2.fresh(41)
        run = RunV2.complete_battle(run,terminal(run)).state
        var route := "safe" if recruit == "gardener" else "risk"
        run = RunV2.choose_route(run,route).state
        var ended := terminal(run)
        run = RunV2.complete_battle(run,ended).state
        check(expedition.resume_checkpoint(record(run,ended)),"live before recruit resumes "+recruit)
        check(expedition.battle == null and expedition.run.stage == "recruit_choice","recruit screen does not replay completion")
        var limit_before: int = expedition.run.hero_limit
        expedition._choose(recruit,int(expedition.run.revision),"recruit_choice",expedition.generation)
        var after: Dictionary = expedition.checkpoint_record()
        check(not after.is_empty() and after.run.stage == "battle3" and after.battle.enemy_id == "hall2_"+route,"live after recruit retains last completed board "+recruit)
        var expected_limit := mini(Config.HERO_MAX_LIMIT,limit_before+(Config.DECLINE_LIMIT_BONUS if recruit == "skip" else 0))
        check(after.run.hero_limit == expected_limit,"recruit limit once at boundary")
        var memory: Dictionary = expedition.last_good_checkpoint()
        expedition.battle._on_settle_failed("fixture recruit fall failed")
        check(expedition.checkpoint_record().is_empty() and expedition.last_good_checkpoint() == memory,"failed fresh boss keeps completed recruit checkpoint")
        check(expedition.resume_checkpoint(after),"after recruit resumes next context once "+recruit)
        check(expedition.run.hero_limit == expected_limit and expedition.battle.state.party == after.run.party,"resume preserves chosen party/limit")
        check(await wait_ready(expedition.battle),"resumed boss Board settles "+recruit)
        var active: Dictionary = expedition.checkpoint_record()
        check(not active.is_empty() and active.battle.enemy_id == "gate","new stable boss checkpoint replaces completed record")
        var plan := next_plan(expedition.battle)
        expedition.battle._show_preview(plan,-2)
        check(expedition.checkpoint_record().is_empty(),"boss preview cannot save old completed record")
        check(expedition.battle.commit_preview(plan),"resumed recruited boss accepts actual next clear")
        check(await wait_ready(expedition.battle),"resumed recruited boss actual refill settles")
        check(expedition.battle.state.actions_left == 2 and expedition.run.hero_limit == expected_limit,"resumed boss action no repeated recruitment reward")
    expedition.queue_free()
    await process_frame

func finish() -> void:
    print(JSON.stringify({"suite":"v2 atomic saves and actual resume","checks":checks,"failures":failures}))
    quit(1 if failures else 0)

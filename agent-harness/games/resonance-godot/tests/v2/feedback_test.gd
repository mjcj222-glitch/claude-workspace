extends SceneTree
## Controlled settlement-boundary fixtures exercise real Combat events and live owners.
## They do not claim physical refills or normal-play wins.
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const RunV2 = preload("res://scripts/v2/run_rules.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ",message)
func ready_owner(owner: Node) -> void:
    for frame in range(2400):
        if owner.phase in ["READY","FINISHED","ERROR"]: return
        await process_frame
func notice(owner: Node) -> String:
    return owner.view.labels.footer.text
func run() -> void:
    var view = load("res://scenes/v2/battle_view.tscn").instantiate()
    root.add_child(view)
    await process_frame
    var hearts := Fixtures.chain(3,"heart")
    for example in [{"hp":60,"pending":6,"effective":6},{"hp":72,"pending":0,"effective":0},{"hp":40,"pending":0,"effective":9}]:
        var state := Fixtures.combat()
        state.hp = example.hp
        state.pending_heal = example.pending
        var plan := Combat.preview(hearts,state,1)
        var original := plan.duplicate(true)
        view.show_state(state,["hero"])
        view.show_plan(hearts,plan)
        var line: String = view.get_node("PreviewLine").text
        check(plan.healing_raw == 9 and plan.healing_effective == example.effective,"real ActionPlan supplies raw and capped healing")
        check(line.contains("누적+9") and line.contains("실효+%d" % example.effective),"visible preview distinguishes raw accrual and effective healing")
        check(view.labels.hp.text.contains("회복 +%d" % example.pending),"earlier pending healing stays separate")
        check(plan == original,"formatting does not mutate authoritative ActionPlan")
        var widest := plan.duplicate(true)
        widest.weaken_intent=true
        widest.refill_tier=3
        view.show_plan(hearts,widest)
        var preview: Label=view.get_node("PreviewLine")
        var font: Font=preview.get_theme_font("font")
        var metrics := font.get_multiline_string_size(preview.text,HORIZONTAL_ALIGNMENT_LEFT,-1,preview.get_theme_font_size("font_size"))
        check(metrics.x<=preview.size.x and metrics.y<=preview.size.y,"raw/effective plus bomb/weakening suffix fits actual preview bounds")
        var applied := Combat.apply_action(state,plan)
        check(applied.ok and applied.state.pending_heal == example.pending+9,"same shown plan accrues raw9 on commit")
    view.show_refund_notice({"paid_cost":6,"energy_effective":5})
    view.show_refund_notice({})
    check(not view.labels.footer.text.contains("환불"),"clearing transient feedback removes old pixels before any asynchronous restore/recovery")
    view.free()
    for target in ["active","cap0","route_choice","completed","lost"]:
        var expedition = load("res://scenes/v2/expedition.tscn").instantiate()
        root.add_child(expedition)
        await process_frame
        if target in ["completed","lost"]:
            var run_state := RunV2.fresh(41)
            for index in [0,1]:
                var won := Combat.fresh(RunV2.battle_context(run_state))
                won.status="victory"; won.enemy_hp=0
                run_state=RunV2.complete_battle(run_state,won).state
                run_state=RunV2.choose_route(run_state,"risk").state if index==0 else RunV2.choose_recruit(run_state,"bomber").state
            expedition.run=run_state
            expedition._show_stage()
        var owner: Node=expedition.battle
        await ready_owner(owner)
        check(owner.phase=="READY","actual live owner ready before controlled settlement")
        # Real skill application; only this fixture's turn/end-state is controlled.
        owner.state.party=["hero","bomber"]
        expedition.run.party=["hero","bomber"] # controlled pre-recruit ownership fixture for choice handoff
        owner.state.energy=10
        owner._render_state()
        var bomber := Skills.preview(owner.snapshot,owner.state,"bomber")
        owner._show_preview(bomber,7)
        check(owner.commit_preview(bomber),"real Bomber skill is accepted once")
        await ready_owner(owner)
        owner.state.energy=10 if target=="cap0" else 5
        owner.state.actions_left=0
        owner.state.refill_pending=true
        owner.state.pending_damage=0 if target in ["active","cap0","lost"] else owner.state.enemy_hp
        if target=="lost": owner.state.hp=1
        owner._pending_refill=true
        owner._pending_epoch=owner._epoch
        owner._pending_board_version=owner.board.version
        owner._generated_bombs=0
        owner.phase="SETTLING"
        var generation: int=expedition.generation
        var stage: String=expedition.run.stage
        owner._on_settled(owner.board.capture())
        await process_frame
        if target in ["active","cap0"]:
            await ready_owner(owner)
            check(owner.phase=="READY" and notice(owner).contains("환불"),"new actual refund survives wait/render/recovery on continuing owner")
            check(notice(owner).contains("+0" if target=="cap0" else "+5") and notice(owner).contains("지불6"),"notice shows actual capped return separately from paid6")
            var shown := notice(owner)
            owner._on_settled(owner.board.capture())
            owner._render_state()
            check(notice(owner)==shown and owner.event_log.filter(func(e):return e.type=="energy_refunded").size()==1,"duplicate/stale settle cannot append or replay refund")
            var saved: Dictionary=owner.export_checkpoint()
            owner.restore_checkpoint(saved)
            await ready_owner(owner)
            check(not notice(owner).contains("환불"),"restored old event log/refunded state does not replay notice")
            owner.start_battle({"enemy_id":"hall1","seed":41,"party":["hero"]})
            check(not notice(owner).contains("환불"),"new battle clears prior notice")
            await ready_owner(owner)
            owner.state.actions_left=0
            owner.state.refill_pending=true
            owner._pending_refill=true
            owner._pending_epoch=owner._epoch
            owner._pending_board_version=owner.board.version
            owner.phase="SETTLING"
            owner._on_settled(owner.board.capture())
            await ready_owner(owner)
            check(not notice(owner).contains("환불"),"accepted settlement without refund event invents no notice")
        else:
            check(expedition.battle==null and expedition.run.stage==target,"actual accepted completion retires battle into correct successor")
            var panel_text := ""
            if is_instance_valid(expedition.choice_panel):
                for node in expedition.choice_panel.find_children("*","Label",true,false): panel_text+=node.text
            check(panel_text.contains("환불") and panel_text.contains("+5") and panel_text.contains("지불6"),"successor screen visibly owns actual capped refund after retirement")
            var revision: int=expedition.run.revision
            var foreign := Node.new()
            expedition._on_battle_finished({"status":"victory"},foreign,generation,stage)
            foreign.free()
            check(expedition.run.revision==revision,"stale retired-owner completion has no effect")
            if target=="completed":
                var record: Dictionary=expedition.last_good_checkpoint()
                check(not record.is_empty() and expedition.resume_checkpoint(record),"real completed checkpoint resumes through current Expedition")
                var resumed_text := ""
                for node in expedition.choice_panel.find_children("*","Label",true,false): resumed_text+=node.text
                check(not resumed_text.contains("환불"),"completed resume never replays saved refund marker as new notice")
            expedition.new_run(41)
            check(expedition.battle!=null and not notice(expedition.battle).contains("환불"),"restart does not replay prior completion notice")
        expedition.free()
        await process_frame
    print(JSON.stringify({"suite":"v2 visible settlement feedback","checks":checks,"failures":failures}))
    quit(0 if failures==0 else 1)

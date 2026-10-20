extends "res://tests/v2/full_expedition_test.gd"
## All previous actions run frozen Board/1.0 matching; only the target uses current Board.
var witness: Dictionary
var product_board: Script
var switched := false
var swap_evidence := {}
var output := ""
func json_equal(actual: Variant, expected: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(actual)) == expected
func observe(phase_name: String, owner: Node, plan: Dictionary) -> void:
    await super.observe(phase_name,owner,plan)
    if phase_name != "ready" or owner == null or switched: return
    if owner.board.next_id != 68 or str(owner.board.rng.seed) != "3296630253": return
    var board = owner.board
    var prior: Dictionary = owner.export_checkpoint().duplicate(true)
    check(json_equal(prior,witness.expected_checkpoint),"all original target checkpoint fields/poses/RNG exactly match before script swap")
    var properties := ["pieces","rng","next_id","version","settling","stable_ticks","elapsed","last_settle_seconds","refill_phase","_recovery_epoch","_recovering","_pending_batch","_pending_openings","last_snapshot"]
    var values := {}
    for key in properties: values[key] = board.get(key)
    var identities: Array = board.pieces.map(func(p): return p.get_instance_id())
    board.set_script(product_board)
    for key in properties: board.set(key,values[key])
    swapped(prior,owner,identities)
func swapped(prior: Dictionary, owner: Node, identities: Array) -> void:
    switched = true
    swap_evidence = {"checkpoint_identical":owner.export_checkpoint() == prior,"same_body_instances":identities == owner.board.pieces.map(func(p): return p.get_instance_id()),"checkpoint":prior}
    check(swap_evidence.checkpoint_identical and swap_evidence.same_body_instances,"target switch preserves every live body and complete checkpoint")
    var plan := Combat.preview(owner.snapshot,owner.state,51)
    check(json_equal(plan,witness.failed_plan),"exact original five-ID displayed target plan preserved")
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args(): quit(1); return
    witness = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v2/fixtures/inlet_history/witness.json"))
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--product-board="): product_board = load(arg.trim_prefix("--product-board="))
        if arg.begins_with("--history-output="): output = arg.trim_prefix("--history-output=")
    var trace := await play(41,"risk","skip",true)
    check(switched,"reached actual original trajectory target")
    var prefix := true
    for index in range(witness.expected_steps.size()):
        if trace.steps.size() <= index or not json_equal(trace.steps[index],witness.expected_steps[index]): prefix = false
    check(prefix,"all21 original steps exactly equal original witness; no restore or seed substitution")
    check(trace.stage == "lost" and trace.get("restart_checked",false),"target real refill resolves actual defeat/restart")
    if not trace.results.is_empty():
        var last: Dictionary = trace.results.back()
        check(last.state.hp == 0 and last.state.enemy_hp == 72 and not last.state.refill_pending,"original target resolves correct HP0/enemy72 after one final refill")
    if not output.is_empty(): write_json(output,{"profile":"HISTORICAL1.0 matching, original bodies; current product Board only at target","prefix_equal":prefix,"swap":swap_evidence,"trace":trace,"checks":checks,"failures":failures})
    print(JSON.stringify({"suite":"v2 historical original inlet trajectory","checks":checks,"failures":failures,"prefix_equal":prefix,"switched":switched,"stage":trace.stage}))
    quit(0 if failures == 0 else 1)

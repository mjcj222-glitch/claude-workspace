extends SceneTree

const SkillsV2 = preload("res://scripts/v2/skill_rules.gd")
const CombatV2 = preload("res://scripts/v2/combat_rules.gd")
const BoardV2 = preload("res://scripts/v2/board.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func recruited(actor: String, energy: int = 10) -> Dictionary:
    var state := Fixtures.combat("gate", 1, 40, energy)
    if actor != "hero":
        state.party.append(actor)
    return state

func ids(plan: Dictionary) -> Array:
    var result: Array = plan.get("changes", {}).keys()
    result.sort()
    return result

func branch() -> Dictionary:
    # Hop-two ID 2 must win over ID 90 even though its parent is visited last.
    return Fixtures.snapshot([
        Fixtures.tile(1, "red", 0, Vector2(250, 250)),
        Fixtures.tile(10, "red", 0, Vector2(250-Fixtures.circle_step(), 250)),
        Fixtures.tile(20, "red", 0, Vector2(250+Fixtures.circle_step(), 250)),
        Fixtures.tile(90, "red", 0, Vector2(250-2*Fixtures.circle_step(), 250)),
        Fixtures.tile(2, "red", 0, Vector2(250+2*Fixtures.circle_step(), 250))], 17)

func inspect_hero() -> void:
    var snap := branch()
    var state := Fixtures.combat()
    var before := state.duplicate(true)
    var snap_before := snap.duplicate(true)
    for limit in [3, 4, 5]:
        state.hero_limit = limit
        var plan := SkillsV2.preview(snap, state, "hero", 1, "blue")
        var expected: Array = {3: [1, 10, 20], 4: [1, 2, 10, 20], 5: [1, 2, 10, 20, 90]}[limit]
        check(ids(plan) == expected, "hero limit %d uses BFS then whole-frontier ID order" % limit)
        check(plan.get("board_version") == 17 and plan.get("combat_version") == 1, "skill stamps both authoritative versions")
        check(plan.get("actor_id") == "hero" and plan.get("cost") == 4
            and plan.get("destination") == "blue" and plan.get("seed_id") == 1, "hero plan records selected actor, destination and exact cost")
        for type in plan.get("changes", {}).values():
            check(type == "blue", "hero changes contain only destination types")
    state.hero_limit = 3
    check(state == before and snap == snap_before, "hero previews preserve state and every snapshot property")
    check(SkillsV2.preview(snap, state, "hero", 1, "red").is_empty(), "same destination color is invalid")
    check(SkillsV2.preview(snap, state, "hero", 1, "heart").is_empty(), "hero cannot create hearts")
    check(SkillsV2.preview(snap, state, "hero", 1, "").is_empty(), "hero needs a destination")
    check(SkillsV2.preview(snap, state, "hero", -1, "blue").is_empty(), "missing target cannot spend resources")
    for barrier in ["heart", "blue", "yellow"]:
        var chain := Fixtures.chain(5)
        chain.pieces[1].match_type = barrier
        if barrier == "blue":
            chain.pieces[1].bomb_tier = 2
        check(ids(SkillsV2.preview(chain, state, "hero", 1, "blue")) == [1], "hero never crosses a %s bridge" % barrier)
        if barrier != "yellow":
            check(SkillsV2.preview(chain, state, "hero", 2, "red").is_empty(), "hero cannot target heart or bomb")
    check(ids(SkillsV2.preview(Fixtures.chain(5, "blue", {2: 1}), state, "hero", 1, "red")) == [1],
        "hero cannot traverse a bomb even when its blue matches the source")

func inspect_apply_and_rejections() -> void:
    var snap := Fixtures.chain(4)
    var state := Fixtures.combat()
    var plan := SkillsV2.preview(snap, state, "hero", 1, "yellow")
    var before := state.duplicate(true)
    var plan_before := plan.duplicate(true)
    var applied := SkillsV2.apply(state, plan)
    check(applied.ok, "starting four energy permits first hero conversion")
    check(state == before and plan == plan_before, "apply leaves state and displayed skill plan unchanged")
    if applied.ok:
        var expected := before.duplicate(true)
        expected.energy = 0
        expected.team_skill_used = true
        expected.revision += 1
        check(applied.state == expected, "skill consumes exact cost and team permission with no action or healing")
        check(applied.events == [{"type": "skill_applied", "actor_id": "hero", "cost": 4, "changes": plan.changes}], "skill event exposes the applied transformation")
        check(not SkillsV2.apply(applied.state, plan).ok, "same displayed skill cannot apply twice")
        check(SkillsV2.preview(snap, applied.state, "hero", 1, "blue").is_empty(), "second skill in the same turn is unavailable")
    for field in ["revision", "energy", "team_skill_used", "refill_pending", "status", "actions_left", "party"]:
        var blocked := before.duplicate(true)
        blocked[field] = {"revision": 2, "energy": 3, "team_skill_used": true,
            "refill_pending": true, "status": "victory", "actions_left": 0, "party": []}[field]
        if field != "revision":
            check(SkillsV2.preview(snap, blocked, "hero", 1, "yellow").is_empty(), "%s blocks skill preview" % field)
        var result := SkillsV2.apply(blocked, plan)
        check(not result.ok and result.state == blocked and result.events.is_empty(), "%s rejects skill without resource changes" % field)
    for actor in ["bomber", "gardener", "unknown"]:
        check(SkillsV2.preview(snap, before, actor, 1).is_empty(), "unrecruited/unknown %s cannot be used" % actor)
    for invalid in [{}, {"actor_id": "hero"}]:
        var result := SkillsV2.apply(before, invalid)
        check(not result.ok and result.state == before, "cancelled or incomplete skill plan consumes nothing")
    if not plan.is_empty():
        var empty_target := plan.duplicate(true)
        empty_target.changes = {}
        check(not SkillsV2.apply(before, empty_target).ok, "empty transformation cannot consume skill")

func inspect_gardener() -> void:
    var snap := branch()
    snap.pieces[2].match_type = "yellow"
    snap.pieces[3].match_type = "blue"
    var state := recruited("gardener", 4)
    var plan := SkillsV2.preview(snap, state, "gardener", 1)
    check(ids(plan) == [1, 10, 20], "gardener picks seed plus two closest contacts across normal colors")
    check(plan.get("destination") == "heart" and plan.get("cost") == 4, "gardener plan creates hearts for four energy")
    var applied := SkillsV2.apply(state, plan)
    check(applied.ok and applied.state.hp == state.hp and applied.state.pending_heal == 0,
        "gardener conversion grants no immediate or pending healing")
    if not applied.ok:
        return
    for tile in snap.pieces:
        if plan.changes.has(tile.id):
            tile.match_type = plan.changes[tile.id]
    snap.version += 1
    var removed := CombatV2.preview(snap, applied.state, 1)
    check(removed.get("healing_raw") == 9 and removed.get("healing_effective") == 9,
        "removing the three connected created hearts grants exactly nine healing")
    for barrier in ["heart", "blue"]:
        var chain := Fixtures.chain(4)
        chain.pieces[1].match_type = barrier
        if barrier == "blue":
            chain.pieces[1].bomb_tier = 1
        check(ids(SkillsV2.preview(chain, state, "gardener", 1)) == [1], "gardener cannot traverse heart or bomb bridges")
        check(SkillsV2.preview(chain, state, "gardener", 2).is_empty(), "gardener cannot target heart or bomb")
    var short_plan := SkillsV2.preview(Fixtures.chain(1), state, "gardener", 1)
    check(ids(short_plan) == [1], "gardener uses available connected targets without requiring three")

func batch() -> Array:
    return [Fixtures.tile(101, "red", 2, Vector2(10, -50)),
        Fixtures.tile(102, "blue", 1, Vector2(100, -50)),
        Fixtures.tile(103, "heart", 3, Vector2(200, -50)),
        Fixtures.tile(104, "blue", 0, Vector2(300, -50))]

func inspect_bomber_and_refill() -> void:
    var snap := Fixtures.chain(3, "blue")
    var state := recruited("bomber", 6)
    state.bomb_buff = {"active": false, "paid_cost": 6, "generated_count": 8, "refunded": true}
    var before := state.duplicate(true)
    var skill := SkillsV2.preview(snap, state, "bomber")
    check(skill.get("cost") == 6 and skill.get("changes", {1: "bad"}).is_empty(), "bomber activation plans buff with no board targets")
    var activated := SkillsV2.apply(state, skill)
    check(activated.ok, "recruited bomber activates at six energy")
    if not activated.ok:
        return
    state = activated.state
    check(state.bomb_buff == {"active": true, "paid_cost": 6, "generated_count": 0, "refunded": false}, "new bomber activation replaces all expired audit markers")
    check(state.energy == 0 and state.team_skill_used and state.actions_left == 3, "bomber spends energy and permission without removal")
    check(snap == Fixtures.chain(3, "blue") and before.bomb_buff.generated_count == 8, "activation never changes existing blue or input state")

func inspect_refill_decoration() -> void:
    var snap := Fixtures.chain(3, "blue")
    var state := recruited("bomber", 0)
    state.team_skill_used = true
    state.bomb_buff = {"active": true, "paid_cost": 6, "generated_count": 0, "refunded": false}
    for n in [3, 4, 5, 7, 8, 12]:
        var action := CombatV2.preview(Fixtures.chain(n), state, 1)
        var pending := CombatV2.apply_action(state, action)
        var original := batch()
        var original_before := original.duplicate(true)
        var pending_before: Dictionary = pending.state.duplicate(true)
        var action_before := action.duplicate(true)
        var decorated := SkillsV2.decorate_refill(original, pending.state, action)
        var tier: int = {3: 1, 4: 1, 5: 2, 7: 2, 8: 3, 12: 3}[n]
        var expected := original.duplicate(true)
        expected[1].bomb_tier = tier
        expected[3].bomb_tier = tier
        check(decorated.batch == expected and decorated.generated_bombs == 2, "direct %d decorates only newly generated blues at tier %d" % [n, tier])
        check(original == original_before and pending.state == pending_before and action == action_before, "refill decoration preserves batch, state and trigger plan")
        check(action.removed_ids == range(1, n + 1) and action.fired_bomb_ids.is_empty(), "new bombs never join current removal or fired queue")
    for source in [Fixtures.chain(3, "heart"), Fixtures.chain(1, "blue", {1: 3})]:
        var action := CombatV2.preview(source, state, 1)
        var pending := CombatV2.apply_action(state, action)
        var decorated := SkillsV2.decorate_refill(batch(), pending.state, action)
        check(decorated.batch[1].bomb_tier == 1 and decorated.generated_bombs == 2, "hearts and solo bombs produce small refill bombs")
    var action := CombatV2.preview(snap, state, 1)
    var pending := CombatV2.apply_action(state, action)
    var unchanged := SkillsV2.decorate_refill(batch(), recruited("bomber"), action)
    check(unchanged.batch == batch() and unchanged.generated_bombs == 0, "inactive buff does not decorate")
    check(SkillsV2.decorate_refill(batch(), state, action).generated_bombs == 0, "non-refill state does not decorate")
    var stale := action.duplicate(true)
    stale.combat_version -= 1
    check(SkillsV2.decorate_refill(batch(), pending.state, stale).generated_bombs == 0, "stale trigger cannot decorate a pending refill")
    check(SkillsV2.decorate_refill([], pending.state, action) == {"batch": [], "generated_bombs": 0}, "empty refill remains empty")
    var board := BoardV2.new()
    board.rng.seed = 517
    var generated := board.make_refill(42)
    var expected := generated.duplicate(true)
    var blues := 0
    for tile in expected:
        if tile.match_type == "blue":
            tile.bomb_tier = 1
            blues += 1
    var rng_before := board.rng.state
    var next_id_before := board.next_id
    var actual := SkillsV2.decorate_refill(generated, pending.state, action)
    check(actual.batch == expected and actual.generated_bombs == blues and blues > 0,
        "real seeded refill retains every sampled type, ID, hull, size, pose and order")
    check(board.rng.state == rng_before and board.next_id == next_id_before, "decoration consumes no board RNG or IDs")
    board.free()

func inspect_last_refill_and_refund() -> void:
    for blue_count in [0, 1]:
        var state := recruited("bomber", 6)
        state.actions_left = 1
        state.enemy_hp = 1
        var activated := SkillsV2.apply(state, SkillsV2.preview(Fixtures.chain(3), state, "bomber"))
        if not activated.ok:
            check(false, "bomber can activate before last removal")
            continue
        state = activated.state
        var action := CombatV2.preview(Fixtures.chain(3), state, 1)
        var pending := CombatV2.apply_action(state, action)
        var original := [Fixtures.tile(100, "blue" if blue_count else "yellow", 2, Vector2(0, -80))]
        pending.state.energy = 9
        var decorated := SkillsV2.decorate_refill(original, pending.state, action)
        check(decorated.generated_bombs == blue_count, "last refill includes actual new bomb count")
        var finished := CombatV2.finish_refill(pending.state, decorated.generated_bombs)
        check(finished.ok and finished.state.status == "victory" and not finished.state.bomb_buff.active,
            "last refill expires buff before battle outcome")
        check(finished.state.energy == (10 if blue_count == 0 else 9)
            and finished.state.bomb_buff.refunded == (blue_count == 0), "zero blue refunds once capped at ten; created bomb prevents refund")
        check(finished.state.team_skill_used, "refund does not restore team skill permission")
        check(decorated.batch[0].bomb_tier == blue_count, "created bomb persists after buff ends")
        var resumed: Dictionary = str_to_var(var_to_str(finished.state))
        var duplicate := CombatV2.finish_refill(resumed, decorated.generated_bombs)
        check(not duplicate.ok and duplicate.state == resumed, "resumed finished refill cannot refund twice")
    var poor := recruited("bomber", 5)
    check(SkillsV2.preview(Fixtures.chain(3), poor, "bomber").is_empty(), "bomber below six energy is unavailable")

func run() -> void:
    inspect_hero()
    inspect_apply_and_rejections()
    inspect_gardener()
    inspect_bomber_and_refill()
    inspect_refill_decoration()
    inspect_last_refill_and_refund()
    print("v2 skill rules checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

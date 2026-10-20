extends SceneTree

const CombatV2 = preload("res://scripts/v2/combat_rules.gd")
const SelectionV2 = preload("res://scripts/v2/selection_rules.gd")
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

func inspect_fresh_and_intent() -> void:
    var context := {"enemy_id": "gate", "seed": 41, "hp": 51, "energy": 7,
        "party": ["hero", "bomber"], "hero_limit": 4, "reduced": true}
    var before := context.duplicate(true)
    var state := CombatV2.fresh(context)
    var expected := Fixtures.combat("gate", 1, 51, 7)
    expected.party = ["hero", "bomber"]
    expected.hero_limit = 4
    check(state == expected, "fresh battle preserves context resources and resets all combat-only fields")
    check(context == before, "fresh leaves battle context unchanged")
    if not state.is_empty():
        state.party.append("gardener")
        check(context == before, "fresh owns its party array")
    var capped := CombatV2.fresh({"enemy_id": "hall1", "hp": 100, "energy": 100})
    check(capped.get("hp") == 72 and capped.get("energy") == 10, "fresh clamps HP and energy")
    check(CombatV2.fresh({"enemy_id": "unknown"}).is_empty(), "unknown enemy cannot start")
    var defaults := CombatV2.fresh({"enemy_id": "hall1"})
    check(defaults.get("hp") == 72 and defaults.get("energy") == 4, "fresh defaults start full with four energy")
    for enemy in ["hall1", "hall2_safe", "hall2_risk", "gate"]:
        var normal: int = {"hall1": 8, "hall2_safe": 12, "hall2_risk": 16, "gate": 16}[enemy]
        var strong: int = {"hall1": 8, "hall2_safe": 20, "hall2_risk": 26, "gate": 28}[enemy]
        var period: int = {"hall1": 0, "hall2_safe": 3, "hall2_risk": 3, "gate": 2}[enemy]
        for turn in range(1, 7):
            var is_strong := period > 0 and turn % period == 0
            var pressure: int = [0, 0, 0, 4, 8, 12][turn - 1]
            var shown := CombatV2.intent(enemy, turn)
            check(shown == {"kind": "strong" if is_strong else "normal", "base_damage": strong if is_strong else normal,
                "pressure": pressure, "total_damage": (strong if is_strong else normal) + pressure, "weakened": false},
                "%s turn %d follows configured attack cycle and pressure" % [enemy, turn])
            var weak := CombatV2.intent(enemy, turn, true)
            check(weak.get("kind") == "normal" and weak.get("total_damage") == normal + pressure
                and weak.get("weakened") == is_strong, "weakening only lowers a scheduled strong attack and keeps pressure")

func inspect_rewards() -> void:
    var damages := []
    var energies := []
    for n in [3, 4, 5, 7, 8, 11, 12]:
        var snap := Fixtures.chain(n)
        var state := Fixtures.combat()
        var snap_before := snap.duplicate(true)
        var state_before := state.duplicate(true)
        var plan := CombatV2.preview(snap, state, 1)
        damages.append(plan.get("direct_damage", -1))
        energies.append(plan.get("energy_raw", -1))
        var selection := SelectionV2.preview(snap, 1, state.revision)
        for key in selection:
            check(plan.get(key) == selection[key], "ActionPlan preserves selection field %s" % key)
        check(plan.get("refill_tier") == 0, "long groups alone do not generate bombs")
        check(snap == snap_before and state == state_before, "preview is pure")
    check(damages == [6, 8, 16, 20, 34, 40, 60], "direct damage at every threshold")
    check(energies == [1, 1, 2, 2, 4, 4, 6], "direct energy at every threshold")
    var state := Fixtures.combat("hall1", 1, 60, 9)
    state.pending_heal = 6
    var hearts := CombatV2.preview(Fixtures.chain(3, "heart"), state, 1)
    check(hearts.get("healing_raw") == 9 and hearts.get("healing_effective") == 6,
        "heart preview accounts for current HP and earlier pending healing")
    check(hearts.get("direct_damage") == 0 and hearts.get("blast_damage") == 0 and hearts.get("energy_raw") == 0,
        "direct hearts grant healing without attack or energy")
    var color := CombatV2.preview(Fixtures.chain(8), state, 1)
    check(color.get("energy_raw") == 4 and color.get("energy_effective") == 1, "preview exposes capped effective energy")
    state.hp = 72
    state.energy = 10
    var full := CombatV2.preview(Fixtures.chain(3, "heart"), state, 1)
    check(full.get("healing_raw") == 9 and full.get("healing_effective") == 0, "full HP retains raw healing with zero effective healing")
    check(CombatV2.preview(Fixtures.chain(3), state, 1).get("energy_effective") == 0, "full energy has zero effective gain")
    var snap := Fixtures.chain(3, "blue", {1: 3})
    # Deliberately overlap extras to isolate reward accounting from packing physics.
    for id in range(4, 13):
        snap.pieces.append(Fixtures.tile(id, "heart" if id == 4 else "red", 0, Vector2(0, id)))
    var blast := CombatV2.preview(snap, Fixtures.combat(), 1)
    check(blast.get("removed_ids", []).size() == 12 and blast.get("direct_color_count") == 3,
        "twelve removals may contain only three direct colors")
    check(blast.get("direct_damage") == 6 and blast.get("blast_damage") == 8
        and blast.get("healing_raw") == 3 and blast.get("energy_raw") == 1,
        "blast extras never increase direct rewards or duplicate heart healing")
    var solo_snap := Fixtures.snapshot([
        Fixtures.tile(1, "blue", 0, Vector2.ZERO, 2),
        Fixtures.tile(2, "blue", 0, Vector2(100, 0), 1),
        Fixtures.tile(3, "heart", 0, Vector2(50, 0)),
        Fixtures.tile(4, "red", 0, Vector2(110, 0))])
    var solo := CombatV2.preview(solo_snap, Fixtures.combat(), 1)
    check(solo.get("mode") == "solo_bomb" and solo.get("direct_damage") == 0 and solo.get("energy_raw") == 0,
        "solo bomb consumes an action without direct damage or energy")
    check(solo.get("blast_damage") == 1 and solo.get("healing_raw") == 3,
        "extra chained bomb deals no own damage and overlapping blasts heal each heart once")
    for n in [3, 4, 5, 7, 8, 12]:
        var buffed := Fixtures.combat()
        buffed.bomb_buff.active = true
        check(CombatV2.preview(Fixtures.chain(n), buffed, 1).get("refill_tier") == (1 if n < 5 else 2 if n < 8 else 3),
            "active bomber decorates refill according to direct group size")
        check(CombatV2.preview(Fixtures.chain(n, "heart"), buffed, 1).get("refill_tier") == 1, "hearts refill small bombs")
        check(CombatV2.preview(solo_snap, buffed, 1).get("refill_tier") == 1, "solo detonation refills small bombs")

func event_types(result: Dictionary) -> Array:
    var types := []
    for event in result.get("events", []):
        types.append(event.get("type"))
    return types

func inspect_actions_and_turns() -> void:
    var state := Fixtures.combat("hall1", 1, 68, 0)
    var snap := Fixtures.chain(3)
    for action in range(3):
        var before := state.duplicate(true)
        var plan := CombatV2.preview(snap, state, 1)
        var plan_before := plan.duplicate(true)
        var applied := CombatV2.apply_action(state, plan)
        check(applied.get("ok", false), "valid removal works at zero energy")
        var next: Dictionary = applied.get("state", state)
        check(state == before and plan == plan_before, "apply preserves source state and displayed plan")
        check(next.get("actions_left") == 2 - action and next.get("refill_pending", false), "apply consumes one action and locks until refill")
        check(next.get("pending_damage") == 6 * (action + 1) and next.get("enemy_hp") == 72 and next.get("hp") == 68,
            "apply accrues damage without attacking or counterattacking")
        check(next.get("energy") == action + 1 and next.get("revision") == state.revision + 1, "energy is immediate and accepted action advances revision")
        check(not CombatV2.apply_action(next, plan).get("ok", false), "repeated apply is rejected")
        var finished := CombatV2.finish_refill(next, 0)
        check(finished.get("ok", false), "pending refill completes once")
        state = finished.get("state", next)
        check(state.revision == next.revision + 1 and not state.refill_pending, "refill completion advances version and unlocks")
        var duplicate := CombatV2.finish_refill(state, 0)
        check(not duplicate.get("ok", false) and duplicate.get("state") == state and duplicate.get("events", []).is_empty(), "duplicate refill is a pure rejection")
        if action < 2:
            check(state.enemy_hp == 72 and state.hp == 68 and state.turn == 1, "first two refills never trigger an enemy action")
        else:
            check(state.enemy_hp == 54 and state.hp == 60 and state.turn == 2 and state.actions_left == 3,
                "third settled refill attacks then counters and prepares next turn")
            check(state.pending_damage == 0 and state.pending_heal == 0 and not state.team_skill_used, "next turn clears accrual and restores team skill use")
            check(event_types(finished) == ["refill_finished", "healed", "player_attack", "enemy_attack", "turn_started"], "turn event order matches settlement order")
    var waiting := Fixtures.combat()
    waiting.refill_pending = true
    for blocked in [waiting, Fixtures.combat()]:
        if not blocked.refill_pending:
            blocked.status = "victory"
        check(CombatV2.preview(snap, blocked, 1).is_empty(), "preview locked during refill or ended battle")
        var rejection := CombatV2.apply_action(blocked, {})
        check(not rejection.get("ok", false) and rejection.get("state") == blocked, "blocked apply consumes no resources")
    var active := Fixtures.combat()
    var stale := CombatV2.preview(snap, active, 1)
    stale.combat_version = 0
    for invalid in [{}, stale, {"combat_version": 1}]:
        var rejected := CombatV2.apply_action(active, invalid)
        check(not rejected.get("ok", false) and rejected.get("state") == active and rejected.get("events", []).is_empty(), "empty, stale and incomplete plans are pure rejection")
    check(CombatV2.preview(Fixtures.chain(2), active, 1).is_empty(), "invalid small selection has no combat preview")
    check(CombatV2.preview(snap, active, 999).is_empty(), "missing selection has no combat preview")
    var pending := Fixtures.combat()
    pending.refill_pending = true
    var bad_count := CombatV2.finish_refill(pending, -1)
    check(not bad_count.get("ok", false) and bad_count.get("state") == pending, "negative generated count cannot consume a refill")

func settled(state: Dictionary, n: int = 3, type: String = "red", bombs: int = 0) -> Dictionary:
    var applied := CombatV2.apply_action(state, CombatV2.preview(Fixtures.chain(n, type), state, 1))
    return CombatV2.finish_refill(applied.get("state", state), bombs)

func inspect_resolution_and_weakening() -> void:
    var state := Fixtures.combat("gate", 4, 10, 9)
    state.actions_left = 1
    state.pending_heal = 100
    state.pending_damage = 1000
    var won := settled(state, 3, "heart")
    var victor: Dictionary = won.get("state", state)
    check(victor.hp == 72 and victor.enemy_hp == 0 and victor.status == "victory" and victor.energy == 9,
        "healing caps before lethal player attack; defeated enemy cannot retaliate")
    check(event_types(won) == ["refill_finished", "healed", "player_attack", "battle_ended"], "victory omits counterattack and next turn")
    var lost_state := Fixtures.combat("gate", 4, 10, 0)
    lost_state.actions_left = 1
    var lost := settled(lost_state)
    var fallen: Dictionary = lost.get("state", lost_state)
    check(fallen.hp == 0 and fallen.status == "defeat" and fallen.turn == 4 and fallen.actions_left == 0,
        "lethal enemy attack ends battle without preparing a turn")
    check(event_types(lost) == ["refill_finished", "healed", "player_attack", "enemy_attack", "battle_ended"], "defeat event follows enemy attack")
    var healer := Fixtures.combat("gate", 4, 10, 0)
    healer.actions_left = 1
    healer.pending_heal = 25
    var healed: Dictionary = settled(healer).get("state", healer)
    check(healed.hp == 3 and healed.status == "active" and healed.turn == 5, "healing precedes enemy attack and can avert defeat")
    var weak_state := Fixtures.combat("gate", 4)
    weak_state.enemy_hp = 1000
    for i in range(2):
        var plan := CombatV2.preview(Fixtures.chain(12), weak_state, 1)
        check(plan.get("weaken_intent") == (i == 0), "12+ only offers new weakening for a currently strong intent")
        var applied := CombatV2.apply_action(weak_state, plan)
        weak_state = applied.get("state", weak_state)
        check(weak_state.intent.total_damage == 20 and weak_state.intent.weakened, "repeated long groups do not reduce pressure or normal base again")
        weak_state = CombatV2.finish_refill(weak_state, 0).get("state", weak_state)
    weak_state = settled(weak_state).get("state", weak_state)
    check(weak_state.hp == 52 and weak_state.turn == 5 and not weak_state.intent.weakened and weak_state.intent.total_damage == 24,
        "weakening affects only current turn and clears when next intent is prepared")
    weak_state = settled(weak_state).get("state", weak_state)
    weak_state = settled(weak_state).get("state", weak_state)
    weak_state = settled(weak_state).get("state", weak_state)
    check(weak_state.turn == 6 and weak_state.intent.kind == "strong" and weak_state.intent.total_damage == 40,
        "next scheduled strong attack is not skipped or weakened")
    check(not CombatV2.preview(Fixtures.chain(12), Fixtures.combat("gate", 3), 1).get("weaken_intent", true), "normal intent receives no weakening carryover")

func inspect_buff_refund() -> void:
    for generated in [0, 1]:
        var state := Fixtures.combat("hall1", 1, 72, 9)
        state.team_skill_used = true
        state.bomb_buff = {"active": true, "paid_cost": 6, "generated_count": 0, "refunded": false}
        for i in range(3):
            var result := settled(state, 3, "heart", generated if i == 2 else 0)
            state = result.get("state", state)
            if i < 2:
                check(state.bomb_buff.active and state.energy == 9 and state.team_skill_used,
                    "bomber remains active through remaining refills without early refund or skill reset")
            else:
                check(not state.bomb_buff.active and state.bomb_buff.generated_count == generated, "last refill is counted before buff expires")
                check(state.energy == (10 if generated == 0 else 9) and state.bomb_buff.refunded == (generated == 0), "zero generation refunds cost once under energy cap")
                var types := event_types(result)
                check(types.has("energy_refunded") == (generated == 0), "refund event emitted only when no bomb generated")
                if generated == 0:
                    check(types.find("energy_refunded") < types.find("healed"), "refund happens before turn healing")
                var duplicate := CombatV2.finish_refill(state, 0)
                check(not duplicate.get("ok", false) and duplicate.get("state") == state, "repeat settlement cannot refund again")
    var victory := Fixtures.combat("hall1", 1, 60, 0)
    victory.actions_left = 1
    victory.pending_damage = 72
    victory.team_skill_used = true
    victory.bomb_buff = {"active": true, "paid_cost": 6, "generated_count": 0, "refunded": false}
    var ended := settled(victory, 3, "heart")
    var end_state: Dictionary = ended.get("state", victory)
    check(end_state.energy == 6 and end_state.bomb_buff.refunded and end_state.team_skill_used and end_state.status == "victory",
        "battle-ending refund preserves consumed team usage")
    var resumed := end_state.duplicate(true)
    check(not CombatV2.finish_refill(resumed, 0).get("ok", false), "serialized completed battle cannot settle or refund twice")
    var already := victory.duplicate(true)
    already.bomb_buff.refunded = true
    check(settled(already, 3, "heart").get("state", already).energy == 0, "persisted refund marker prevents duplicate cost return")

func inspect_purity_and_effective_rewards() -> void:
    var state := Fixtures.combat("hall1", 1, 68, 9)
    state.actions_left = 1
    state.pending_heal = 2
    var plan := CombatV2.preview(Fixtures.chain(3, "heart"), state, 1)
    var before := state.duplicate(true)
    var applied := CombatV2.apply_action(state, plan)
    check(applied.get("ok", false), "heart action applies at its displayed effective healing")
    var pending: Dictionary = applied.get("state", state)
    var pending_before := pending.duplicate(true)
    var result := CombatV2.finish_refill(pending, 0)
    check(state == before and pending == pending_before, "finish_refill also preserves source and nested intent/buff values")
    var events: Array = result.get("events", [])
    if events.size() >= 3:
        check(events[1] == {"type": "healed", "raw": 11, "effective": 4}, "settlement healing equals earlier accrual plus displayed effective increment")
    var capped := Fixtures.combat("hall1", 1, 72, 9)
    var color := CombatV2.preview(Fixtures.chain(12), capped, 1)
    var gained: Dictionary = CombatV2.apply_action(capped, color).get("state", capped)
    check(gained.energy - capped.energy == color.get("energy_effective", -1) and gained.energy == 10,
        "actual immediate energy gain equals the displayed capped gain")
    var solo_snap := Fixtures.snapshot([Fixtures.tile(1, "blue", 0, Vector2.ZERO, 1)])
    var solo := CombatV2.preview(solo_snap, capped, 1)
    var detonated: Dictionary = CombatV2.apply_action(capped, solo).get("state", capped)
    check(detonated.actions_left == 2 and detonated.pending_damage == 0 and detonated.energy == 9,
        "solo bomb actually consumes exactly one action without color rewards")
    var buffed := Fixtures.combat()
    buffed.actions_left = 1
    buffed.bomb_buff = {"active": true, "paid_cost": 6, "generated_count": 2, "refunded": false}
    var previous: Dictionary = settled(buffed, 3, "heart").get("state", buffed)
    check(previous.energy == 4 and previous.bomb_buff.generated_count == 2 and not previous.bomb_buff.refunded,
        "bombs from earlier refills prevent a zero-final-refill refund")
    var snapshot := Fixtures.chain(8)
    var snapshot_before := snapshot.duplicate(true)
    seed(512987)
    var expected := randi()
    seed(512987)
    var first := CombatV2.preview(snapshot, state, 1)
    for i in range(10):
        check(CombatV2.preview(snapshot, state, 1) == first, "combat preview is deterministic")
    CombatV2.apply_action(state, first)
    CombatV2.finish_refill(pending, 0)
    check(randi() == expected and snapshot == snapshot_before and state == before,
        "pure combat preview/application/refill consume no global RNG and mutate no input")

func run() -> void:
    inspect_fresh_and_intent()
    inspect_rewards()
    inspect_actions_and_turns()
    inspect_resolution_and_weakening()
    inspect_buff_refund()
    inspect_purity_and_effective_rewards()
    print(JSON.stringify({"suite": "v2 pure combat", "checks": checks, "failures": failures}))
    quit(0 if failures == 0 else 1)

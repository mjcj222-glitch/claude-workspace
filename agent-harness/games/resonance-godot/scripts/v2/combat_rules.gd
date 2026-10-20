extends RefCounted
## Pure combat accrual and one-time settled-refill resolution.
## Board-version validation belongs to the caller's authoritative preview session.

const Config = preload("res://scripts/v2/config.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")

static func fresh(context: Dictionary) -> Dictionary:
    var enemy_id := str(context.get("enemy_id", ""))
    if not Config.ENEMIES.has(enemy_id):
        return {}
    return {"revision": 1, "enemy_id": enemy_id,
        "hp": clampi(int(context.get("hp", Config.START_HP)), 0, Config.MAX_HP),
        "enemy_hp": int(Config.ENEMIES[enemy_id].hp), "turn": 1,
        "actions_left": Config.ACTIONS_PER_TURN, "pending_damage": 0, "pending_heal": 0,
        "energy": clampi(int(context.get("energy", Config.START_ENERGY)), 0, Config.MAX_ENERGY),
        "party": context.get("party", ["hero"]).duplicate(true),
        "hero_limit": int(context.get("hero_limit", Config.HERO_START_LIMIT)), "team_skill_used": false,
        "bomb_buff": {"active": false, "paid_cost": 0, "generated_count": 0, "refunded": false},
        "intent": intent(enemy_id, 1), "refill_pending": false, "status": "active"}

static func intent(enemy_id: String, turn: int, weakened: bool = false) -> Dictionary:
    if not Config.ENEMIES.has(enemy_id) or turn < 1:
        return {}
    var enemy: Dictionary = Config.ENEMIES[enemy_id]
    var scheduled_strong := int(enemy.strong_every) > 0 and turn % int(enemy.strong_every) == 0
    var strong := scheduled_strong and not weakened
    var base := int(enemy.strong if strong else enemy.normal)
    var pressure := Config.PRESSURE_PER_TURN * maxi(0, turn - Config.PRESSURE_START_TURN)
    return {"kind": "strong" if strong else "normal", "base_damage": base,
        "pressure": pressure, "total_damage": base + pressure, "weakened": scheduled_strong and weakened}

static func _ready(state: Dictionary) -> bool:
    return state.get("status", "") == "active" and not state.get("refill_pending", false) and int(state.get("actions_left", 0)) > 0

static func preview(snapshot: Dictionary, state: Dictionary, seed_id: int) -> Dictionary:
    if not _ready(state):
        return {}
    var plan := Selection.preview(snapshot, seed_id, int(state.revision))
    if plan.is_empty():
        return {}
    var n := int(plan.direct_color_count)
    plan.direct_damage = 0
    plan.energy_raw = 0
    for reward in Config.GROUP_REWARDS:
        if n >= int(reward.minimum):
            plan.direct_damage = n * Config.DIRECT_DAMAGE_PER_PIECE + int(reward.damage_bonus)
            plan.energy_raw = int(reward.energy)
            break
    var pieces := {}
    for piece in snapshot.pieces:
        pieces[int(piece.id)] = piece
    plan.blast_damage = 0
    plan.healing_raw = 0
    for id in plan.removed_ids:
        if str(pieces[id].match_type) == "heart":
            plan.healing_raw += Config.HEAL_PER_PIECE
    for id in plan.extra_ids:
        if str(pieces[id].match_type) != "heart" and int(pieces[id].bomb_tier) == 0:
            plan.blast_damage += Config.BLAST_DAMAGE_PER_PIECE
    plan.healing_effective = mini(int(plan.healing_raw), maxi(0, Config.MAX_HP - int(state.hp) - int(state.pending_heal)))
    plan.energy_effective = mini(int(plan.energy_raw), maxi(0, Config.MAX_ENERGY - int(state.energy)))
    plan.weaken_intent = n >= int(Config.GROUP_REWARDS[0].minimum) and state.intent.kind == "strong"
    plan.refill_tier = 0
    if state.bomb_buff.active:
        plan.refill_tier = 1
        if n >= int(Config.GROUP_REWARDS[1].minimum):
            plan.refill_tier = 3
        elif n >= int(Config.GROUP_REWARDS[2].minimum):
            plan.refill_tier = 2
    return plan

static func _rejected(state: Dictionary) -> Dictionary:
    return {"ok": false, "state": state.duplicate(true), "events": []}

static func _complete_plan(plan: Dictionary) -> bool:
    for key in ["board_version", "combat_version", "seed_id", "mode", "direct_ids", "extra_ids", "removed_ids",
        "direct_color_count", "fired_bomb_ids", "blast_circles", "direct_damage", "blast_damage", "healing_raw",
        "healing_effective", "energy_raw", "energy_effective", "weaken_intent", "refill_tier"]:
        if not plan.has(key):
            return false
    if not ["color", "heart", "solo_bomb"].has(plan.mode) or plan.removed_ids.is_empty():
        return false
    if plan.mode == "solo_bomb":
        if plan.direct_ids.size() != 1 or int(plan.direct_color_count) != 0:
            return false
    elif plan.direct_ids.size() < Config.MIN_GROUP:
        return false
    for key in ["direct_damage", "blast_damage", "healing_raw", "healing_effective", "energy_raw", "energy_effective"]:
        if int(plan[key]) < 0:
            return false
    return true

static func apply_action(state: Dictionary, plan: Dictionary) -> Dictionary:
    if not _ready(state) or not _complete_plan(plan) or int(plan.combat_version) != int(state.revision):
        return _rejected(state)
    var next := state.duplicate(true)
    next.revision += 1
    next.pending_damage += int(plan.direct_damage) + int(plan.blast_damage)
    next.pending_heal += int(plan.healing_raw)
    next.energy = mini(Config.MAX_ENERGY, int(next.energy) + int(plan.energy_effective))
    next.actions_left -= 1
    next.refill_pending = true
    if plan.weaken_intent and next.intent.kind == "strong":
        next.intent = intent(str(next.enemy_id), int(next.turn), true)
    return {"ok": true, "state": next, "events": [{"type": "action_applied",
        "direct_damage": int(plan.direct_damage), "blast_damage": int(plan.blast_damage),
        "healing_raw": int(plan.healing_raw), "healing_effective": int(plan.healing_effective),
        "energy_raw": int(plan.energy_raw), "energy_effective": int(plan.energy_effective),
        "weaken_intent": bool(plan.weaken_intent), "refill_tier": int(plan.refill_tier)}]}

static func finish_refill(state: Dictionary, generated_bombs: int) -> Dictionary:
    if state.get("status", "") != "active" or not state.get("refill_pending", false) or generated_bombs < 0:
        return _rejected(state)
    var next := state.duplicate(true)
    var events: Array = [{"type": "refill_finished", "generated_bombs": generated_bombs}]
    next.revision += 1
    next.refill_pending = false
    if next.bomb_buff.active:
        next.bomb_buff.generated_count += generated_bombs
    if int(next.actions_left) > 0:
        return {"ok": true, "state": next, "events": events}
    # Include the final actual refill before deciding whether to refund.
    if next.bomb_buff.active:
        if int(next.bomb_buff.generated_count) == 0 and not next.bomb_buff.refunded:
            var returned := mini(int(next.bomb_buff.paid_cost), Config.MAX_ENERGY - int(next.energy))
            next.energy += returned
            next.bomb_buff.refunded = true
            events.append({"type": "energy_refunded", "paid_cost": int(next.bomb_buff.paid_cost), "energy_effective": returned})
        next.bomb_buff.active = false
    var healed := mini(int(next.pending_heal), maxi(0, Config.MAX_HP - int(next.hp)))
    next.hp += healed
    events.append({"type": "healed", "raw": int(next.pending_heal), "effective": healed})
    var damage := mini(int(next.enemy_hp), int(next.pending_damage))
    next.enemy_hp -= damage
    events.append({"type": "player_attack", "raw": int(next.pending_damage), "effective": damage})
    next.pending_damage = 0
    next.pending_heal = 0
    if int(next.enemy_hp) == 0:
        next.status = "victory"
    else:
        var taken := mini(int(next.hp), int(next.intent.total_damage))
        next.hp -= taken
        events.append({"type": "enemy_attack", "intent": next.intent.duplicate(true), "effective": taken})
        if int(next.hp) == 0:
            next.status = "defeat"
    if next.status != "active":
        events.append({"type": "battle_ended", "status": next.status})
    else:
        next.turn += 1
        next.actions_left = Config.ACTIONS_PER_TURN
        next.team_skill_used = false
        next.intent = intent(str(next.enemy_id), int(next.turn))
        events.append({"type": "turn_started", "turn": int(next.turn), "intent": next.intent.duplicate(true)})
    return {"ok": true, "state": next, "events": events}

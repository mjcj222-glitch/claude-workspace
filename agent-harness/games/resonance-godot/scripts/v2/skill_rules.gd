extends RefCounted
## Pure skill previews and resource changes; the caller validates the live board
## version before applying the displayed plan and its type-only changes.

const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")

static func _available(state: Dictionary, actor_id: String) -> bool:
    return Config.SKILL_COSTS.has(actor_id) and state.get("party", []).has(actor_id) \
        and state.get("status", "") == "active" and not state.get("refill_pending", false) \
        and int(state.get("actions_left", 0)) > 0 and not state.get("team_skill_used", false) \
        and int(state.get("energy", 0)) >= int(Config.SKILL_COSTS[actor_id])

static func _ordinary(piece: Dictionary) -> bool:
    return Config.COLOR_TYPES.has(str(piece.match_type)) and int(piece.bomb_tier) == 0

static func preview(snapshot: Dictionary, state: Dictionary, actor_id: String, seed_id: int = -1, destination: String = "") -> Dictionary:
    if not _available(state, actor_id):
        return {}
    var changes := {}
    if actor_id == "bomber":
        seed_id = -1
        destination = ""
    else:
        var pieces := {}
        for piece in snapshot.pieces:
            pieces[int(piece.id)] = piece
        if not pieces.has(seed_id) or not _ordinary(pieces[seed_id]):
            return {}
        var source := str(pieces[seed_id].match_type)
        var limit := Config.GARDENER_LIMIT + 1
        if actor_id == "hero":
            if not Config.COLOR_TYPES.has(destination) or destination == source:
                return {}
            limit = clampi(int(state.hero_limit), Config.HERO_START_LIMIT, Config.HERO_MAX_LIMIT)
        else:
            destination = "heart"
        var edges := Geometry.graph(snapshot)
        var seen := {seed_id: true}
        var frontier: Array = [seed_id]
        while not frontier.is_empty() and changes.size() < limit:
            frontier.sort()
            var next_frontier: Array = []
            for id in frontier:
                changes[id] = destination
                if changes.size() == limit:
                    break
                for neighbor in edges[id]:
                    if seen.has(neighbor):
                        continue
                    seen[neighbor] = true
                    if not _ordinary(pieces[neighbor]):
                        continue
                    if actor_id == "hero" and str(pieces[neighbor].match_type) != source:
                        continue
                    next_frontier.append(neighbor)
            frontier = next_frontier
    return {"board_version": int(snapshot.version), "combat_version": int(state.revision),
        "actor_id": actor_id, "seed_id": seed_id, "destination": destination,
        "cost": int(Config.SKILL_COSTS[actor_id]), "changes": changes}

static func _complete_plan(plan: Dictionary, state: Dictionary) -> bool:
    for key in ["board_version", "combat_version", "actor_id", "seed_id", "destination", "cost", "changes"]:
        if not plan.has(key):
            return false
    var actor_id := str(plan.actor_id)
    if not _available(state, actor_id) or int(plan.combat_version) != int(state.revision) \
        or int(plan.cost) != int(Config.SKILL_COSTS[actor_id]) or not plan.changes is Dictionary:
        return false
    if actor_id == "bomber":
        return plan.changes.is_empty() and int(plan.seed_id) == -1 and str(plan.destination) == ""
    var limit := Config.GARDENER_LIMIT + 1 if actor_id == "gardener" else clampi(int(state.hero_limit), Config.HERO_START_LIMIT, Config.HERO_MAX_LIMIT)
    var destination := str(plan.destination)
    if plan.changes.is_empty() or plan.changes.size() > limit or not plan.changes.has(int(plan.seed_id)):
        return false
    if (actor_id == "hero" and not Config.COLOR_TYPES.has(destination)) or (actor_id == "gardener" and destination != "heart"):
        return false
    for type in plan.changes.values():
        if type != destination:
            return false
    return true

static func apply(state: Dictionary, skill_plan: Dictionary) -> Dictionary:
    if not _complete_plan(skill_plan, state):
        return {"ok": false, "state": state.duplicate(true), "events": []}
    var next := state.duplicate(true)
    var actor_id := str(skill_plan.actor_id)
    next.revision += 1
    next.energy -= int(skill_plan.cost)
    next.team_skill_used = true
    if actor_id == "bomber":
        next.bomb_buff = {"active": true, "paid_cost": int(skill_plan.cost), "generated_count": 0, "refunded": false}
    return {"ok": true, "state": next, "events": [{"type": "skill_applied", "actor_id": actor_id,
        "cost": int(skill_plan.cost), "changes": skill_plan.changes.duplicate(true)}]}

static func decorate_refill(batch: Array, state: Dictionary, trigger_plan: Dictionary) -> Dictionary:
    var result := {"batch": batch.duplicate(true), "generated_bombs": 0}
    if state.get("status", "") != "active" or not state.get("refill_pending", false) \
        or not state.get("bomb_buff", {}).get("active", false) \
        or int(trigger_plan.get("combat_version", -1)) != int(state.revision) - 1:
        return result
    var tier := int(trigger_plan.get("refill_tier", 0))
    if not Config.BOMB_RADIUS_MULTIPLIERS.has(tier):
        return result
    for piece in result.batch:
        if str(piece.match_type) == "blue" and int(piece.bomb_tier) == 0:
            piece.bomb_tier = tier
            result.generated_bombs += 1
    return result

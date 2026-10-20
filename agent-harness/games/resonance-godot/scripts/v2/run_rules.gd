extends RefCounted
## Pure three-battle progression. All accepted changes return a new RunState.
const Config = preload("res://scripts/v2/config.gd")
const BATTLE_STAGES := ["battle1", "battle2", "battle3"]

static func fresh(seed: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var seeds: Array = []
    for index in range(Config.BATTLE_COUNT):
        seeds.append(rng.randi())
    return {"revision":1,"seed":seed,"stage":"battle1","route":"","party":["hero"],
        "hero_limit":Config.HERO_START_LIMIT,"hp":Config.START_HP,"energy":Config.START_ENERGY,
        "battle_seeds":seeds,"applied_choices":[],"completed_battles":[]}

static func battle_context(run: Dictionary) -> Dictionary:
    var index := BATTLE_STAGES.find(run.get("stage",""))
    if index < 0: return {}
    var enemy := "hall1"
    if index == 1:
        if run.get("route","") not in ["safe","risk"]: return {}
        enemy = "hall2_" + str(run.route)
    elif index == 2:
        enemy = "gate"
    return {"enemy_id":enemy,"seed":run.battle_seeds[index],"hp":run.hp,
        "energy":run.energy,"party":run.party.duplicate(true),"hero_limit":run.hero_limit,"reduced":false}

static func _rejected(run: Dictionary) -> Dictionary:
    return {"ok":false,"state":run.duplicate(true),"events":[]}

static func _accepted(next: Dictionary, events: Array) -> Dictionary:
    next.revision += 1
    return {"ok":true,"state":next,"events":events}

static func _owned_battle(run: Dictionary, battle: Dictionary) -> bool:
    var context := battle_context(run)
    if context.is_empty() or battle.get("enemy_id","") != context.enemy_id:
        return false
    if battle.get("party",[]) != run.party or battle.get("hero_limit",0) != run.hero_limit:
        return false
    for key in ["hp","energy"]:
        if not battle.has(key) or typeof(battle[key]) != TYPE_INT: return false
    return int(battle.hp) >= 0 and int(battle.hp) <= Config.MAX_HP \
        and int(battle.energy) >= 0 and int(battle.energy) <= Config.MAX_ENERGY \
        and battle.get("status","") in ["active","victory","defeat"]

static func sync_battle(run: Dictionary, battle: Dictionary) -> Dictionary:
    if not _owned_battle(run,battle): return _rejected(run)
    var next := run.duplicate(true)
    next.hp = battle.hp
    next.energy = battle.energy
    return _accepted(next,[])

static func complete_battle(run: Dictionary, battle: Dictionary) -> Dictionary:
    if not _owned_battle(run,battle) or str(run.stage) in run.completed_battles \
        or battle.get("refill_pending",true): return _rejected(run)
    var status := str(battle.status)
    if status == "active" or (status == "victory" and (int(battle.hp) == 0 or int(battle.get("enemy_hp",-1)) != 0)) \
        or (status == "defeat" and int(battle.hp) != 0): return _rejected(run)
    var next := run.duplicate(true)
    next.hp = battle.hp
    next.energy = battle.energy
    next.completed_battles.append(str(run.stage))
    var events: Array = [{"type":"battle_completed","battle_id":run.stage,"status":status}]
    if status == "defeat":
        next.stage = "lost"
    elif run.stage == "battle1":
        next.stage = "route_choice"
    elif run.stage == "battle2":
        if run.route == "risk":
            next.hero_limit = mini(Config.HERO_MAX_LIMIT,int(next.hero_limit)+Config.RISK_LIMIT_BONUS)
            events.append({"type":"hero_limit_increased","hero_limit":next.hero_limit})
        next.stage = "recruit_choice"
    else:
        next.stage = "completed"
    return _accepted(next,events)

static func choose_route(run: Dictionary, choice: String) -> Dictionary:
    if run.get("stage","") != "route_choice" or "route_choice" in run.applied_choices \
        or choice not in ["safe","risk"]: return _rejected(run)
    var next := run.duplicate(true)
    next.applied_choices.append("route_choice")
    next.route = choice
    next.stage = "battle2"
    var healed := 0
    if choice == "safe":
        healed = mini(Config.SAFE_ROUTE_HEAL,Config.MAX_HP-int(next.hp))
        next.hp += healed
    return _accepted(next,[{"type":"route_chosen","choice":choice,"healing_effective":healed}])

static func choose_recruit(run: Dictionary, choice: String) -> Dictionary:
    if run.get("stage","") != "recruit_choice" or "recruit_choice" in run.applied_choices \
        or choice not in ["bomber","gardener","skip"] or run.party != ["hero"]: return _rejected(run)
    var next := run.duplicate(true)
    next.applied_choices.append("recruit_choice")
    next.stage = "battle3"
    if choice == "skip":
        next.hero_limit = mini(Config.HERO_MAX_LIMIT,int(next.hero_limit)+Config.DECLINE_LIMIT_BONUS)
    else:
        next.party.append(choice)
    var minimum := int(Config.SKILL_COSTS["hero" if choice == "skip" else choice])
    var added := maxi(0,minimum-int(next.energy))
    next.energy += added
    return _accepted(next,[{"type":"recruit_chosen","choice":choice,"energy_effective":added}])

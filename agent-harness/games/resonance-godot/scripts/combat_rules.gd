class_name CombatRules
extends RefCounted

static func fresh() -> Dictionary:
    return {"hp":180,"enemy_hp":620,"turn":1,"taps":3,"pending_damage":0,"pending_heal":0,
        "gauge":0,"boost":false,"echo":[],"ready":[1,1,1],"prism":false,"ignition":false,"shield":0,"status":"playing"}

static func index(snapshot: Array) -> Dictionary:
    var result := {}
    for tile in snapshot: result[int(tile.id)] = tile
    return result

static func preview(snapshot: Array, edges: Dictionary, selected: int, state: Dictionary) -> Dictionary:
    var tiles := index(snapshot)
    if not tiles.has(selected): return {}
    var first: Dictionary = tiles[selected]
    var initial: Array = [selected]
    var cursor := 0
    while cursor < initial.size():
        for neighbor in edges.get(initial[cursor],[]):
            if tiles[neighbor].color == first.color and not initial.has(neighbor): initial.append(neighbor)
        cursor += 1
    var echo_hit := false
    for id_value in initial:
        if state.echo.has(id_value): echo_hit = true
    var removed: Array = initial.duplicate()
    if echo_hit:
        for id_value in state.echo:
            if tiles.has(int(id_value)) and not removed.has(int(id_value)): removed.append(int(id_value))
    cursor = 0
    var bombs := 0
    var megas := 0
    while cursor < removed.size():
        var item: Dictionary = tiles[removed[cursor]]
        var targets: Array = []
        if item.kind == "bomb" or item.kind == "mega":
            bombs += 1
            targets = edges.get(int(item.id),[]).duplicate()
            if item.kind == "mega":
                megas += 1
                if item.color == 0:
                    for id_value in targets.duplicate():
                        for other in edges[id_value]:
                            if not targets.has(other): targets.append(other)
                else:
                    for other in snapshot:
                        var delta: float = absf(item.y-other.y) if item.color == 1 else absf(item.x-other.x)
                        if delta <= 58.0 and not targets.has(int(other.id)): targets.append(int(other.id))
        for id_value in targets:
            if not removed.has(id_value): removed.append(id_value)
        cursor += 1
    var damage := 0
    var healing := 0
    for id_value in removed:
        var item: Dictionary = tiles[id_value]
        if item.color == 3: healing += 6
        else: damage += 5
        if item.kind == "charge": damage += 24
    damage *= 2 if state.boost else 1
    var prism_bonus := (24 if echo_hit else 12) if state.prism and first.color != 3 else 0
    var ignition_bonus := mini(bombs,3)*10 if state.ignition else 0
    damage += prism_bonus+ignition_bonus
    var special := {}
    var marks: Array = []
    if first.color != 3 and initial.size() >= 5:
        special = first.duplicate()
        special.kind = "mega" if initial.size() >= 8 else "charge"
        var candidates: Array = []
        for id_value in initial:
            for neighbor in edges[id_value]:
                if not candidates.has(neighbor): candidates.append(neighbor)
        candidates.sort_custom(func(a,b): return tiles[a].x < tiles[b].x if tiles[a].x != tiles[b].x else tiles[a].y < tiles[b].y)
        for id_value in candidates:
            if not removed.has(id_value) and tiles[id_value].color != 3 and tiles[id_value].kind == "normal" and marks.size() < 8:
                marks.append(id_value)
    return {"initial":initial,"removed":removed,"color":first.color,"damage":damage,"healing":healing,
        "special":special,"echo":marks,"echo_hit":echo_hit,"bombs":bombs,"megas":megas,"prism_bonus":prism_bonus,"ignition_bonus":ignition_bonus}

static func apply(state: Dictionary, plan: Dictionary) -> Dictionary:
    var result := {"attack":0,"blocked":0,"healed":0,"enemy_damage":0}
    state.pending_damage += plan.damage
    state.pending_heal += plan.healing
    state.echo = plan.echo.duplicate()
    if plan.prism_bonus: state.prism = false
    if plan.ignition_bonus: state.ignition = false
    if not state.boost: state.gauge = mini(55,state.gauge+plan.removed.size())
    state.taps -= 1
    if state.taps == 0:
        result.healed = mini(180-state.hp,state.pending_heal)
        state.hp += result.healed
        result.enemy_damage = mini(state.enemy_hp,state.pending_damage)
        state.enemy_hp -= result.enemy_damage
        if state.enemy_hp == 0: state.status = "won"
        else:
            var incoming := 14 if int(state.turn)%2 == 1 else 20
            result.blocked = mini(incoming,state.shield)
            result.attack = incoming-result.blocked
            state.shield = 0
            state.hp = maxi(0,state.hp-result.attack)
            if state.hp == 0: state.status = "lost"
        if state.status == "playing":
            state.turn += 1
            state.taps = 3
            state.pending_damage = 0
            state.pending_heal = 0
            state.boost = false
    return result

static func candidates(snapshot: Array, skill: int) -> Array:
    var ids: Array = []
    for tile in snapshot:
        if tile.kind == "mega": continue
        if skill == 0 and tile.color == 2 or skill > 0 and tile.kind == "normal" and tile.color != 3:
            ids.append(int(tile.id))
            if skill > 0 and ids.size() == (2 if skill == 1 else 6): break
    return ids

static func can_skill(snapshot: Array, state: Dictionary, skill: int) -> bool:
    return skill >= 0 and skill < 3 and state.status == "playing" and state.turn >= state.ready[skill] and not candidates(snapshot,skill).is_empty()

static func apply_skill(state: Dictionary, skill: int) -> void:
    state.ready[skill] = state.turn+3
    if skill == 0: state.prism = true
    elif skill == 1: state.ignition = true
    else: state.shield = 18

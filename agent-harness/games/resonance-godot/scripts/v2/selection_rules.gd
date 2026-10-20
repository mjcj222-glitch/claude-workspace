extends RefCounted
## Pure selection from a settled snapshot; never allocates pieces or refills.

const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")

static func _index(snapshot: Dictionary) -> Dictionary:
    var by_id: Dictionary={}
    for item in snapshot.pieces:by_id[int(item.id)]=item
    return by_id
static func preview(snapshot: Dictionary,seed_id: int,combat_version: int) -> Dictionary:
    var by_id:=_index(snapshot)
    if not by_id.has(seed_id):return {}
    return _evaluate(snapshot,seed_id,combat_version,by_id,Geometry.graph(snapshot,Config.MATCH_CONTACT_EPS))
static func has_selection(snapshot: Dictionary) -> bool:
    var by_id:=_index(snapshot)
    if by_id.is_empty():return false
    var edges:=Geometry.graph(snapshot,Config.MATCH_CONTACT_EPS)
    for item in snapshot.pieces:
        if not _evaluate(snapshot,int(item.id),0,by_id,edges).is_empty():return true
    return false
static func _evaluate(snapshot: Dictionary,seed_id: int,combat_version: int,by_id: Dictionary,edges: Dictionary) -> Dictionary:
    var type := str(by_id[seed_id].match_type)
    var direct := {seed_id: true}
    var queue: Array = [seed_id]
    var cursor := 0
    while cursor < queue.size():
        for neighbor in edges[queue[cursor]]:
            if not direct.has(neighbor) and str(by_id[neighbor].match_type) == type:
                direct[neighbor] = true
                queue.append(neighbor)
        cursor += 1
    var mode := "heart" if type == "heart" else "color"
    if direct.size() < Config.MIN_GROUP:
        if type != "blue" or int(by_id[seed_id].bomb_tier) == 0:
            return {}
        mode = "solo_bomb"
        direct = {seed_id: true}
    var direct_ids: Array = direct.keys()
    direct_ids.sort()
    var removed := direct.duplicate()
    var fired := {}
    var circles := {}
    queue = direct_ids.duplicate()
    cursor = 0
    var d := Geometry.diameter_unit()
    while cursor < queue.size():
        var id := int(queue[cursor])
        cursor += 1
        var bomb: Dictionary = by_id[id]
        var tier := int(bomb.bomb_tier)
        if tier == 0 or fired.has(id):
            continue
        fired[id] = true
        var radius: float = d * Config.BOMB_RADIUS_MULTIPLIERS[tier]
        circles[id] = {"id": id, "x": bomb.x, "y": bomb.y, "radius": radius}
        for other_id in by_id:
            var other: Dictionary = by_id[other_id]
            # Snapshot scalars retain float64 precision; Vector2 would round an
            # exact boundary outward on standard single-precision Godot builds.
            var dx := float(other.x) - float(bomb.x)
            var dy := float(other.y) - float(bomb.y)
            if sqrt(dx * dx + dy * dy) <= radius and not removed.has(other_id):
                removed[other_id] = true
                queue.append(other_id)
    var removed_ids: Array = removed.keys()
    removed_ids.sort()
    var extra_ids: Array = []
    for id in removed_ids:
        if not direct.has(id):
            extra_ids.append(id)
    var fired_ids: Array = fired.keys()
    fired_ids.sort()
    var blast_circles: Array = []
    for id in fired_ids:
        blast_circles.append(circles[id])
    return {"board_version": int(snapshot.version), "combat_version": combat_version,
        "seed_id": seed_id, "mode": mode, "direct_ids": direct_ids, "extra_ids": extra_ids,
        "removed_ids": removed_ids, "direct_color_count": direct_ids.size() if mode == "color" else 0,
        "fired_bomb_ids": fired_ids, "blast_circles": blast_circles}

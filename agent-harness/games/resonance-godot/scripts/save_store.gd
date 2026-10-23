class_name ResonanceSave
extends RefCounted
const Geometry = preload("res://scripts/piece_geometry.gd")

static func whole(value: Variant, low: int, high: int) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=low and value<=high

static func decode(raw: String) -> Dictionary:
    var data = JSON.parse_string(raw)
    if not data is Dictionary or data.get("version") != 1: return {}
    if not data.get("snapshot") is Array or data.snapshot.size()!=42 or not data.get("state") is Dictionary: return {}
    if not whole(data.get("seed"),0,4294967295) or not whole(data.get("next_id"),43,10000000): return {}
    if not data.get("rng_state") is String or not data.rng_state.is_valid_int() or not data.get("reduced") is bool: return {}
    var state: Dictionary = data.state
    var ranges := {"hp":[0,180],"enemy_hp":[0,620],"turn":[1,10000],"taps":[0,3],"pending_damage":[0,100000],"pending_heal":[0,100000],"gauge":[0,55],"shield":[0,18]}
    for key in ranges:
        if not whole(state.get(key),ranges[key][0],ranges[key][1]): return {}
        state[key] = int(state[key])
    for key in ["boost","prism","ignition"]:
        if not state.get(key) is bool: return {}
    if not state.shield in [0,18]: return {}
    if not state.get("status") in ["playing","won","lost"]: return {}
    if state.status=="playing" and (state.hp==0 or state.enemy_hp==0 or state.taps==0): return {}
    if state.status=="won" and (state.enemy_hp!=0 or state.taps!=0): return {}
    if state.status=="lost" and (state.hp!=0 or state.enemy_hp==0 or state.taps!=0): return {}
    if not state.get("ready") is Array or state.ready.size()!=3: return {}
    for i in range(3):
        if not whole(state.ready[i],1,state.turn+3): return {}
        state.ready[i] = int(state.ready[i])
    var seen := {}
    var polygons: Array = []
    var grounded: Array = []
    for item in data.snapshot:
        if not item is Dictionary: return {}
        if not whole(item.get("id"),1,data.next_id-1) or seen.has(int(item.id)) or not whole(item.get("color"),0,3): return {}
        if not item.get("kind") in ["normal","charge","bomb","mega"] or item.kind=="mega" and item.color==3: return {}
        for key in ["size","x","y","angle"]:
            if not (item.get(key) is int or item.get(key) is float) or not is_finite(float(item[key])): return {}
        if item.size<0.96 or item.size>1.04 or absf(item.angle)>10000: return {}
        item.id = int(item.id)
        item.color = int(item.color)
        var poly := Geometry.transformed(Geometry.polygon(item.color,item.size),Vector2(item.x,item.y),item.angle)
        for point in poly:
            if point.x < -0.8 or point.x > 600.8 or point.y < 0 or point.y > 580.8: return {}
        for point in poly:
            if point.y >= 579.0 and not grounded.has(item.id): grounded.append(item.id)
        for prior in polygons:
            for overlap in Geometry2D.intersect_polygons(poly,prior):
                if Geometry.area(overlap)>32.0: return {}
        polygons.append(poly)
        seen[item.id] = item
    var edges := Geometry.graph(data.snapshot)
    var cursor := 0
    while cursor < grounded.size():
        for other in edges[grounded[cursor]]:
            if not grounded.has(other): grounded.append(other)
        cursor += 1
    if grounded.size()!=42: return {}
    if not state.get("echo") is Array or state.echo.size()>8: return {}
    var echo_ids := {}
    for i in range(state.echo.size()):
        if not whole(state.echo[i],1,data.next_id-1): return {}
        var id_value := int(state.echo[i])
        if not seen.has(id_value) or echo_ids.has(id_value) or seen[id_value].color==3: return {}
        echo_ids[id_value] = true
        state.echo[i] = id_value
    return data

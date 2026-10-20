extends RefCounted

const Geometry = preload("res://scripts/v2/geometry.gd")
const Config = preload("res://scripts/v2/config.gd")

static func tile(id: int, type: String, hull_id: int, center: Vector2, bomb_tier: int = 0) -> Dictionary:
    return {"id": id, "hull_id": hull_id, "match_type": type, "size": 1.0,
        "x": center.x, "y": center.y, "angle": 0.0, "bomb_tier": bomb_tier}

static func snapshot(tiles: Array, version: int = 1) -> Dictionary:
    var ordered := tiles.duplicate(true)
    ordered.sort_custom(func(a, b): return a.id < b.id)
    return {"version": version, "pieces": ordered}

static func circle_diameter() -> float:
    var diameter := 0.0
    for point in Geometry.polygon(0): diameter = maxf(diameter, point.x * 2)
    return diameter

static func circle_step() -> float:
    return circle_diameter() + 0.5

static func chain(n: int, type: String = "red", bomb_tiers: Dictionary = {}) -> Dictionary:
    var tiles: Array = []
    for i in range(n):
        tiles.append(tile(i + 1, type, 0, Vector2(i * circle_step(), 100), int(bomb_tiers.get(i + 1, 0))))
    return snapshot(tiles)

static func combat(enemy_id: String = "hall1", turn: int = 1, hp: int = 72, energy: int = 4) -> Dictionary:
    var enemy: Dictionary = Config.ENEMIES[enemy_id]
    var strong := int(enemy.strong_every) > 0 and turn % int(enemy.strong_every) == 0
    var base := int(enemy.strong if strong else enemy.normal)
    var pressure := Config.PRESSURE_PER_TURN * maxi(0, turn - Config.PRESSURE_START_TURN)
    return {"revision": 1, "enemy_id": enemy_id, "hp": hp, "enemy_hp": int(enemy.hp),
        "turn": turn, "actions_left": Config.ACTIONS_PER_TURN, "pending_damage": 0, "pending_heal": 0,
        "energy": energy, "party": ["hero"], "hero_limit": Config.HERO_START_LIMIT, "team_skill_used": false,
        "bomb_buff": {"active": false, "paid_cost": 0, "generated_count": 0, "refunded": false},
        "intent": {"kind": "strong" if strong else "normal", "base_damage": base, "pressure": pressure, "total_damage": base + pressure, "weakened": false},
        "refill_pending": false, "status": "active"}

extends RefCounted
## All contact edges use the same fixed hull as drawing and physics.

const Config = preload("res://scripts/v2/config.gd")
const Base = preload("res://scripts/piece_geometry.gd")
const HULL_MAP := [0, 2, 1, 3]
const CONTACT_EPS := Config.CONTACT_EPS

static func polygon(hull_id: int, size: float = 1.0) -> PackedVector2Array:
    return Base.polygon(HULL_MAP[hull_id], size * Config.BASE_HULL_SCALE)

static func transformed(points: PackedVector2Array, origin: Vector2, angle: float) -> PackedVector2Array:
    return Base.transformed(points, origin, angle)

static func distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
    return Base.distance(a, b)

static func area(points: PackedVector2Array) -> float:
    return Base.area(points)

static func diameter_unit() -> float:
    var sum := 0.0
    for hull in range(Config.HULL_COUNT):
        var points := polygon(hull, 1.0)
        var diameter := 0.0
        for a in points:
            for b in points:
                diameter = maxf(diameter, a.distance_to(b))
        sum += diameter
    return sum / Config.HULL_COUNT

static func graph(snapshot: Dictionary) -> Dictionary:
    var edges := {}
    var polygons := {}
    var bounds := {}
    var pieces: Array = snapshot.pieces
    for item in pieces:
        var id := int(item.id)
        edges[id] = []
        var poly := transformed(polygon(int(item.hull_id), float(item.size)), Vector2(item.x, item.y), float(item.angle))
        polygons[id] = poly
        var rect := Rect2(poly[0], Vector2.ZERO)
        for point in poly:
            rect = rect.expand(point)
        bounds[id] = rect.grow(CONTACT_EPS)
    for i in range(pieces.size()):
        var a := int(pieces[i].id)
        for j in range(i):
            var b := int(pieces[j].id)
            if not bounds[a].intersects(bounds[b], true):
                continue
            if distance(polygons[a], polygons[b]) <= CONTACT_EPS:
                edges[a].append(b)
                edges[b].append(a)
    for ids in edges.values():
        ids.sort()
    return edges

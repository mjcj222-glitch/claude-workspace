class_name PieceGeometry
extends RefCounted

const CONTACT_EPS := 1.0
const COLORS := [Color("ee426c"), Color("ffc735"), Color("24bce5"), Color("38c88c")]
const NAMES := ["불꽃", "별빛", "물방울", "회복"]

static func polygon(kind: int, size_factor: float = 1.0) -> PackedVector2Array:
    var points := PackedVector2Array()
    if kind == 0:
        for i in range(32):
            points.append(Vector2.from_angle(i * TAU / 32) * 38.0)
    elif kind == 1:
        for i in range(10):
            var radius := 51.0 if i % 2 == 0 else 29.0
            points.append(Vector2.from_angle(-PI / 2 + i * TAU / 10) * radius)
        points = soften(points, 0.12)
    elif kind == 2:
        for corner in range(4):
            var center := Vector2(20, 20).rotated(corner * PI / 2)
            for i in range(7):
                points.append(center + Vector2.from_angle(corner * PI / 2 + i * PI / 12) * 16.0)
    else:
        for side in [1.0, -1.0]:
            for i in range(16):
                var t := i / 16.0
                var a := Vector2(0, -47 * side)
                var b := Vector2(67 * side, 0)
                var c := Vector2(0, 47 * side)
                points.append(a * pow(1-t, 2) + b * 2*(1-t)*t + c*t*t)
    for i in range(points.size()):
        points[i] *= size_factor
    return points

static func soften(points: PackedVector2Array, amount: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in range(points.size()):
        out.append(points[i].lerp(points[(i+1) % points.size()], amount))
        out.append(points[i].lerp(points[(i+1) % points.size()], 1-amount))
    return out

static func transformed(points: PackedVector2Array, origin: Vector2, angle: float) -> PackedVector2Array:
    var result := PackedVector2Array()
    for p in points:
        result.append(origin + p.rotated(angle))
    return result

static func distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
    if Geometry2D.is_point_in_polygon(a[0], b) or Geometry2D.is_point_in_polygon(b[0], a):
        return 0.0
    var best := INF
    for i in range(a.size()):
        var a0 := a[i]
        var a1 := a[(i+1) % a.size()]
        for j in range(b.size()):
            var b0 := b[j]
            var b1 := b[(j+1) % b.size()]
            if Geometry2D.segment_intersects_segment(a0, a1, b0, b1) != null:
                return 0.0
            best = minf(best, a0.distance_squared_to(Geometry2D.get_closest_point_to_segment(a0, b0, b1)))
            best = minf(best, b0.distance_squared_to(Geometry2D.get_closest_point_to_segment(b0, a0, a1)))
    return sqrt(best)

static func area(points: PackedVector2Array) -> float:
    var sum := 0.0
    for i in range(points.size()):
        sum += points[i].cross(points[(i+1) % points.size()])
    return absf(sum) / 2.0

static func graph(snapshot: Array) -> Dictionary:
    var edges := {}
    for piece in snapshot:
        edges[int(piece.id)] = []
    for i in range(snapshot.size()):
        var a: Dictionary = snapshot[i]
        for j in range(i):
            var b: Dictionary = snapshot[j]
            if Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) > 112:
                continue
            var pa := transformed(polygon(int(a.color), a.size), Vector2(a.x, a.y), a.angle)
            var pb := transformed(polygon(int(b.color), b.size), Vector2(b.x, b.y), b.angle)
            if distance(pa, pb) <= CONTACT_EPS:
                edges[int(a.id)].append(int(b.id))
                edges[int(b.id)].append(int(a.id))
    for ids in edges.values():
        ids.sort()
    return edges

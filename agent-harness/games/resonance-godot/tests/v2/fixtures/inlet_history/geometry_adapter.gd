extends RefCounted
## Historical legality adapter: ignores the newer match argument, retaining frozen1.0.
const Frozen = preload("res://tests/v2/fixtures/inlet_history/geometry.gd")
const Base = Frozen.Base
const HULL_MAP = Frozen.HULL_MAP
const CONTACT_EPS = Frozen.CONTACT_EPS
static func polygon(hull_id: int, size: float = 1.0) -> PackedVector2Array: return Frozen.polygon(hull_id,size)
static func transformed(points: PackedVector2Array, origin: Vector2, angle: float) -> PackedVector2Array: return Frozen.transformed(points,origin,angle)
static func distance(a: PackedVector2Array, b: PackedVector2Array) -> float: return Frozen.distance(a,b)
static func area(points: PackedVector2Array) -> float: return Frozen.area(points)
static func diameter_unit() -> float: return Frozen.diameter_unit()
static func graph(snapshot: Dictionary, _new_match_margin: float = 1.0) -> Dictionary: return Frozen.graph(snapshot)

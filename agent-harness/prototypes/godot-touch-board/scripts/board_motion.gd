extends RefCounted
## Continuous circle packing. No row/column identity or grid matching.
const RADIUS := 37.0

static func _landing(x: float, radius: float, placed: Array, floor_y: float) -> float:
	var y := floor_y - radius
	for other in placed:
		var dx: float = absf(x - other.pos.x)
		var span: float = radius + other.radius
		if dx < span:
			y = minf(y, other.pos.y - sqrt(span * span - dx * dx))
	return y

static func _place(radius: float, placed: Array, bounds: Rect2, preferred_x: float, rng: RandomNumberGenerator) -> Vector2:
	var candidates: Array = [bounds.position.x + radius, bounds.end.x - radius, preferred_x]
	for i in range(12): candidates.append(rng.randf_range(bounds.position.x + radius, bounds.end.x - radius))
	for a in placed:
		candidates.append(a.pos.x + radius + a.radius)
		candidates.append(a.pos.x - radius - a.radius)
		# Circle-circle intersection produces real touching supports, not a slot grid.
		for b in placed:
			if a.id >= b.id: continue
			var d: float = a.pos.distance_to(b.pos)
			var reach: float = radius + a.radius
			if d > 0.01 and d <= reach * 2.0:
				var middle: Vector2 = (a.pos + b.pos) * 0.5
				var perpendicular: Vector2 = (b.pos - a.pos).normalized().orthogonal()
				var height := sqrt(maxf(0.0, reach * reach - d*d*0.25))
				candidates.append((middle + perpendicular * height).x)
				candidates.append((middle - perpendicular * height).x)
	var best := Vector2(preferred_x, -INF)
	var best_score := -INF
	for x in candidates:
		if x < bounds.position.x + radius - 0.001 or x > bounds.end.x - radius + 0.001: continue
		var y := _landing(x, radius, placed, bounds.end.y)
		# Prefer downward compaction; among equivalent supports retain horizontal position.
		var score := y - absf(x - preferred_x) * 0.005
		if score > best_score:
			best = Vector2(x, y)
			best_score = score
	return best

static func pack(panels: Array, bounds: Rect2, count: int, next_id: int, rng: RandomNumberGenerator) -> Dictionary:
	var placed: Array = []
	var survivors: Array = panels.duplicate(true)
	survivors.sort_custom(func(a, b): return a.pos.y > b.pos.y if not is_equal_approx(a.pos.y, b.pos.y) else a.id < b.id)
	for p in survivors:
		var old_pos: Vector2 = p.pos
		p.pos = _place(p.radius, placed, bounds, old_pos.x, rng)
		p.from = old_pos
		placed.append(p)
	while placed.size() < count:
		var preferred_x := rng.randf_range(bounds.position.x + RADIUS, bounds.end.x - RADIUS)
		var target := _place(RADIUS, placed, bounds, preferred_x, rng)
		var color := rng.randi_range(0, 4)
		placed.append({"id": next_id, "pos": target, "from": Vector2(target.x, bounds.position.y - RADIUS - (placed.size() % 4) * 38), "radius": RADIUS, "color": color, "kind": "heart" if color == 4 else "normal"})
		next_id += 1
	placed.sort_custom(func(a, b): return a.id < b.id)
	return {"panels": placed, "next_id": next_id}

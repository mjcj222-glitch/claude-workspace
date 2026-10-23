extends SceneTree
const Motion = preload("res://scripts/board_motion.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 421
	var bounds := Rect2(30, 290, 660, 530)
	var packed := Motion.initial_board(bounds, 48, 1, rng)
	check(packed.panels.size() == 48, "refill exact count")
	check(packed.next_id == 49, "IDs advance exactly once")
	var positions := {}
	for p in packed.panels:
		check(bounds.has_point(p.pos), "centers inside board")
		check(p.pos.y + p.radius <= bounds.end.y + 0.01, "floor containment")
		positions[p.id] = p.pos
		for q in packed.panels:
			if p.id < q.id:
				check(p.pos.distance_to(q.pos) >= p.radius + q.radius - 0.05, "no overlap")
	print("INITIAL MOTION failures=", failures)
	quit(1 if failures else 0)

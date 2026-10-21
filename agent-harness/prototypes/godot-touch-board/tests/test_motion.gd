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
	var packed := Motion.pack([], bounds, 48, 1, rng)
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
	var survivors: Array = packed.panels.slice(0, 24)
	if survivors.size() > 0:
		survivors[0].kind = "strong"
	var result := Motion.pack(survivors, bounds, 48, packed.next_id, rng)
	check(result.panels.size() == 48, "one refill restores count")
	check(result.next_id == 73, "only missing panels allocated")
	if survivors.size() > 0:
		check(result.panels[0].id == survivors[0].id and result.panels[0].kind == "strong", "survivor identity/special retained")
		check(survivors[0].pos == positions[survivors[0].id], "packing does not mutate snapshot")
	# Repeat partial refills: catch pile growth and exhausted capacity, not only first layout.
	for turn in range(100):
		var keep: Array = []
		for panel in result.panels:
			if rng.randf() > 0.3: keep.append(panel)
		result = Motion.pack(keep, bounds, 48, result.next_id, rng)
		for panel in result.panels:
			check(panel.pos.y - panel.radius >= bounds.position.y - 0.01, "100 refill board top containment")
			for other in result.panels:
				if panel.id < other.id: check(panel.pos.distance_to(other.pos) >= panel.radius + other.radius - 0.05, "100 refill nonoverlap")
	print("MOTION failures=", failures)
	quit(1 if failures else 0)

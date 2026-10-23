extends SceneTree
const Feedback = preload("res://scripts/board_feedback.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func _init() -> void:
	var source: Array = [
		{"id":1,"kind":"normal"},{"id":2,"kind":"heart"},
		{"id":3,"kind":"core"},{"id":4,"kind":"strong"},
		{"id":5,"kind":"normal"},{"id":3,"kind":"core"}]
	var plan: Dictionary = {"removed":[1,2,3,3,4,404],"activated":[3,3,4,404,1]}
	var original := plan.duplicate(true)
	var original_source := source.duplicate(true)
	var f = Feedback.new()
	f.start(plan,source)
	check(f.expected_count == 4, "canonical removed intersects real IDs, includes heart")
	check(f.total_cores == 2, "activation dedup and actual core kinds only")
	check(f.count == 0 and f.core_count == 0 and not f.finished and not f.visible, "start never pre-credits execution")
	check(not f.consume(404,Vector2.ZERO,Color.RED) and not f.consume(5,Vector2.ZERO,Color.RED), "unknown or surviving ID cannot count")
	check(f.consume(2,Vector2(30,50),Color.PINK), "heart counts as one removed panel")
	check(f.count == 1 and f.core_count == 0 and f.visible, "heart updates visible counter")
	check(not f.consume(2,Vector2.ZERO,Color.PINK) and f.count == 1, "repeated reachability never duplicates clear")
	check(f.consume(3,Vector2(70,90),Color.CYAN), "core consumes once")
	check(f.count == 2 and f.core_count == 1, "core activation is distinct counter")
	check(f.rings.size() >= 3, "core activation produces multiple local waves")
	var emitted: int = f.particles.size()
	f.finish()
	check(f.particles.size() == emitted, "finish reconciliation does not invent missing bursts")
	check(f.finished and f.count == 4 and f.core_count == 2, "finish reconciles missing sequence against canonical totals")
	check(not f.consume(1,Vector2.ZERO,Color.RED), "late events cannot restart finished effects")
	f.update(0.8)
	check(f.visible, "finished count remains readable")
	f.finish()
	f.update(1.3)
	check(not f.visible and f.particles.is_empty() and f.rings.is_empty(), "finish is idempotent and all visuals expire independently")
	f.reset()
	check(f.count == 0 and f.core_count == 0 and f.expected_count == 0 and f.total_cores == 0 and not f.finished and not f.visible, "reset clears accounting and presentation")
	f.finish()
	check(f.count == 0 and not f.visible and not f.finished, "finish after reset cannot credit cancelled execution")
	f.start(plan,source)
	f.consume(1,Vector2.ZERO,Color.RED)
	f.reset()
	check(not f.consume(3,Vector2.ZERO,Color.RED), "cancelled pending IDs cannot leak to next action")
	f.start({"removed":[5],"activated":[]},source)
	check(f.consume(5,Vector2.ZERO,Color.GOLD) and f.count == 1 and f.total_cores == 0, "next action starts clean")
	check(plan == original and source == original_source, "presentation never mutates rule plan or panels")
	f.start({"removed":[3],"activated":[]},source)
	check(f.count == 0 and f.particles.is_empty() and f.rings.is_empty(), "start discards previous action presentation")
	f.consume(3,Vector2.ZERO,Color.CYAN)
	check(f.count == 1 and f.core_count == 0, "special kind alone cannot fabricate activation")
	var age: float = f.particles[0].age
	f.update(-1.0)
	check(f.particles[0].age == age, "negative delta cannot rewind effects")
	f.start({"removed":[1,3],"activated":[3,4,4]},source)
	check(f.total_cores == 1, "surviving core in malformed activation list cannot contribute")
	f.finish()
	check(f.count == 2 and f.core_count == 1, "finish never fabricates surviving core activation")
	var wave_panels: Array = [{"id":1000,"kind":"core"}]
	var wave_ids: Array = [1000]
	for id in range(1001,1021):
		wave_panels.append({"id":id,"kind":"normal"})
		wave_ids.append(id)
	f.start({"removed":wave_ids,"activated":[1000]},wave_panels)
	f.consume(1000,Vector2.ZERO,Color.CYAN)
	for id in range(1001,1021): f.consume(id,Vector2(id,0),Color.RED)
	var priority_waves := 0
	for ring in f.rings:
		if ring.get("core_priority",false): priority_waves += 1
	check(priority_waves == 3, "ordinary burst pressure preserves all three core waves")
	check(f.rings.size() <= 24, "priority retention does not exceed ring budget")
	f.update(2.0)
	check(f.rings.is_empty(), "protected core waves still expire normally")
	var many: Array = []
	var ids: Array = []
	for id in range(500):
		many.append({"id":id,"kind":"core"})
		ids.append(id)
	f.start({"removed":ids,"activated":ids},many)
	for id in ids: f.consume(id,Vector2(id,0),Color.CYAN)
	check(f.count == 500 and f.core_count == 500, "visual budget cannot suppress actual accounting")
	check(f.particles.size() <= 320 and f.rings.size() <= 24, "effect objects stay bounded")
	f.update(3.0)
	check(f.particles.is_empty() and f.rings.is_empty(), "old effects expire even before finish")
	f.start({"removed":[],"activated":[]},source)
	f.finish()
	check(not f.visible and f.count == 0, "empty action never displays a fabricated count")
	print("FEEDBACK checks=",checks," failures=",failures)
	quit(1 if failures else 0)

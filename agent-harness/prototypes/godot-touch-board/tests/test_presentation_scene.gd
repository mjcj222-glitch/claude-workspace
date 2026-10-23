extends SceneTree
## Integration fixtures: real Rules -> session press/release -> scene _burst.
## Automatic scene processing is disabled. Explicit _burst/feedback.finish calls
## verify event wiring only, not natural animation timing or ready transitions.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func panel(id: int, point: Vector2, color: int, kind: String = "normal") -> Dictionary:
	return {"id":id,"pos":point,"radius":10.0,"color":color,"kind":kind}

func fixture(scene, panels: Array) -> void:
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	scene.session.panels = panels.duplicate(true)
	scene.visual = panels.duplicate(true)
	scene.session.next_id = 100
	scene.primary_touch = -99
	scene.target_hit = 0.0

func commit(scene, point: Vector2) -> Dictionary:
	var screen: Vector2 = scene.board_to_screen(point)
	scene.press(screen, -1)
	var preview: Dictionary = scene.session.selection.duplicate(true)
	scene.release(screen, -1)
	return preview

func expected_old_rng(state: int, panel_count: int) -> int:
	# Seven legacy particles per eligible unique _burst, two randf_range calls each.
	# This baseline catches any added presentation randomness using gameplay RNG.
	var baseline := RandomNumberGenerator.new()
	baseline.state = state
	for i in range(panel_count):
		for particle in range(7):
			baseline.randf_range(65, 180)
			baseline.randf_range(2, 6)
	return baseline.state

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	scene.record_timings = false
	scene.sound.muted = true
	await process_frame
	check(scene.feedback.get_script() == load("res://scripts/board_feedback.gd"), "actual scene owns production feedback module")
	var start := Vector2(250, 500)
	var hearts: Array = [panel(1,start,4,"heart"),panel(2,start+Vector2(20,0),4,"heart")]
	fixture(scene, hearts)
	var preview := commit(scene, start)
	check(preview.valid and preview.removed == [1,2] and preview.heal_raw == 4, "heart fixture uses actual two-heart Rules plan")
	check(scene.active_plan == preview, "heart release preserves exact preview as active plan")
	check(scene.feedback.count == 0 and not scene.feedback.visible and scene.feedback.expected_count == 2, "committing starts canonical eligible count without prematurely displaying removed count")
	var rng_before: int = scene.rng.state
	scene._burst(1,0)
	check(scene.feedback.count == 1 and scene.feedback.core_count == 0 and scene.feedback.visible, "actual heart clear event increments count once")
	check(scene.target_hit == 0.0, "heart clear does not trigger enemy hit")
	check(scene.rng.state == expected_old_rng(rng_before,1) and scene.particles.size() == 7, "first event preserves seven legacy particles and fourteen gameplay RNG draws")
	var rng_after_first: int = scene.rng.state
	var feedback_particles: int = scene.feedback.particles.size()
	scene._burst(1,0)
	scene._burst(999,1)
	check(scene.feedback.count == 1 and scene.feedback.particles.size() == feedback_particles, "duplicate and absent heart events add no feedback")
	check(scene.rng.state == rng_after_first and scene.particles.size() == 7, "duplicate and absent events add no legacy RNG or particles")
	scene._burst(2,1)
	scene.feedback.finish()
	check(scene.feedback.count == 2 and scene.feedback.core_count == 0 and scene.feedback.finished, "heart finish reports exactly two canonical removed panels")
	check(scene.rng.state == expected_old_rng(rng_before,2), "heart effects do not add gameplay RNG beyond legacy draws")
	check(scene.active_plan == preview and scene.session.actions == 1 and scene.session.hp == 18, "feedback leaves plan and canonical action/heal results unchanged")

	var chain: Array = [
		panel(10,start,0,"core"),
		panel(11,start+Vector2(20,0),1,"core"),
		panel(12,start+Vector2(40,0),3),
		panel(13,start+Vector2(60,0),1),
	]
	fixture(scene, chain)
	preview = commit(scene,start)
	check(preview.removed == [10,11,12,13] and preview.activated == [10,11] and preview.damage == 2, "multi-core fixture has two activations and four actual removals")
	check(scene.active_plan == preview and scene.feedback.expected_count == 4 and scene.feedback.total_cores == 2, "multi-core active plan and feedback eligibility match frozen preview")
	rng_before = scene.rng.state
	var seen: Array = []
	for id in preview.sequence:
		scene._burst(id,seen.size())
		seen.append(id)
		scene._burst(id,seen.size()-1)
		check(scene.feedback.count == seen.size(), "overlapping repeated event %d is deduplicated" % id)
	check(scene.feedback.core_count == 2 and scene.target_hit == 0.0, "each existing core counted once; enemy hit waits for delivery")
	scene.feedback.finish()
	scene.feedback.finish()
	check(scene.feedback.count == 4 and scene.feedback.core_count == 2, "repeated finish retains canonical four panels and two cores")
	check(scene.rng.state == expected_old_rng(rng_before,4) and scene.particles.size() == 28, "multi-core extra effects leave legacy gameplay RNG sequence unchanged")
	check(scene.active_plan == preview and scene.session.damage_total == 2 and scene.session.actions == 1, "multi-core feedback never changes damage/action/plan")

	var six: Array = []
	for i in range(6):
		six.append(panel(i,start+Vector2(20*i,0),0))
	fixture(scene,six)
	preview = commit(scene,start)
	check(preview.spawn.get("kind","") == "core" and preview.activated.is_empty(), "six-direct fixture creates protected core but activates none")
	for id in preview.sequence:
		scene._burst(id,id)
	scene._burst(100,6)
	scene.feedback.finish()
	check(scene.feedback.count == 6 and scene.feedback.core_count == 0, "new protected core never contributes to current removal or activation count")

	fixture(scene,[panel(1,start,0),panel(2,start+Vector2(20,0),0)])
	scene.press(scene.board_to_screen(start),-1)
	check(scene.session.selection.get("valid",false) and scene.feedback.count == 0 and not scene.feedback.visible, "preview alone shows no committed-effect count")
	scene.cancel_input()
	scene.release(scene.board_to_screen(start),-1)
	scene._burst(1,0)
	check(scene.feedback.count == 0 and scene.feedback.particles.is_empty() and scene.session.actions == 0, "canceled preview cannot trigger eligible clear feedback")
	scene.session.skill_mode = true
	scene.session.skill_color = 2
	var skill_preview := commit(scene,start)
	check(skill_preview.mode == "skill" and scene.session.panels[0].color == 2, "skill fixture executes actual shown conversion")
	check(scene.feedback.count == 0 and not scene.feedback.visible and scene.session.actions == 0, "skill conversion gives zero clear count and no action consumption")

	fixture(scene,hearts)
	commit(scene,start)
	scene._burst(1,0)
	check(scene.feedback.visible and not scene.feedback.particles.is_empty(), "reset fixture first has visible effects")
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	check(scene.feedback.count == 0 and scene.feedback.core_count == 0 and scene.feedback.expected_count == 0 and not scene.feedback.visible, "reset clears all counters and visibility")
	check(scene.feedback.particles.is_empty() and scene.feedback.rings.is_empty() and scene.particles.is_empty(), "reset clears both new and legacy effects")
	scene.feedback.finish()
	scene._burst(1,0)
	check(scene.feedback.count == 0 and not scene.feedback.visible, "late finish/event cannot resurrect reset feedback")
	scene.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	print("PRESENTATION SCENE fixture checks=",checks," failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
## Actual main scene, normal input routing and natural process/refill/attack.
## Uses legal greedy choices, never modifies board, RNG, HP, charge or phases.
## --capture labels MovieWriter output; absent it runs the same live flow.
const REWARDS := ["pigment", "lens"]
var scene
var events: Array = []
var errors: Array = []
var snapshots: Array = []
var output_dir := ""
var movie := false
var began_us := 0
var saw_attack := false
var saw_mitigation := false
var clear_count := 0

func _initialize() -> void:
	call_deferred("run")

func state() -> Dictionary:
	var s = scene.session
	var c = s.combat
	return {"phase":s.phase,"encounter":c.encounter,"enemy_hp":c.enemy_hp,
		"enemy_max_hp":c.enemy_max_hp,"turn":c.turn,"actions_in_turn":c.actions_in_turn,
		"incoming_damage":c.incoming_damage,"mitigation_active":c.mitigation_active,
		"mitigation_success":c.mitigation_success,"fallback_plain":c.fallback_plain,
		"attacks_total":c.attacks_total,"last_attack_damage":c.last_attack_damage,
		"enemies_defeated":c.enemies_defeated,"hp":s.hp,"charge":s.charge,
		"charge_required":s.charge_required,"actions":s.actions,"relics":s.relics.duplicate(),
		"ash_reserved":s.ash_reserved,"wall_ms":(Time.get_ticks_usec()-began_us)/1000.0,
		"process_frame":Engine.get_process_frames(),"scene_seconds":scene.time}

func record(type: String, details: Dictionary = {}) -> void:
	var entry := state()
	entry["type"] = type
	entry["details"] = details
	events.append(entry)
	print("CAPTURE_COMBAT ",JSON.stringify(entry))

func snapshot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(name+".png")
	var result: int = root.get_texture().get_image().save_png(path)
	if result != OK:
		errors.append("screenshot failed: "+name+" error="+str(result))
	else:
		snapshots.append(path)

func gesture(point: Vector2, hold: float = 0.25) -> Dictionary:
	scene.press(point,-1)
	var preview: Dictionary = scene.session.selection.duplicate(true)
	await create_timer(hold).timeout
	scene.release(point,-1)
	return preview

func direct_count(plan: Dictionary) -> int:
	var ids: Dictionary = {}
	for id in plan.get("direct",[]): ids[id] = true
	return ids.size()

func best_clear() -> Dictionary:
	var s = scene.session
	var best: Dictionary = {}
	var best_value := -INF
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false): continue
		var lethal: bool = plan.damage >= s.combat.enemy_hp
		# The actual combat condition counts unique direct IDs (including hearts
		# and existing cores), not only the new-core generation normal count.
		var mitigates: bool = s.combat.mitigation_active and not s.combat.mitigation_success and direct_count(plan)>=4
		var value: float = plan.damage*10.0+plan.removed.size()+plan.heal_effective*(15.0 if s.hp<=10 else 5.0)
		if lethal: value += 100000.0
		elif mitigates: value += 10000.0
		if value > best_value:
			best_value = value
			best = {"id":panel.id,"point":panel.pos,"plan":plan}
	return best

func best_skill() -> Dictionary:
	var s = scene.session
	var best: Dictionary = {}
	var best_value := -1
	for panel in s.panels:
		if panel.kind != "normal": continue
		for color in range(4):
			var plan: Dictionary = s.skill_plan_for(panel.id,color)
			if not plan.get("valid",false): continue
			var changed := 0
			for candidate in s.panels:
				if candidate.id in plan.targets and candidate.color != color: changed += 1
			if changed == 0: continue
			var value: int = plan.connected.size()*100+changed
			if value > best_value:
				best_value = value
				best = {"id":panel.id,"point":panel.pos,"color":color,"plan":plan}
	return best

func use_skill(skill: Dictionary) -> void:
	var actions_before: int = scene.session.actions
	await gesture(scene.SKILL.get_center(),0.12)
	if not scene.session.skill_mode:
		errors.append("ready skill button did not enter color selection")
		return
	await gesture(scene.UI.color_rect(skill.color).get_center(),0.12)
	var preview: Dictionary = await gesture(scene.board_to_screen(skill.point))
	if preview.get("mode","") != "skill" or not preview.get("valid",false) or preview.get("targets",[]) != skill.plan.targets:
		errors.append("skill legal preview differs from chosen plan")
	if scene.session.actions != actions_before or scene.session.skill_mode:
		errors.append("skill did not execute for free through UI")
	record("skill",{"start_id":skill.id,"color":skill.color,"targets":preview.get("targets",[]),"connected":preview.get("connected",[])})
	await create_timer(0.20).timeout

func wait_resolution() -> void:
	var deadline := Time.get_ticks_msec()+120000
	var attack_recorded := false
	while scene.session.phase in ["busy","enemy_attack"]:
		if Time.get_ticks_msec() > deadline:
			errors.append("natural animation/refill exceeded safety deadline")
			return
		if scene.session.phase == "enemy_attack" and not attack_recorded:
			attack_recorded = true
			saw_attack = true
			record("enemy_attack")
			await snapshot("attack-%02d"%scene.session.combat.attacks_total)
		await process_frame
	record("resolved")
	if scene.session.phase == "stalled":
		errors.append("natural refill stalled; no board rescue attempted")

func run() -> void:
	movie = "--capture" in OS.get_cmdline_user_args()
	output_dir = "res://evidence/combat/capture-movie" if movie else "res://evidence/combat/capture-live"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	began_us = Time.get_ticks_usec()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if scene.sandbox or scene.session.get("combat") == null:
		printerr("CAPTURE_COMBAT requires default actual-run mode, no --sandbox")
		quit(2)
		return
	record("initial")
	await snapshot("initial")
	await create_timer(1.6).timeout
	while scene.session.phase not in ["victory","defeat"] and clear_count < 120 and errors.is_empty():
		match scene.session.phase:
			"reward":
				record("reward_offer",{"options":scene.session.reward_options.duplicate()})
				await snapshot("reward-%d"%scene.session.reward_round)
				await create_timer(1.8).timeout
				var reward_index: int = scene.session.relics.size()
				if reward_index >= REWARDS.size():
					errors.append("unexpected additional reward")
					break
				var id: String = REWARDS[reward_index]
				var index: int = scene.session.reward_options.find(id)
				if index < 0:
					errors.append("intended earned reward not available: "+id)
					break
				await gesture(scene.UI.reward_rect(index,scene.session.reward_options.size()).get_center())
				if scene.session.phase != "between" or id not in scene.session.relics:
					errors.append("reward UI did not enter between state")
				record("reward_chosen",{"id":id})
			"between":
				await snapshot("between-%d"%(scene.session.combat.encounter+1))
				await create_timer(1.0).timeout
				var previous: int = scene.session.combat.encounter
				await gesture(scene.UI.SUMMARY_CONTINUE.get_center())
				if scene.session.phase != "ready" or scene.session.combat.encounter != previous+1:
					errors.append("explicit next-battle UI did not advance once")
				record("next_fight")
				await snapshot("nextfight-%d"%(scene.session.combat.encounter+1))
				await create_timer(0.8).timeout
			"ready":
				var selected := best_clear()
				if scene.session.charge >= scene.session.charge_required and (selected.is_empty() or selected.plan.damage < scene.session.combat.enemy_hp):
					var skill := best_skill()
					if not skill.is_empty():
						await use_skill(skill)
						selected = best_clear()
				if not errors.is_empty(): break
				if selected.is_empty():
					errors.append("normal board has no legal clear")
					break
				var before := state()
				var preview: Dictionary = await gesture(scene.board_to_screen(selected.point))
				if preview.is_empty() or preview != scene.active_plan or scene.session.actions != before.actions+1:
					errors.append("normal clear preview/execution mismatch")
					break
				clear_count += 1
				record("clear",{"start_id":selected.id,"direct":preview.direct,"removed":preview.removed,"damage":preview.damage,"heal_effective":preview.heal_effective,"before":before})
				if not before.mitigation_success and scene.session.combat.mitigation_success:
					saw_mitigation = true
					record("mitigation_success",{"direct_unique":direct_count(preview)})
					await snapshot("mitigation-%02d"%clear_count)
				await wait_resolution()
				if scene.session.phase == "ready": await create_timer(0.40).timeout
			_:
				errors.append("unexpected phase: "+scene.session.phase)
	if scene.session.phase == "victory":
		record("victory")
		await snapshot("victory")
		await create_timer(2.0).timeout
	else:
		record("stopped")
		await snapshot("stopped")
		if errors.is_empty(): errors.append("did not reach victory: "+scene.session.phase)
	if not saw_attack: errors.append("run did not demonstrate an actual counterattack")
	if not saw_mitigation: errors.append("run did not demonstrate mitigation success")
	var trace := {"method":"actual main.tscn, real press/release routing, natural _process/refill/attack; automated legal decisions, not hardware touch","movie":movie,"timing_note":"MovieWriter is fixed-frame evidence, not wall-clock performance; live timings include concurrent screenshot I/O" if movie else "live rendered wall-clock; screenshots/driver decisions add overhead, not a dedicated performance benchmark","seed":scene.run_seed,"rewards":REWARDS,"no_fixtures":true,"terminal":scene.session.phase,"errors":errors,"observed_counterattack":saw_attack,"observed_mitigation":saw_mitigation,"events":events,"timings":scene.timings.duplicate(true),"screenshots":snapshots,"final":state()}
	var file := FileAccess.open(output_dir.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"  "))
	print("CAPTURE_COMBAT terminal=",scene.session.phase," clears=",clear_count," errors=",errors)
	# Keep the final scene intact until shutdown; no gray teardown frames.
	quit(0 if errors.is_empty() else 1)

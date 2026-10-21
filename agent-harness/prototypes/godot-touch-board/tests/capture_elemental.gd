extends SceneTree
## Actual main scene, normal input routing and natural process/refill/attack.
## Uses legal greedy choices, never modifies board, RNG, HP, charge or phases.
## --capture labels MovieWriter output; absent it runs the same live flow.
const PAIRS := [["pigment","lens"],["pigment","ash"],["lens","ash"]]
var rewards: Array = PAIRS[0]
var pair_index := 0
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
var route_choice := "elite"
var selected_policy := "intent-aware"
var boss_turns_seen: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func state() -> Dictionary:
	var s = scene.session
	var c = s.combat
	return {"phase":s.phase,"encounter":c.encounter,"enemy_hp":c.enemy_hp,
		"enemy_max_hp":c.enemy_max_hp,"turn":c.turn,"actions_in_turn":c.actions_in_turn,
		"weak_color":c.weak_color,"combat_context":c.damage_context(),
		"incoming_damage":c.incoming_damage,"mitigation_active":c.mitigation_active,
		"mitigation_success":c.mitigation_success,"fallback_plain":c.fallback_plain,
		"attacks_total":c.attacks_total,"last_attack_damage":c.last_attack_damage,
		"enemies_defeated":c.enemies_defeated,"hp":s.hp,"charge":s.charge,
		"charge_required":s.charge_required,"actions":s.actions,"relics":s.relics.duplicate(),
		"ash_reserved":s.ash_reserved,"route":s.route,"gold":s.gold,"gold_spent":s.gold_spent,
		"shop_heal_sold":s.shop_heal_sold,"shop_relic_sold":s.shop_relic_sold,"shop_closed":s.shop_closed,"wall_ms":(Time.get_ticks_usec()-began_us)/1000.0,
		"process_frame":Engine.get_process_frames(),"scene_seconds":scene.time}

func record(type: String, details: Dictionary = {}) -> void:
	var entry := state()
	entry["type"] = type
	entry["details"] = details
	events.append(entry)
	print("CAPTURE_ELEMENTAL ",JSON.stringify(entry))

func snapshot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(name+".png")
	var result: int = root.get_texture().get_image().save_png(path)
	if result != OK:
		errors.append("screenshot failed: "+name+" error="+str(result))
	else:
		snapshots.append(path)

func gesture(point: Vector2, hold: float = 0.35) -> Dictionary:
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
		# Use the immutable planner result, including boss weakness criteria.
		var mitigates: bool = selected_policy == "intent-aware" and s.combat.mitigation_active and not s.combat.mitigation_success and plan.get("mitigates_intent",false)
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--route="): route_choice = arg.substr(8)
		if arg.begins_with("--policy="): selected_policy = arg.substr(9)
		if arg.begins_with("--pair="): pair_index = int(arg.substr(7))
	if route_choice not in ["safe","elite"] or selected_policy not in ["intent-aware","damage-first"] or pair_index not in [0,1,2]:
		printerr("route must be safe/elite; policy intent-aware/damage-first")
		quit(2)
		return
	rewards = PAIRS[pair_index]
	var capture_seed := "20261021"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): capture_seed = arg.substr(7)
	output_dir = "res://evidence/elemental/capture-%s-%s-pair%d-%s-%s" % [capture_seed,route_choice,pair_index,selected_policy,"movie" if movie else "live"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	began_us = Time.get_ticks_usec()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if scene.sandbox or scene.session.get("combat") == null:
		printerr("CAPTURE_ELEMENTAL requires default actual-run mode, no --sandbox")
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
				if reward_index >= rewards.size():
					errors.append("unexpected additional reward")
					break
				var id: String = rewards[reward_index]
				var index: int = scene.session.reward_options.find(id)
				if index < 0:
					errors.append("intended earned reward not available: "+id)
					break
				await gesture(scene.UI.reward_rect(index,scene.session.reward_options.size()).get_center())
				var expected_phase := "route" if scene.session.combat.encounter == 0 else "shop"
				if scene.session.phase != expected_phase or id not in scene.session.relics:
					errors.append("reward UI did not enter "+expected_phase)
				record("reward_chosen",{"id":id})
			"route":
				record("route_offer")
				await snapshot("route-offer")
				await create_timer(2.0).timeout
				var index := 0 if route_choice == "safe" else 1
				await gesture(choice_rect(index).get_center())
				if scene.session.phase != "ready" or scene.session.combat.encounter != 1 or scene.session.route != route_choice:
					errors.append("route card UI did not enter selected second fight")
				record("route_chosen",{"choice":route_choice})
				await snapshot("route-entered")
				await create_timer(0.8).timeout
			"shop":
				record("shop_offer",{"remaining_relic":scene.session.shop_remaining_relic(),"heal_gain":scene.session.shop_heal_gain()})
				await snapshot("shop-before")
				await create_timer(2.0).timeout
				# Match the pure simulation shop policy; no forced HP/gold.
				var purchases: Array = ["heal"] if route_choice == "safe" and pair_index == 0 else ["relic"]
				if route_choice == "elite": purchases = ["heal","relic"] if pair_index == 0 else ["relic","heal"]
				for item in purchases:
					var index: int = 1 if item == "relic" else 0
					var price: int = 8 if item == "relic" else 4
					var before := state()
					var gain: int = scene.session.shop_heal_gain() if item == "heal" else 0
					var eligible: bool = scene.session.gold >= price and (not scene.session.shop_remaining_relic().is_empty() if item == "relic" else gain > 0)
					if not eligible:
						record("shop_skip",{"item":item,"reason":"full_hp" if item == "heal" and gain == 0 else "insufficient_gold_or_unavailable"})
						continue
					await gesture(choice_rect(index).get_center())
					if scene.session.phase != "shop" or scene.session.gold != before.gold-price:
						errors.append("shop card UI did not purchase available "+item)
					record("shop_purchase",{"item":item,"price":price,"heal_gain":gain,"before":before})
					await snapshot("shop-after-"+item)
					await create_timer(0.6).timeout
				await snapshot("shop-after")
				await create_timer(1.0).timeout
				var carried := state()
				await gesture(scene.UI.SUMMARY_CONTINUE.get_center())
				if scene.session.phase != "ready" or scene.session.combat.encounter != 2:
					errors.append("explicit shop exit did not enter final fight")
				record("shop_exit",{"before":carried})
				await snapshot("finalfight-entered")
				await create_timer(2.2).timeout
			"ready":
				await observe_boss_turn()
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
				record("clear",{"start_id":selected.id,"direct":preview.direct,"removed":preview.removed,"damage":preview.damage,"base_damage":preview.base_damage,"weak_count":preview.weak_count,"weak_bonus":preview.weak_bonus,"normal_count":preview.normal_count,"combat_context":preview.combat_context,"mitigates_intent":preview.mitigates_intent,"heal_effective":preview.heal_effective,"before":before})
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
		record("defeat" if scene.session.phase == "defeat" else "stopped")
		await snapshot("defeat" if scene.session.phase == "defeat" else "stopped")
		await create_timer(2.0).timeout
		if errors.is_empty() and scene.session.phase != "defeat": errors.append("did not reach terminal state: "+scene.session.phase)
	var trace := {"method":"actual main.tscn, real press/release routing, natural _process/refill/attack; automated legal decisions, not hardware touch","movie":movie,"timing_note":"MovieWriter is fixed-frame evidence, not wall-clock performance; live timings include concurrent screenshot I/O" if movie else "live rendered wall-clock; screenshots/driver decisions add overhead, not a dedicated performance benchmark","seed":scene.run_seed,"rewards":rewards,"route":route_choice,"policy":selected_policy,"selection_note":"Ordinary seed/route/policy, no fixture. Compare selected capture to full 24-run records; movie and live are not performance benchmarks.","pair_index":pair_index,"shop_policy":"same as pure: safe pair0 heal, safe pair1/2 relic; elite pair0 heal then relic, pair1/2 relic then heal; skip unavailable/full HP","no_fixtures":true,"terminal":scene.session.phase,"errors":errors,"observed_counterattack":saw_attack,"observed_mitigation":saw_mitigation,"events":events,"timings":scene.timings.duplicate(true),"screenshots":snapshots,"final":state()}
	var file := FileAccess.open(output_dir.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"  "))
	print("CAPTURE_ELEMENTAL terminal=",scene.session.phase," clears=",clear_count," errors=",errors)
	# Keep the final scene intact until shutdown; no gray teardown frames.
	quit(0 if errors.is_empty() else 1)

func choice_rect(index: int) -> Rect2:
	# Shared approved route/shop card geometry; this is a screen gesture, not
	# a direct session method call or injected route/shop state.
	return Rect2(64,350+156*index,592,140)

func observe_boss_turn() -> void:
	var s = scene.session
	if s.combat.encounter != 2 or s.combat.actions_in_turn != 0: return
	var key: String = str(s.combat.damage_context().intent_serial)
	if boss_turns_seen.has(key): return
	boss_turns_seen[key] = true
	var candidates: Array = []
	var eligible := 0
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false): continue
		var qualifies: bool = plan.weak_count >= 2 or plan.normal_count >= 8
		if qualifies: eligible += 1
		candidates.append({"start_id":panel.id,"weak_count":plan.weak_count,"normal_count":plan.normal_count,"base_damage":plan.base_damage,"weak_bonus":plan.weak_bonus,"mitigates_intent":plan.mitigates_intent,"qualifies_raw_threshold":qualifies})
	record("boss_turn_start",{"eligible_legal_starts":eligible,"candidates":candidates,"note":"Before skill/clear; multiple starts can identify same group, frozen intent may be plain."})
	await snapshot("boss-turn-%d"%s.combat.turn)
	await create_timer(2.0).timeout

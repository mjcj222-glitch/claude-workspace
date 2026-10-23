extends SceneTree
## Pure normal-play simulation, NOT real-time GPU/input/performance evidence.
## No board recoloring, forced charge, injected health or favorable fixtures.
const Motion = preload("res://scripts/board_motion.gd")
const BOUNDS = Rect2(30,290,660,530)
const PAIRS = [["pigment","lens"],["pigment","ash"],["lens","ash"]]
const SEEDS = [20261021,20261022]
const ACTION_LIMIT = 120
var failures := 0
var results: Array = []
var RunSession
var selected_policy := "intent-aware"
var hero := "rio"

func _initialize() -> void:
	call_deferred("run")

func combat_state(s) -> Dictionary:
	var c = s.combat
	return {"encounter":c.encounter,"enemy_hp":c.enemy_hp,"enemy_max_hp":c.enemy_max_hp,
		"turn":c.turn,"actions_in_turn":c.actions_in_turn,"incoming_damage":c.incoming_damage,
		"mitigation_active":c.mitigation_active,"mitigation_success":c.mitigation_success,
		"fallback_plain":c.fallback_plain,"enemies_defeated":c.enemies_defeated,
		"attacks_total":c.attacks_total,"last_attack_damage":c.last_attack_damage,
		"weak_color":c.weak_color,"damage_context":c.damage_context()}

func carry(s) -> Dictionary:
	return {"character_id":s.character_id,"hp":s.hp,"charge":s.charge,"charge_required":s.charge_required,
		"ash_reserved":s.ash_reserved,"relics":s.relics.duplicate(),"actions":s.actions,
		"route":s.route,"gold":s.gold,"gold_spent":s.gold_spent,"shop_heal_sold":s.shop_heal_sold,
		"shop_relic_sold":s.shop_relic_sold,"shop_closed":s.shop_closed}

func best_clear(s) -> Dictionary:
	if selected_policy=="attrition":return preload("res://tests/character_policy.gd").weak_clear(s)
	var best: Dictionary = {}
	var best_value := -INF
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false):
			continue
		# Prefer an immediate lethal clear over defensive progress. Otherwise
		# satisfy the active plan-based intent once, then maximize damage.
		var lethal: bool = plan.damage >= s.combat.enemy_hp
		var mitigates: bool = selected_policy == "intent-aware" and s.combat.mitigation_active and not s.combat.mitigation_success and plan.get("mitigates_intent",false)
		var value: float = plan.damage * 10.0 + plan.removed.size() + plan.heal_effective * (15.0 if s.hp <= 10 else 5.0)
		if lethal: value += 100000.0
		elif mitigates: value += 10000.0
		if value > best_value:
			best_value = value
			best = {"id":panel.id,"point":panel.pos,"plan":plan,"score":value}
	return best

func best_skill(s) -> Dictionary:
	return preload("res://tests/character_policy.gd").best_skill(s)

func burst_rng(rng: RandomNumberGenerator, plan: Dictionary, present: Dictionary) -> int:
	# Match main._burst: 7 particles, speed and size each consume game RNG.
	# Feedback rejects duplicate removals, and missing visual IDs emit nothing.
	var done: Dictionary = {}
	for id in plan.sequence:
		if id not in plan.removed or not present.has(id) or done.has(id): continue
		done[id] = true
		for particle in range(7):
			rng.randf_range(65,180)
			rng.randf_range(2,6)
	return done.size()*14

func simulate(seed_value: int, pair_index: int, route_choice: String) -> Dictionary:
	var s = RunSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var initial: Dictionary = Motion.initial_board(BOUNDS,48,1,rng)
	s.initialize_board(initial.panels,initial.next_id)
	s.open_departure()
	s.select_departure(hero,s.offer_serial)
	s.start_departure(s.offer_serial)
	var events: Array = [{"type":"initialize","seed":seed_value,"rng_state":str(rng.state),"carry":carry(s),"combat":combat_state(s)}]
	var effects := {"pigment_five_targets":0,"lens_five_core":0,"lens_eleven_strong":0,
		"ash_reservations":0,"ash_consumptions":0,"mitigation_latched":0}
	var errors: Array = []
	var reason := ""
	var iterations := 0
	var boss_turns_seen: Dictionary = {}
	while s.phase not in ["victory","defeat"] and s.actions < ACTION_LIMIT and iterations < 400:
		iterations += 1
		if s.phase == "enemy_attack":
			var before := carry(s)
			var before_combat := combat_state(s)
			s.finish_attack()
			events.append({"type":"enemy_attack","before":before,"before_combat":before_combat,"after":carry(s),"combat":combat_state(s),"phase":s.phase})
			continue
		if s.phase == "reward":
			var reward_index: int = s.relics.size()
			if reward_index >= PAIRS[pair_index].size():
				errors.append("unexpected additional reward")
				break
			var id: String = PAIRS[pair_index][reward_index]
			var before := carry(s)
			var accepted: bool = s.choose_relic(id,s.offer_serial)
			events.append({"type":"reward","id":id,"accepted":accepted,"before":before,"after":carry(s),"phase":s.phase})
			if not accepted:
				errors.append("intended unowned relic not offered: "+id)
				break
			continue
		if s.phase == "route":
			var before := carry(s)
			var accepted: bool = s.choose_route(route_choice)
			events.append({"type":"route","choice":route_choice,"accepted":accepted,"before":before,"after":carry(s),"phase":s.phase})
			if not accepted or s.phase != "between":
				errors.append("legal route selection rejected")
				break
			continue
		if s.phase == "shop":
			var purchases: Array = ["heal"] if route_choice == "safe" and pair_index == 0 else ["relic"]
			if route_choice == "elite": purchases = ["heal","relic"] if pair_index == 0 else ["relic","heal"]
			events.append({"type":"shop_enter","carry":carry(s),"remaining_relic":s.shop_remaining_relic(),"heal_gain":s.shop_heal_gain(),"purchase_policy":purchases})
			for item in purchases:
				var before := carry(s)
				var cost: int = 4 if item == "heal" else 8
				var gain: int = s.shop_heal_gain() if item == "heal" else 0
				var available: bool = s.gold >= cost and (gain > 0 and not s.shop_heal_sold if item == "heal" else not s.shop_relic_sold and not s.shop_remaining_relic().is_empty())
				if not available:
					events.append({"type":"shop_skip","item":item,"reason":"full_hp" if item == "heal" and gain == 0 else "insufficient_gold_or_sold","carry":before})
					continue
				var accepted: bool = s.buy_shop(item)
				events.append({"type":"shop_purchase","item":item,"cost":cost,"heal_gain":gain,"accepted":accepted,"before":before,"after":carry(s)})
				if not accepted: errors.append("affordable available shop item rejected: "+item)
			var before := carry(s)
			s.leave_shop()
			events.append({"type":"shop_leave","before":before,"after":carry(s),"phase":s.phase})
			if s.phase != "between": errors.append("shop exit did not permit final fight")
			if not errors.is_empty(): break
			continue
		if s.phase == "between":
			var before := carry(s)
			var next: Dictionary = Motion.initial_board(BOUNDS,48,s.next_id,rng)
			s.begin_next_fight(next.panels,next.next_id)
			events.append({"type":"next_fight","before":before,"after":carry(s),"combat":combat_state(s),"rng_state":str(rng.state),"phase":s.phase})
			continue
		if s.phase != "ready":
			errors.append("unexpected phase: "+s.phase)
			break
		if s.combat.encounter == 2 and s.combat.actions_in_turn == 0:
			var key: String = str(s.combat.damage_context().intent_serial)
			if not boss_turns_seen.has(key):
				boss_turns_seen[key] = true
				events.append(boss_turn_start(s))
		# A winning clear should not be delayed by an unnecessary skill.
		var selected := best_clear(s)
		if (selected_policy!="attrition" or s.skill_uses==0) and s.charge >= s.charge_required and (selected.is_empty() or selected.plan.damage < s.combat.enemy_hp):
			var skill := best_skill(s)
			if not skill.is_empty():
				var before := carry(s)
				s.skill_mode = true
				s.skill_color = skill.color
				if not s.begin(skill.point,-1):
					errors.append("legal skill begin rejected")
					break
				var preview: Dictionary = s.selection.duplicate(true)
				var executed: Dictionary = s.release(skill.point,-1)
				if executed != preview or executed.is_empty():
					errors.append("skill preview/commit mismatch")
					break
				if executed.targets.size() == 5 and "pigment" in s.relics: effects.pigment_five_targets += 1
				if executed.get("consume_ash",false): effects.ash_consumptions += 1
				events.append({"type":"skill","start_id":skill.id,"color":skill.color,"target_ids":executed.targets,"connected_ids":executed.connected,"planted":executed.get("planted",{}),"consumed_ash":executed.get("consume_ash",false),"before":before,"after":carry(s)})
				selected = best_clear(s)
		if selected.is_empty():
			reason = "no_legal_clear"
			break
		var present: Dictionary = {}
		for panel in s.panels: present[panel.id] = true
		var before := carry(s)
		var before_combat := combat_state(s)
		if not s.begin(selected.point,-1):
			errors.append("legal clear begin rejected")
			break
		var preview: Dictionary = s.selection.duplicate(true)
		var executed: Dictionary = s.release(selected.point,-1)
		if executed != preview or executed.is_empty():
			errors.append("clear preview/commit mismatch")
			break
		if s.actions != before.actions+1:
			errors.append("valid clear did not consume exactly one action")
			break
		if executed.spawn.get("kind","") == "core" and executed.direct_normals == 5 and "lens" in s.relics: effects.lens_five_core += 1
		if executed.spawn.get("kind","") == "strong" and executed.direct_normals == 11 and "lens" in s.relics: effects.lens_eleven_strong += 1
		if executed.get("ash_reserve",false) and not before.ash_reserved and s.ash_reserved: effects.ash_reservations += 1
		if not before_combat.mitigation_success and s.combat.mitigation_success: effects.mitigation_latched += 1
		var rng_calls := burst_rng(rng,executed,present)
		var motion: Dictionary = Motion.start(s.panels,BOUNDS,48,s.next_id,rng)
		while not motion.ready and not motion.stalled:
			Motion.step(motion,BOUNDS,Motion.STEP)
		var record := {"type":"clear","start_id":selected.id,"direct_ids":executed.direct,"removed_ids":executed.removed,"sequence":executed.sequence,"direct_normals":executed.direct_normals,"damage":executed.damage,"base_damage":executed.base_damage,"weak_count":executed.weak_count,"weak_bonus":executed.weak_bonus,"normal_count":executed.normal_count,"combat_context":executed.combat_context,"mitigates_intent":executed.mitigates_intent,"heal_raw":executed.heal_raw,"heal_effective":executed.heal_effective,"heal_overflow":executed.heal_overflow,"core_created":executed.spawn.get("kind",""),"activated":executed.activated,"before":before,"before_combat":before_combat,"burst_rng_draws":rng_calls,"refill_sim_seconds":motion.elapsed,"rng_state":str(rng.state)}
		if motion.stalled:
			record["phase"] = "stalled"
			record["pending"] = motion.pending.size()
			events.append(record)
			reason = "motion_stalled_at_4s"
			break
		s.panels = motion.panels.duplicate(true)
		s.next_id = motion.next_id
		s.finish_refill()
		record["after"] = carry(s)
		record["combat"] = combat_state(s)
		record["phase"] = s.phase
		events.append(record)
	if reason.is_empty():
		reason = s.phase if s.phase in ["victory","defeat"] else ("assertion_failure" if not errors.is_empty() else "action_or_iteration_limit")
	return {"seed":seed_value,"route":route_choice,"pair":PAIRS[pair_index],"pair_index":pair_index,"method":"pure headless normal-play simulation; fixed-step physics; not real-time GPU/input evidence","policy":selected_policy,"policy_detail":"both lethal-first and same damage/healing weights + maximum-connection skill; intent-aware additionally prioritizes one plan that mitigates active unlatched intent; damage-first does not","comparison_limit":"Same initial seeds; selected actions change later RNG consumption/boards. This is not an identical-board causal comparison.","restrictions":"no recolor, favorable fixture, forced charge, HP injection, board rescue or intermediate reset","rng_parity":"same game RNG; fourteen burst draws per unique actually removed ID before refill; visual effect RNG unused","terminal":reason,"session_phase":s.phase,"errors":errors,"carry":carry(s),"combat":combat_state(s),"effects_observed":effects,"events":events}

func run() -> void:
	RunSession = load("res://scripts/board_run_session.gd")
	if RunSession == null:
		printerr("CHARACTER_NORMAL blocked: board_run_session.gd unavailable")
		quit(2)
		return
	var seeds: Array = [20261021]
	var pairs: Array = [0,1,2]
	var routes: Array = ["safe","elite"]
	var policies: Array = ["intent-aware"]
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg: String = args[index]
		if arg.begins_with("--hero="): hero=arg.substr(7)
		elif arg.begins_with("--seed="): seeds = [int(arg.substr(7))]
		elif arg == "--seed" and index+1 < args.size(): seeds = [int(args[index+1])]
		elif arg.begins_with("--policy="): policies = [arg.substr(9)]
		elif arg.begins_with("--route="): routes = [arg.substr(8)]
		elif arg.begins_with("--pair="): pairs = [int(arg.substr(7))]
		elif arg == "--pair" and index+1 < args.size(): pairs = [int(args[index+1])]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/characters/normal-"+hero+""))
	for seed_value in seeds:
		for route_choice in routes:
			if route_choice not in ["safe","elite"]:
				printerr("route must be safe or elite")
				quit(2)
				return
			for pair_index in pairs:
				if pair_index not in [0,1,2]:
					printerr("pair must be 0,1,2")
					quit(2)
					return
				for policy in policies:
					if policy not in ["intent-aware","damage-first","attrition"]:
						printerr("unknown policy: "+str(policy))
						quit(2)
						return
					selected_policy = policy
					var result := simulate(seed_value,pair_index,route_choice)
					result["audit"] = audit(result)
					result["boss_summary"] = boss_summary(result)
					results.append(result)
					var path := "res://evidence/characters/normal-%s/seed%d-%s-pair%d-%s.json" % [hero,seed_value,route_choice,pair_index,selected_policy]
					var file := FileAccess.open(path,FileAccess.WRITE)
					file.store_string(JSON.stringify(result,"  "))
					file.close()
					var complete: bool = result.terminal in ["victory","defeat"] and result.errors.is_empty() and result.audit.errors.is_empty()
					if not complete: failures += 1
					print("CHARACTER_NORMAL seed=",seed_value," route=",route_choice," pair=",pair_index," policy=",selected_policy," terminal=",result.terminal," hp=",result.carry.hp," actions=",result.carry.actions," gold=",result.carry.gold," spent=",result.carry.gold_spent," effects=",result.effects_observed," errors=",result.errors," audit=",result.audit)
					await process_frame
	print("CHARACTER_NORMAL runs=",results.size()," incomplete_or_errors=",failures," (defeat is an honest completed outcome, not an assertion failure)")
	quit(1 if failures else 0)

func audit(result: Dictionary) -> Dictionary:
	var errors: Array = []
	var checked := 0
	for event in result.events:
		match event.type:
			"next_fight":
				checked += 1
				if event.before != event.after: errors.append("fight transition altered carried resources")
			"route":
				checked += 1
				if event.before.gold != event.after.gold: errors.append("route choice changed gold")
			"shop_purchase":
				checked += 3
				if event.after.gold != event.before.gold-event.cost: errors.append("purchase gold mismatch")
				if event.after.gold_spent != event.before.gold_spent+event.cost: errors.append("purchase spending mismatch")
				if event.before.charge != event.after.charge or event.before.charge_required != event.after.charge_required or event.before.ash_reserved != event.after.ash_reserved: errors.append("purchase changed charge or ash")
				if event.item == "heal":
					checked += 1
					if event.after.hp != event.before.hp+event.heal_gain: errors.append("shop heal gain mismatch")
			"clear":
				checked += 7
				if event.damage != event.base_damage+event.weak_bonus: errors.append("weakness aggregate damage mismatch")
				if event.weak_bonus != floori(float(event.weak_count)/2.0): errors.append("weakness floor bonus mismatch")
				if event.burst_rng_draws != 14*event.removed_ids.size(): errors.append("burst RNG parity mismatch")
				if event.after.actions != event.before.actions+1: errors.append("clear action accounting mismatch")
				var attack: int = event.combat.last_attack_damage if event.phase == "enemy_attack" else 0
				if event.after.hp != maxi(0,event.before.hp+event.heal_effective-attack): errors.append("clear/attack HP mismatch")
				var payout: int = 0
				if event.phase == "reward": payout = 4 if event.combat.encounter == 0 or result.route == "safe" else 8
				if event.after.gold != event.before.gold+payout: errors.append("victory payout mismatch")
				if event.after.gold < 0: errors.append("negative gold")
	return {"checks":checked,"errors":errors}

func boss_turn_start(s) -> Dictionary:
	var candidates: Array = []
	var eligible_starts := 0
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false): continue
		var qualifies: bool = plan.weak_count >= 2 or plan.normal_count >= 8
		if qualifies: eligible_starts += 1
		candidates.append({"start_id":panel.id,"weak_count":plan.weak_count,"normal_count":plan.normal_count,"base_damage":plan.base_damage,"weak_bonus":plan.weak_bonus,"damage":plan.damage,"qualifies_raw_slam_threshold":qualifies,"mitigates_intent":plan.mitigates_intent})
	return {"type":"boss_turn_start","combat":combat_state(s),"carry":carry(s),"eligible_legal_start_count":eligible_starts,"candidates":candidates,"note":"Observed before this turn's first skill/clear. Multiple starts can represent the same group. Raw threshold existence is distinct from the frozen scheduled intent."}

func boss_summary(result: Dictionary) -> Dictionary:
	var summary := {"turns_observed":0,"slam_turns":0,"plain_turns":0,"fallback_turns":0,"mitigation_latches":0,"attacks":0,"actual_damage_taken":0,"deaths":0,"clears":0,"weak_bonus_total":0}
	for event in result.events:
		if event.type == "boss_turn_start":
			summary.turns_observed += 1
			if event.combat.damage_context.intent == "slam": summary.slam_turns += 1
			else: summary.plain_turns += 1
			if event.combat.fallback_plain: summary.fallback_turns += 1
		elif event.type == "clear" and event.before_combat.encounter == 2:
			summary.clears += 1
			summary.weak_bonus_total += event.weak_bonus
			if event.get("combat",{}).get("mitigation_success",false) and not event.before_combat.mitigation_success: summary.mitigation_latches += 1
			if event.get("phase","") == "enemy_attack":
				summary.attacks += 1
				summary.actual_damage_taken += event.combat.last_attack_damage
				if event.after.hp <= 0: summary.deaths += 1
	return summary

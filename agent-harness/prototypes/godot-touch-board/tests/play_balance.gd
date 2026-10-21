extends "res://tests/play_elemental.gd"
## Bounded baseline diagnosis. Production rules and all resources remain untouched.
## avoid-intent is deliberately adversarial, NOT a model of human skill.

const Policy = preload("res://tests/balance_policy.gd")

func best_clear(s) -> Dictionary:
	return Policy.best_clear(s,selected_policy)

func boss_turn_start(s) -> Dictionary:
	var context: Dictionary = s.combat.damage_context()
	var record: Dictionary = {"type":"boss_turn_start","combat":combat_state(s),"carry":carry(s),"candidates":[],"eligible_legal_start_count":0,"note":"Before first skill/clear; canonical plan intent eligibility. Raw threshold requires published context fields."}
	var published: bool = context.has("slam_weak_required") and context.has("slam_normal_required")
	var raw_sets: Dictionary = {}
	var unique_sets: Dictionary = {}
	var eligible_sets: Dictionary = {}
	var min_w := 999999
	var max_w := 0
	var min_n := 999999
	var max_n := 0
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false): continue
		var removed: Array = plan.removed.duplicate()
		removed.sort()
		var key := JSON.stringify(removed)
		unique_sets[key] = true
		var qualifies: bool = plan.get("mitigates_intent",false)
		var raw: Variant = plan.weak_count >= int(context.slam_weak_required) or plan.normal_count >= int(context.slam_normal_required) if published else null
		if qualifies:
			eligible_sets[key] = true
			record.eligible_legal_start_count += 1
		if raw == true: raw_sets[key] = true
		record.candidates.append({"start_id":panel.id,"weak_count":plan.weak_count,"normal_count":plan.normal_count,"base_damage":plan.base_damage,"weak_bonus":plan.weak_bonus,"damage":plan.damage,"mitigates_intent":qualifies,"qualifies_raw_slam_threshold":raw})
		min_w = mini(min_w,plan.weak_count)
		max_w = maxi(max_w,plan.weak_count)
		min_n = mini(min_n,plan.normal_count)
		max_n = maxi(max_n,plan.normal_count)
	record["raw_eligible_unique_removal_sets"] = raw_sets.size() if published else null
	record["thresholds_published"] = published
	record["eligibility_basis"] = "canonical plan.mitigates_intent; raw eligibility separately uses published context thresholds"
	record["legal_start_count"] = record.candidates.size()
	record["unique_removal_sets"] = unique_sets.size()
	record["eligible_unique_removal_sets"] = eligible_sets.size()
	record["weak_count_range"] = [min_w if not unique_sets.is_empty() else 0,max_w]
	record["normal_count_range"] = [min_n if not unique_sets.is_empty() else 0,max_n]
	return record

func run() -> void:
	RunSession = load("res://scripts/board_run_session.gd")
	if RunSession == null:
		printerr("BALANCE_NORMAL blocked: board_run_session.gd unavailable")
		quit(2)
		return
	var seeds: Array = [20261021,20261022,20261023]
	var pairs: Array = [0]
	var label := "baseline"
	var routes: Array = ["safe","elite"]
	var policies: Array = ["immediate-damage","intent-aware","avoid-intent"]
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg: String = args[index]
		if arg.begins_with("--label="): label = arg.substr(8)
		elif arg.begins_with("--seed="): seeds = [int(arg.substr(7))]
		elif arg == "--seed" and index+1 < args.size(): seeds = [int(args[index+1])]
		elif arg.begins_with("--policy="): policies = [arg.substr(9)]
		elif arg.begins_with("--route="): routes = [arg.substr(8)]
		elif arg.begins_with("--pair="): pairs = [int(arg.substr(7))]
		elif arg == "--pair" and index+1 < args.size(): pairs = [int(args[index+1])]
	if label not in ["baseline","candidate-a","candidate-b","final"]:
		printerr("label must be baseline/candidate-a/candidate-b/final")
		quit(2)
		return
	var output_dir := "res://evidence/balance/"+label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
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
					if policy not in ["immediate-damage","intent-aware","avoid-intent"]:
						printerr("unknown policy: "+str(policy))
						quit(2)
						return
					selected_policy = policy
					var result := simulate(seed_value,pair_index,route_choice)
					result["policy_detail"] = "First two fights: identical existing intent-aware selector. Boss immediate-damage: damage then normal count then lowest ID. Boss intent-aware: lethal first, then active unlatched qualifying plan, then same damage score. Boss avoid-intent: diagnostic deliberately prefers nonmitigating legal clear when available, even over lethal; otherwise same damage score. Common existing max-connection skill and shop handling."
					result["audit"] = audit(result)
					result["boss_summary"] = boss_summary(result)
					results.append(result)
					var path := output_dir.path_join("seed%d-%s-pair%d-%s.json" % [seed_value,route_choice,pair_index,selected_policy])
					var file := FileAccess.open(path,FileAccess.WRITE)
					file.store_string(JSON.stringify(result,"  "))
					file.close()
					var complete: bool = result.terminal in ["victory","defeat"] and result.errors.is_empty() and result.audit.errors.is_empty()
					if not complete: failures += 1
					print("BALANCE_NORMAL seed=",seed_value," route=",route_choice," pair=",pair_index," policy=",selected_policy," terminal=",result.terminal," hp=",result.carry.hp," actions=",result.carry.actions," gold=",result.carry.gold," spent=",result.carry.gold_spent," effects=",result.effects_observed," errors=",result.errors," audit=",result.audit)
					await process_frame
	print("BALANCE_NORMAL runs=",results.size()," incomplete_or_errors=",failures," (defeat is an honest completed outcome, not an assertion failure)")
	quit(1 if failures else 0)

func audit(result: Dictionary) -> Dictionary:
	var safe: Dictionary = result.duplicate(true)
	var omitted: Array = []
	safe.events = []
	for event in result.events:
		if event.type == "clear" and not event.has("after"):
			omitted.append({"start_id":event.start_id,"phase":event.get("phase","unknown"),"reason":"Resolution incomplete; no post-refill state exists. Original event retained unchanged."})
		else: safe.events.append(event)
	var report: Dictionary = super.audit(safe)
	report["incomplete_events"] = omitted
	if not omitted.is_empty(): report.errors.append("Incomplete clear resolution: no after-state; not counted as defeat or successful completed audit")
	return report

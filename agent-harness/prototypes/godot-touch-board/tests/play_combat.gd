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

func _initialize() -> void:
	call_deferred("run")

func combat_state(s) -> Dictionary:
	var c = s.combat
	return {"encounter":c.encounter,"enemy_hp":c.enemy_hp,"enemy_max_hp":c.enemy_max_hp,
		"turn":c.turn,"actions_in_turn":c.actions_in_turn,"incoming_damage":c.incoming_damage,
		"mitigation_active":c.mitigation_active,"mitigation_success":c.mitigation_success,
		"fallback_plain":c.fallback_plain,"enemies_defeated":c.enemies_defeated,
		"attacks_total":c.attacks_total,"last_attack_damage":c.last_attack_damage}

func carry(s) -> Dictionary:
	return {"hp":s.hp,"charge":s.charge,"charge_required":s.charge_required,
		"ash_reserved":s.ash_reserved,"relics":s.relics.duplicate(),"actions":s.actions}

func best_clear(s) -> Dictionary:
	var best: Dictionary = {}
	var best_value := -INF
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false):
			continue
		# Prefer an immediate lethal clear over defensive progress. Otherwise
		# satisfy the active four-normal mitigation once, then maximize damage.
		var lethal: bool = plan.damage >= s.combat.enemy_hp
		var mitigates: bool = s.combat.mitigation_active and not s.combat.mitigation_success and plan.direct_normals >= 4
		var value: float = plan.damage * 10.0 + plan.removed.size() + plan.heal_effective * (15.0 if s.hp <= 10 else 5.0)
		if lethal: value += 100000.0
		elif mitigates: value += 10000.0
		if value > best_value:
			best_value = value
			best = {"id":panel.id,"point":panel.pos,"plan":plan,"score":value}
	return best

func best_skill(s) -> Dictionary:
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

func simulate(seed_value: int, pair_index: int) -> Dictionary:
	var s = RunSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var initial: Dictionary = Motion.initial_board(BOUNDS,48,1,rng)
	s.initialize_board(initial.panels,initial.next_id)
	var events: Array = [{"type":"initialize","seed":seed_value,"rng_state":str(rng.state),"carry":carry(s),"combat":combat_state(s)}]
	var effects := {"pigment_five_targets":0,"lens_five_core":0,"lens_eleven_strong":0,
		"ash_reservations":0,"ash_consumptions":0,"mitigation_latched":0}
	var errors: Array = []
	var reason := ""
	var iterations := 0
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
		if s.phase == "between":
			var before := carry(s)
			var next: Dictionary = Motion.initial_board(BOUNDS,48,s.next_id,rng)
			s.begin_next_fight(next.panels,next.next_id)
			events.append({"type":"next_fight","before":before,"after":carry(s),"combat":combat_state(s),"rng_state":str(rng.state),"phase":s.phase})
			continue
		if s.phase != "ready":
			errors.append("unexpected phase: "+s.phase)
			break
		# A winning clear should not be delayed by an unnecessary skill.
		var selected := best_clear(s)
		if s.charge >= s.charge_required and (selected.is_empty() or selected.plan.damage < s.combat.enemy_hp):
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
				events.append({"type":"skill","start_id":skill.id,"color":skill.color,"target_ids":executed.targets,"connected_ids":executed.connected,"consumed_ash":executed.get("consume_ash",false),"before":before,"after":carry(s)})
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
		var record := {"type":"clear","start_id":selected.id,"direct_ids":executed.direct,"removed_ids":executed.removed,"sequence":executed.sequence,"direct_normals":executed.direct_normals,"damage":executed.damage,"heal_raw":executed.heal_raw,"heal_effective":executed.heal_effective,"heal_overflow":executed.heal_overflow,"core_created":executed.spawn.get("kind",""),"activated":executed.activated,"before":before,"before_combat":before_combat,"burst_rng_draws":rng_calls,"refill_sim_seconds":motion.elapsed,"rng_state":str(rng.state)}
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
	return {"seed":seed_value,"pair":PAIRS[pair_index],"pair_index":pair_index,"method":"pure headless normal-play simulation; fixed-step physics; not real-time GPU/input evidence","policy":"lethal first; active four-normal mitigation next; damage/removed plus effective healing; largest legal skill connection","restrictions":"no recolor, favorable fixture, forced charge, HP injection, board rescue or intermediate reset","rng_parity":"same game RNG; fourteen burst draws per unique actually removed ID before refill; visual effect RNG unused","terminal":reason,"session_phase":s.phase,"errors":errors,"carry":carry(s),"combat":combat_state(s),"effects_observed":effects,"events":events}

func run() -> void:
	RunSession = load("res://scripts/board_run_session.gd")
	if RunSession == null:
		printerr("COMBAT_NORMAL blocked: board_run_session.gd unavailable")
		quit(2)
		return
	var seeds: Array = SEEDS.duplicate()
	var pairs: Array = [0,1,2]
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg: String = args[index]
		if arg.begins_with("--seed="): seeds = [int(arg.substr(7))]
		elif arg == "--seed" and index+1 < args.size(): seeds = [int(args[index+1])]
		elif arg.begins_with("--pair="): pairs = [int(arg.substr(7))]
		elif arg == "--pair" and index+1 < args.size(): pairs = [int(args[index+1])]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/combat"))
	for seed_value in seeds:
		for pair_index in pairs:
			if pair_index not in [0,1,2]:
				printerr("pair must be0,1,2")
				quit(2)
				return
			var result := simulate(seed_value,pair_index)
			results.append(result)
			var path := "res://evidence/combat/combat-normal-seed%d-pair%d.json" % [seed_value,pair_index]
			var file := FileAccess.open(path,FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"  "))
			file.close()
			var complete: bool = result.terminal in ["victory","defeat"] and result.errors.is_empty()
			if not complete: failures += 1
			print("COMBAT_NORMAL seed=",seed_value," pair=",pair_index," terminal=",result.terminal," hp=",result.carry.hp," actions=",result.carry.actions," effects=",result.effects_observed," errors=",result.errors)
			await process_frame
	print("COMBAT_NORMAL runs=",results.size()," incomplete_or_errors=",failures," (defeat is an honest completed outcome, not an assertion failure)")
	quit(1 if failures else 0)

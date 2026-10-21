extends "res://tests/play_elemental.gd"
## One archived-input replay, not a new policy experiment or a physics fix.
const SOURCE := "res://evidence/balance/baseline/seed20261023-elite-pair0-avoid-intent.json"
const OUTPUT := "res://evidence/balance/stall-reproduction"

func fail(message: String) -> void:
	printerr("STALL_REPLAY FAILED: ",message)
	quit(1)

func point_for(s, id: int) -> Vector2:
	for panel in s.panels:
		if int(panel.id) == id: return panel.pos
	return Vector2(INF,INF)

func run() -> void:
	if "--verify-saved" in OS.get_cmdline_user_args():
		var saved := FileAccess.open(OUTPUT+"/state.var",FileAccess.READ)
		var state: Dictionary = saved.get_var(false)
		saved.close()
		var verified := verify_roundtrip(state)
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/summary.json"))
		report["roundtrip"] = verified
		report["verification_driver_sha256"] = FileAccess.get_sha256("res://tests/reproduce_balance_stall.gd")
		var output := FileAccess.open(OUTPUT+"/summary.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(report,"  ")); output.close()
		print("STALL_SAVED_VERIFY ",JSON.stringify(verified))
		quit(0 if verified.equal and verified.vector2_count>0 and verified.object_count==0 else 1)
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	RunSession = load("res://scripts/board_run_session.gd")
	var s = RunSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source.seed)
	var initial: Dictionary = Motion.initial_board(BOUNDS,48,1,rng)
	s.initialize_board(initial.panels,initial.next_id)
	var count := 0
	for event in source.events:
		match String(event.type):
			"reward":
				if not s.choose_relic(event.id,s.offer_serial):
					fail("archived reward rejected"); return
			"route":
				if not s.choose_route(event.choice):
					fail("archived route rejected"); return
			"shop_purchase":
				if not s.buy_shop(event.item):
					fail("archived purchase rejected"); return
			"shop_leave":
				if not s.leave_shop():
					fail("archived shop exit rejected"); return
			"next_fight":
				var next: Dictionary = Motion.initial_board(BOUNDS,48,s.next_id,rng)
				s.begin_next_fight(next.panels,next.next_id)
			"enemy_attack": s.finish_attack()
			"skill":
				s.skill_mode = true
				s.skill_color = int(event.color)
				var point := point_for(s,int(event.start_id))
				if not point.is_finite() or not s.begin(point,-1):
					fail("archived skill begin rejected"); return
				var executed: Dictionary = s.release(point,-1)
				if executed.is_empty() or not same_ids(executed.targets,event.target_ids):
					fail("archived skill targets diverged"); return
			"clear":
				if s.phase != "ready":
					fail("archived clear outside ready phase"); return
				var pre_action := {"panels":s.panels.duplicate(true),"next_id":s.next_id,"carry":carry(s),"combat":combat_state(s),"rng_state":rng.state,"phase":s.phase}
				var present: Dictionary = {}
				for panel in s.panels: present[panel.id] = true
				var point := point_for(s,int(event.start_id))
				if not point.is_finite() or not s.begin(point,-1):
					fail("archived clear begin rejected"); return
				var preview: Dictionary = s.selection.duplicate(true)
				var executed: Dictionary = s.release(point,-1)
				if executed != preview or not same_ids(executed.removed,event.removed_ids):
					fail("archived clear preview or removed IDs diverged"); return
				count += 1
				var survivors: Array = s.panels.duplicate(true)
				var rng_draws := burst_rng(rng,executed,present)
				var before_motion_rng: int = rng.state
				var motion: Dictionary = Motion.start(s.panels,BOUNDS,48,s.next_id,rng)
				while not motion.ready and not motion.stalled:
					Motion.step(motion,BOUNDS,Motion.STEP)
				if motion.stalled:
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
					var expected: bool = count == 20 and int(event.start_id) == 159 and s.hp == 2 and motion.pending.size() == 0 and absf(motion.elapsed-4.00833333333333)<0.001
					var state := {"status":"UNRESOLVED reproduced" if expected else "UNEXPECTED stall", "source":SOURCE,"source_sha256":FileAccess.get_sha256(SOURCE),"seed":source.seed,"route":source.route,"policy":source.policy,"action":count,"start_id":event.start_id,"pre_action":pre_action,"survivors_before_refill":survivors,"committed_plan":executed,"motion":motion.duplicate(true),"rng_state":rng.state,"rng_state_before_motion":before_motion_rng,"burst_rng_draws":rng_draws,"carry":carry(s),"combat":combat_state(s),"session_phase":s.phase,"session_panels":s.panels.duplicate(true),"session_next_id":s.next_id,"note":"Motion is full stalled local refill state; session remains busy because stalled refill was never committed. No forced board/resources/reset/physics edits. .var is lossless Variant data with Vector2 and int64 RNG; .txt is human-readable Godot Variant text."}
					var binary := FileAccess.open(OUTPUT+"/state.var",FileAccess.WRITE)
					binary.store_var(state); binary.close()
					var roundtrip := verify_roundtrip(state)
					expected = expected and roundtrip.equal and roundtrip.vector2_count>0 and roundtrip.object_count==0
					var readable := FileAccess.open(OUTPUT+"/state.txt",FileAccess.WRITE)
					readable.store_string(var_to_str(state)); readable.close()
					var hashes: Dictionary = {}
					for path in ["scripts/board_rules.gd","scripts/board_combat.gd","scripts/board_session.gd","scripts/board_run_session.gd","scripts/board_motion.gd","scripts/board_relics.gd","tests/reproduce_balance_stall.gd"]:
						hashes[path] = FileAccess.get_sha256("res://"+path)
					var summary := {"status":state.status,"action":count,"start_id":event.start_id,"hp":s.hp,"pending":motion.pending.size(),"simulated_seconds":motion.elapsed,"source_sha256":state.source_sha256,"source_hashes":hashes,"rng_state":str(rng.state),"state_files":["state.var","state.txt"],"roundtrip":roundtrip,"not_fixed":true,"not_defeat":true}
					var report := FileAccess.open(OUTPUT+"/summary.json",FileAccess.WRITE)
					report.store_string(JSON.stringify(summary,"  ")); report.close()
					print("STALL_REPLAY ",JSON.stringify(summary))
					quit(0 if expected else 1); return
				s.panels = motion.panels.duplicate(true)
				s.next_id = motion.next_id
				s.finish_refill()
	fail("archived sequence ended without reproducing stall")

func same_ids(actual: Array, archived: Array) -> bool:
	# Godot JSON parses numeric IDs as floats; normalize only the comparison.
	if actual.size() != archived.size(): return false
	for i in range(actual.size()):
		if int(actual[i]) != int(archived[i]): return false
	return true

func verify_roundtrip(state: Dictionary) -> Dictionary:
	# Verify serialization of the exact stored Variant without executing physics.
	var path := "/tmp/chroma-stall-roundtrip.var"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_var(state,false); file.close()
	file = FileAccess.open(path,FileAccess.READ)
	var restored: Variant = file.get_var(false); file.close()
	var types := {"vector2_count":0,"object_count":0}
	count_types(restored,types)
	return {"equal":restored==state,"vector2_count":types.vector2_count,"object_count":types.object_count,"method":"store_var/get_var(false) exact deep Variant equality; no simulation or Object decoding"}

func count_types(value: Variant, totals: Dictionary) -> void:
	if typeof(value)==TYPE_OBJECT: totals.object_count += 1
	elif typeof(value)==TYPE_VECTOR2: totals.vector2_count += 1
	elif value is Dictionary:
		for key in value:
			count_types(key,totals)
			count_types(value[key],totals)
	elif value is Array:
		for item in value: count_types(item,totals)

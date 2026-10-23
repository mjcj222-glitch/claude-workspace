extends SceneTree
## Shared, pre-recorded legal-input playback. No search, screenshot or writes
## between warm-up and terminal state. Used only in isolated instrumented copies.
var scene
var rows: Array = []
var frames: Array = []
var errors: Array = []
var recording := false
var stage := "warmup"
var output := ""
var commands: Array = []
var viewport_rid: RID

func _initialize() -> void:
	call_deferred("run")

func state() -> Dictionary:
	var s=scene.session
	return {"phase":s.phase,"hp":s.hp,"charge":s.charge,"requirement":s.charge_required,"ash":s.ash_reserved,"actions":s.actions,"relics":s.relics.duplicate(),"gold":s.gold,"spent":s.gold_spent,"enemy_hp":s.combat.enemy_hp,"encounter":s.combat.encounter,"incoming":s.combat.incoming_damage,"mitigated":s.combat.mitigation_success}

func after_frame() -> void:
	if not recording: return
	frames.append({"stage":stage,"frame":Engine.get_process_frames(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_process_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),"cpu":scene.bench.duplicate(),"wall_us":Time.get_ticks_usec()})
	scene.bench.clear()

func sample_frames(count: int,label: String) -> void:
	stage=label
	for i in range(count):
		await process_frame
		await RenderingServer.frame_post_draw

func target(id: int) -> Vector2:
	for p in scene.session.panels:
		if p.id==id:return scene.board_to_screen(p.pos)
	errors.append("missing recorded target "+str(id))
	return Vector2.INF

func equal_value(a,b) -> bool:
	# JSON's numeric values are floats; production IDs/counters are integers.
	if (a is int or a is float) and (b is int or b is float):return float(a)==float(b)
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not equal_value(a[i],b[i]):return false
		return true
	return a==b

func gesture(point: Vector2,kind: String,expected: Dictionary={}) -> Dictionary:
	await process_frame
	stage=kind+"_press"
	var began:=Time.get_ticks_usec()
	scene.press(point,-1)
	var cpu_us:=Time.get_ticks_usec()-began
	await RenderingServer.frame_post_draw
	var visible_us:=Time.get_ticks_usec()-began
	var plan: Dictionary=scene.session.selection.duplicate(true)
	await sample_frames(8,kind+"_held")
	var release_us:=Time.get_ticks_usec()
	scene.release(point,-1)
	var release_cpu:=Time.get_ticks_usec()-release_us
	var row: Dictionary={"kind":kind,"press_cpu_us":cpu_us,"first_draw_us":visible_us,"release_cpu_us":release_cpu,"state":state()}
	if not expected.is_empty():
		for key in expected:
			if not equal_value(plan.get(key),expected[key]):errors.append("plan mismatch "+kind+" "+key)
		row.plan=expected
	rows.append(row)
	return plan

func wait_resolution() -> void:
	var deadline:=Time.get_ticks_msec()+120000
	while scene.session.phase in ["busy","enemy_attack"]:
		stage="fall" if scene.falling else ("enemy_attack" if scene.session.phase=="enemy_attack" else "clear_fx")
		await process_frame
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec()>deadline:
			errors.append("resolution timeout")
			return
	if scene.session.phase=="stalled":errors.append("refill stalled")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--result="):output=arg.substr(9)
	commands=JSON.parse_string(FileAccess.get_file_as_string("res://tests/performance_commands.json"))
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	viewport_rid=root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	RenderingServer.frame_post_draw.connect(after_frame)
	await sample_frames(30,"warmup")
	scene.bench.clear()
	recording=true
	await sample_frames(25,"idle")
	for cmd in commands:
		if not errors.is_empty():break
		match cmd.type:
			"skill":
				await gesture(scene.SKILL.get_center(),"skill_button")
				await gesture(scene.UI.color_rect(cmd.details.color).get_center(),"palette")
				await gesture(target(cmd.details.start_id),"skill",{"targets":cmd.details.targets,"connected":cmd.details.connected})
				await sample_frames(18,"skill_effect")
			"clear":
				var d: Dictionary=cmd.details
				await gesture(target(d.start_id),"clear",{"direct":d.direct,"removed":d.removed,"damage":d.damage,"base_damage":d.base_damage,"weak_count":d.weak_count,"weak_bonus":d.weak_bonus,"heal_effective":d.heal_effective})
				await wait_resolution()
				rows.append({"kind":"resolved","state":state()})
				await sample_frames(18,"settled")
			"reward_chosen":
				await gesture(scene.UI.reward_rect(scene.session.reward_options.find(cmd.details.id),scene.session.reward_options.size()).get_center(),"reward")
			"route_chosen":
				await gesture(scene.UI.route_rect(0 if cmd.details.choice=="safe" else 1).get_center(),"route")
				# Match the recorded normal flow's deliberate transition pause.
				# Frame counts alone can be shorter than its existing500ms
				# duplicate-tap guard when a renderer is faster.
				await create_timer(0.8).timeout
				await sample_frames(18,"next_fight")
			"shop_purchase":
				await gesture(scene.UI.shop_rect(0 if cmd.details.item=="heal" else 1).get_center(),"shop")
			"shop_exit":
				await gesture(scene.UI.SUMMARY_CONTINUE.get_center(),"shop_exit")
				await create_timer(0.8).timeout
				await sample_frames(18,"next_fight")
	await sample_frames(18,"terminal")
	recording=false
	var result: Dictionary={"errors":errors,"rows":rows,"frames":frames,"timings":scene.timings,"final":state(),"renderer":RenderingServer.get_video_adapter_name(),"method":"Preloaded recorded inputs, no policy/search/screenshot/disk writes during measured run. Rendering/logic instrumentation in isolated copies only. Render GPU time may be unsupported under Compatibility/llvmpipe."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit(0 if errors.is_empty() and scene.session.phase=="victory" else 1)

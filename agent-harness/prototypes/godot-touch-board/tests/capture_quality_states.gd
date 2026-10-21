extends SceneTree
## Quality acceptance with actual OS input and explicitly injected states.
## Frozen animation ages and constructed edge boards are NOT earned-run evidence.
var scene
var checks := 0
var failures := 0
var effects_only := false
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void: call_deferred("run")
func gesture(stage: String, point: Vector2, action: String = "click", capture: String = "") -> void:
	scene.queue_redraw()
	scene.board_surface.queue_redraw()
	scene.overlay_surface.queue_redraw()
	await RenderingServer.frame_post_draw
	var actual: Vector2 = root.get_screen_transform() * point + Vector2(root.position)
	var file := FileAccess.open("/tmp/chroma-quality-window-request.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage, "x":actual.x, "y":actual.y, "action":action, "capture":capture, "window_size":[root.size.x,root.size.y], "window_position":[root.position.x,root.position.y]}))
	file.close()
	var deadline := Time.get_ticks_msec() + 12000
	var acknowledged := false
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists("/tmp/chroma-quality-window-ack.json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("/tmp/chroma-quality-window-ack.json"))
			if data is Dictionary and data.get("stage", "") == stage:
				acknowledged = true
				break
		await process_frame
	check(acknowledged, "OS driver acknowledged " + stage)
	await process_frame
	await process_frame
func reset() -> void:
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	scene.record_timings=false
	scene.sound.muted=true
func shot(name:String) -> void:
	if effects_only and name not in ["05-activation-120ms","07-chain-damage-fx","08-heal-overheal-fx"]: return
	await gesture(name,Vector2.ZERO,"capture",name)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	effects_only = "--effects-only" in args
	root.size=Vector2i(int(args[0]),int(args[1]))
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	reset()
	await process_frame
	print("QUALITY FIXTURES: injected states and frozen presentation ages; NOT normal progression or performance evidence")
	await shot("01-ready")
	if "--hit-controls" in args:
		await gesture("effects-reduced",scene.UI.EFFECTS.get_center())
		check(scene.reduced_effects and scene.session.actions==0 and scene.session.selection.is_empty(),"OS reduced-effects control toggles without board passthrough")
		await shot("01b-reduced")
		await gesture("effects-full",scene.UI.EFFECTS.get_center())
		check(not scene.reduced_effects and scene.session.actions==0,"OS full effects restored without action")
		await gesture("audio-toggle",scene.MUTE.get_center())
		check(not scene.sound.muted and scene.session.actions==0,"OS mute control preserved")
		scene.sound.muted=true
	scene.session.charge=1
	await shot("02-charging-three")
	scene.session.charge_required=2
	scene.session.relics=["ash"]
	await shot("03-ash-charging-two")
	reset()
	await gesture("targeting",scene.SKILL.get_center())
	await gesture("color",scene.UI.color_rect(3).get_center())
	check(scene.session.skill_mode and scene.session.skill_color==3,"OS skill and palette choose water")
	await shot("04-targeting")
	await gesture("cancel-targeting",scene.SKILL.get_center())
	check(not scene.session.skill_mode and scene.quality_fx.cutin_remaining==0,"targeting cancel has no activation")
	await gesture("target-again",scene.SKILL.get_center())
	var chosen: Dictionary={}
	for p in scene.session.panels:
		if p.kind=="normal": chosen=p;break
	await gesture("activate",scene.board_to_screen(chosen.pos))
	check(scene.quality_fx.cutin_remaining>0 and scene.session.actions==0 and scene.session.phase=="ready","actual skill activates without action or input lock")
	scene.quality_fx.update(0.12)
	await shot("05-activation-120ms")
	await gesture("reset-fx",scene.RESET.get_center())
	check(scene.quality_fx.cutin_remaining==0 and scene.session.charge==3,"OS reset clears activation")
	# Deliberately constructed edge board; canonical plan and controller commit.
	var board:Array=[]
	for i in range(24):
		board.append({"id":i+1,"pos":Vector2(130+74*(i%6),370+74*(i/6)),"radius":37.0,"color":0,"kind":"core" if i<2 else "normal"})
	scene.session.panels=board.duplicate(true)
	scene.visual=board.duplicate(true)
	scene.session.next_id=100
	var at:Vector2=scene.board_to_screen(board[0].pos)
	await gesture("chain-down",at,"down")
	var plan:Dictionary=scene.session.selection.duplicate(true)
	check(plan.get("valid",false) and plan.get("activated",[]).size()>=2,"constructed edge board uses canonical core chain")
	await shot("06-chain-preview")
	await gesture("chain-up",at,"up")
	for id in plan.get("sequence",[]): scene._burst(id,0)
	scene.quality_fx.action_finished()
	scene.quality_fx.update(scene.clear_duration+0.04)
	await shot("07-chain-damage-fx")
	reset()
	board=[]
	for i in range(3): board.append({"id":i+1,"pos":Vector2(250+74*i,500),"radius":37.0,"color":4,"kind":"heart"})
	scene.session.panels=board.duplicate(true)
	scene.visual=board.duplicate(true)
	scene.session.hp=29
	scene.session.next_id=100
	await gesture("heal",scene.board_to_screen(board[0].pos))
	plan=scene.active_plan
	check(plan.get("heal_raw",0)==6 and plan.get("heal_effective",0)==1 and plan.get("heal_overflow",0)==5 and plan.get("damage",-1)==0 and scene.session.hp==30,"heart commit distinguishes raw and effective healing")
	for id in plan.get("sequence",[]): scene._burst(id,0)
	scene.quality_fx.action_finished()
	scene.quality_fx.update(0.12)
	await shot("08-heal-overheal-fx")
	if effects_only:
		print("QUALITY_EFFECTS checks=",checks," failures=",failures," size=",root.size)
		quit(1 if failures else 0)
		return
	reset()
	scene.session.phase="reward"
	scene.session.reward_round=1
	scene.session.reward_options=["pigment","lens","ash"]
	scene.session.offer_serial=7
	scene.session.combat.enemy_hp=0
	scene.session.gold=4
	await shot("09-reward")
	var reward:Vector2=scene.UI.reward_rect(0,3).get_center()
	await gesture("reward-down",reward,"down")
	await shot("10-reward-pressed")
	await gesture("reward-up",reward,"up")
	check(scene.session.phase=="route" and scene.session.relics.has("pigment"),"OS reward release chooses once and opens route")
	await shot("11-route")
	await gesture("route-stale-up",scene.UI.route_rect(0).get_center(),"up")
	check(scene.session.phase=="route" and scene.session.actions==0,"stale modal release cannot advance or clear")
	reset()
	scene.session.phase="shop"
	scene.session.combat.encounter=1
	scene.session.combat.enemy_hp=0
	scene.session.route="elite"
	scene.session.relics=["pigment","lens"]
	scene.session.gold=12
	scene.session.hp=17
	await shot("12-shop")
	await gesture("buy-heal",scene.UI.shop_rect(0).get_center())
	await gesture("buy-relic",scene.UI.shop_rect(1).get_center())
	check(scene.session.hp==25 and scene.session.gold==0 and scene.session.shop_heal_sold and scene.session.shop_relic_sold,"OS shop transactions apply once")
	await shot("13-shop-sold")
	scene.session.shop_heal_sold=false
	scene.session.shop_relic_sold=false
	scene.session.relics=["pigment","lens"]
	scene.session.hp=30
	await shot("14-shop-disabled")
	await gesture("disabled-heal",scene.UI.shop_rect(0).get_center())
	check(scene.session.gold==0 and scene.session.hp==30 and not scene.session.shop_heal_sold,"disabled shop click consumes nothing")
	reset()
	scene.session.relics=["pigment","lens","ash"]
	await gesture("details",scene.UI.owned_rect(2).get_center())
	check(scene.detail_relic=="ash","OS owned relic opens explanation")
	await shot("15-details")
	await gesture("detail-close",scene.UI.DETAIL_CLOSE.get_center())
	check(scene.detail_relic=="" and scene.session.actions==0,"detail close never passes through to board")
	for phase in ["victory","defeat"]:
		reset()
		scene.session.combat.encounter=2
		scene.session.phase=phase
		scene.session.hp=17 if phase=="victory" else 0
		scene.session.combat.enemy_hp=0 if phase=="victory" else 20
		await shot("16-"+phase)
		await gesture("restart-"+phase,scene.UI.RESTART.get_center())
		check(scene.session.phase=="ready" and scene.session.hp==30 and scene.session.relics.is_empty(),"OS terminal restart restores clean run: "+phase)
	print("QUALITY_WINDOW checks=",checks," failures=",failures," size=",root.size)
	quit(1 if failures else 0)

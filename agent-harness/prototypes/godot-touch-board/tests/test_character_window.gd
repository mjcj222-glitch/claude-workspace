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
	var args:=OS.get_cmdline_user_args()
	root.size=Vector2i(int(args[0]),int(args[1]))
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	scene.sound.muted=true;scene.record_timings=false
	await process_frame
	check(scene.session.phase=="departure","OS app starts at departure")
	await shot("01-departure")
	await gesture("noa-down-cancel",scene.UI.character_rect(1).get_center(),"down")
	await gesture("noa-outside",Vector2(12,208),"move")
	await gesture("noa-release-cancel",scene.UI.character_rect(1).get_center(),"up")
	check(scene.session.departure_choice=="","OS card moving outside cancels")
	await gesture("noa-candidate",scene.UI.character_rect(1).get_center())
	check(scene.session.departure_choice=="noa" and scene.session.character_id=="","OS card only selects candidate")
	await shot("02-noa-choice")
	await gesture("departure",scene.UI.DEPART.get_center())
	check(scene.session.character_id=="noa" and scene.session.phase=="ready","OS explicit departure commits noa")
	await create_timer(.55).timeout
	await shot("03-noa-ready")
	await gesture("noa-target",scene.SKILL.get_center())
	var panel:Dictionary={}
	for p in scene.session.panels:
		if p.kind=="normal":panel=p;break
	var point:Vector2=scene.board_to_screen(panel.pos)
	await gesture("noa-preview",point,"down")
	check(scene.session.selection.get("valid",false) and scene.session.selection.get("planted",{}).has(panel.id),"OS inverse pointer selects same normal")
	await shot("04-noa-preview")
	await gesture("noa-commit",point,"up")
	check(scene.session.skill_uses==1 and scene.session.actions==0 and scene.session.charge==0 and scene.session.panels.any(func(p):return p.id==panel.id and p.kind=="core"),"OS installation changes same ID only with no action")
	await shot("05-noa-charging3")
	# Explicit presentation fixtures for relic descriptions and charge2, no
	# claim that these relics were earned by the window-control probe.
	scene.session.relics=["pigment","ash"];scene.session.charge_required=2;scene.session.charge=1
	scene.quality_fx.reset();scene.hero_active=0
	await shot("06-noa-charging2-fixture")
	await gesture("noa-owned",scene.UI.owned_rect(0).get_center())
	check(scene.detail_relic=="pigment" and scene.UI.relic_copy("pigment",scene.session).change=="심는 핵: 일반핵 → 강화핵","OS owned detail matches noa effect")
	await shot("07-noa-relic-details-fixture")
	var before:int=scene.session.actions
	await gesture("detail-board",scene.UI.DETAIL_PANEL.get_center())
	check(scene.session.actions==before and scene.detail_relic=="pigment","OS detail blocks board")
	await gesture("detail-close",scene.UI.DETAIL_CLOSE.get_center())
	# Closing outside is allowed; if the previous board point was outside the
	# modal, it closed without any board action. Either way no passthrough.
	check(scene.detail_relic=="","OS detail closes")
	await gesture("reset",scene.RESET.get_center())
	check(scene.session.phase=="departure" and scene.session.character_id=="" and scene.session.relics.is_empty() and scene.session.charge==3,"OS reset returns fresh departure")
	await gesture("rio-candidate",scene.UI.character_rect(0).get_center())
	await gesture("rio-departure",scene.UI.DEPART.get_center())
	await create_timer(.55).timeout
	check(scene.session.character_id=="rio","OS can choose original hero after reset")
	await gesture("rio-target",scene.SKILL.get_center())
	await gesture("rio-color",scene.UI.color_rect(3).get_center())
	check(scene.session.skill_color==3 and scene.session.skill_mode,"OS original color palette stays touchable")
	await shot("08-rio-targeting")
	scene.session.phase="defeat";scene.session.cancel();scene.session.skill_mode=false
	await shot("09-result-fixture")
	await gesture("result-return",scene.UI.SUMMARY_CONTINUE.get_center())
	check(scene.session.phase=="departure" and scene.session.actions==0,"OS result returns to selection")
	await shot("10-returned")
	scene.queue_free();await process_frame
	print("CHARACTER_WINDOW checks=",checks," failures=",failures," size=",root.size)
	quit(1 if failures else 0)

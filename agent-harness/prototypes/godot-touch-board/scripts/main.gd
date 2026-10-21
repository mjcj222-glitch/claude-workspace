extends Node2D
const Session = preload("res://scripts/board_session.gd")
const RunSession = preload("res://scripts/board_run_session.gd")
const ATTACK_SECONDS := 0.45
const Motion = preload("res://scripts/board_motion.gd")
const Rules = preload("res://scripts/board_rules.gd")
const Art = preload("res://scripts/board_art.gd")
const UI = preload("res://scripts/board_ui.gd")
const Feedback = preload("res://scripts/board_feedback.gd")
const Sound = preload("res://scripts/board_audio.gd")
const COLORS := [Color("ff705d"), Color("6edb6b"), Color("ffcf5b"), Color("61b7ff"), Color("ff86b5")]
const BOARD := Rect2(30, 290, 660, 530)
const RESET = UI.RESET
const SKILL = UI.SKILL
const MUTE = UI.MUTE
var session = RunSession.new()
var sandbox := false
var run_seed := 20261021
var attack_clock := 0.0
var rng := RandomNumberGenerator.new()
var sound: Node
var font: Font
var font_bold: Font
var time := 0.0
var visual: Array = []
var particles: Array = []
var feedback = Feedback.new()
var detail_relic := ""
var detail_pointer := -99
var detail_index := -1
var detail_action := ""
var active_plan: Dictionary = {}
var action_clock := 0.0
var fall_clock := 0.0
var clear_duration := 0.0
var falling := false
var motion_state: Dictionary = {}
var fall_started_us := 0
var played := 0
var target_hit := 0.0
var hero_active := 0.0
var landing := 1.0
var status := "누르고 확인 · 놓으면 소거"
var last_summary := "같은 색 2개부터"
var pressed_us := 0
var feedback_pending := false
var committed_us := 0
var committed_frame := 0
var timings: Array = []
var record_timings := true
var run_start := 0
var capture_mode := false
var demo := false
var demo_step := 0
var demo_wait := 0.0
var demo_id := -1
var demo_point := Vector2.ZERO
var primary_touch := -99
var board_surface: Control
var overlay_surface: Node2D
var modal_pointer := -99
var modal_index := -1
var modal_offer := -1
var modal_phase := ""

class BoardSurface extends Control:
	var presenter: Node2D
	func _draw() -> void:
		if presenter: presenter.draw_panels(self)


class ModalSurface extends Node2D:
	var presenter: Node2D
	func _draw() -> void:
		if presenter:
			if presenter.session.phase in ["ready","busy"] and presenter.detail_relic=="" and presenter.session.selection.is_empty():
				presenter.feedback.draw_hud(presenter,self)
			presenter.UI.draw_modal(presenter,self)
			presenter.UI.draw_details(presenter,self)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font = load("res://assets/ChromaSans.otf") if ResourceLoader.exists("res://assets/ChromaSans.otf") else ThemeDB.fallback_font
	font_bold = font
	sound = Sound.new()
	add_child(sound)
	RenderingServer.frame_post_draw.connect(_after_draw)
	run_start = Time.get_ticks_usec()
	var args := OS.get_cmdline_user_args()
	sandbox = "--sandbox" in args
	for arg in args:
		if arg.begins_with("--seed="): run_seed = int(arg.trim_prefix("--seed="))
	demo = "--demo" in args and sandbox
	capture_mode = "--capture" in args
	board_surface = BoardSurface.new()
	board_surface.presenter = self
	board_surface.position = UI.BOARD_SCREEN.position
	board_surface.size = BOARD.size
	board_surface.clip_contents = true
	board_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_surface)
	overlay_surface = ModalSurface.new()
	overlay_surface.presenter = self
	add_child(overlay_surface)
	reset_board()

func reset_board() -> void:
	_cancel_modal()
	detail_relic=""
	feedback.reset()
	rng.seed = run_seed
	session = Session.new() if sandbox else RunSession.new()
	session.bounds = BOARD
	var packed := Motion.initial_board(BOARD, 48, 1, rng)
	if sandbox:
		session.panels = packed.panels
		session.next_id = packed.next_id
		# First board guarantees a readable six-link and one two-heart opportunity.
		var graph := Rules.contact_graph(session.panels)
		var start: int = session.panels[22].id
		var queue: Array = [start]
		var group: Array = []
		while not queue.is_empty() and group.size() < 7:
			var id: int = queue.pop_front()
			if id in group:
				continue
			group.append(id)
			for n in graph[id]:
				if n not in group: queue.append(n)
		for p in session.panels:
			if p.id in group:
				p.color = 0
				p.kind = "normal"
	else:
		session.initialize_board(packed.panels, packed.next_id)
	visual = session.panels.duplicate(true)
	particles.clear()
	active_plan = {}
	falling = false
	motion_state = {}
	action_clock = 0
	attack_clock = 0
	fall_clock = 0
	played = 0
	clear_duration = 0
	target_hit = 0
	hero_active = 0
	feedback_pending = false
	primary_touch = -99
	if sound:
		for voice in sound.voices: voice.stop()
		sound.cursor = 0
	landing = 1
	status = "누르고 확인 · 놓으면 소거"
	last_summary = "같은 색 2개부터"
	queue_redraw()

func _advance_fight() -> void:
	if sandbox or session.phase != "between": return
	var packed := Motion.initial_board(BOARD, 48, session.next_id, rng)
	if not session.begin_next_fight(packed.panels, packed.next_id): return
	_cancel_modal()
	detail_relic = ""
	feedback.reset()
	particles.clear()
	active_plan = {}
	motion_state = {}
	falling = false
	action_clock = 0
	attack_clock = 0
	feedback_pending = false
	landing = 1
	visual = session.panels.duplicate(true)
	status = "누르고 확인 · 놓으면 소거"
	last_summary = "전투 %d / 3 · 생명과 충전을 이어갑니다" % (session.combat.encounter + 1)
	queue_redraw()

func _text(at: Vector2, text: String, size: int, color: Color = Color("f3f2ef")) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
func _center(at: Vector2, text: String, size: int, color: Color = Color("f3f2ef")) -> void:
	_text(at - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0, 0), text, size, color)
func _box(rect: Rect2, color: Color, radius: int = 15, border: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1)
	draw_style_box(style, rect)

func _draw() -> void:
	UI.draw(self)

func board_to_screen(pos: Vector2) -> Vector2:
	return pos - BOARD.position + UI.BOARD_SCREEN.position

func screen_to_board(pos: Vector2) -> Vector2:
	return pos - UI.BOARD_SCREEN.position + BOARD.position

func draw_panels(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(-BOARD.position)
	var preview: Dictionary = session.selection
	for source in visual:
		var p: Dictionary = source.duplicate()
		var emphasis := ""
		var scale_factor := 1.0
		if not preview.is_empty() and preview.get("valid", false):
			if preview.mode == "skill":
				if p.id in preview.targets:
					emphasis = "convert"
					p.color = preview.converted[p.id]
				elif p.id in preview.connected: emphasis = "chain"
			else:
				if p.id in preview.direct: emphasis = "direct"
				elif p.id in preview.removed: emphasis = "chain"
				if preview.converted.has(p.id): p.color = preview.converted[p.id]
		if not active_plan.is_empty() and not falling and active_plan.mode == "clear" and p.id in active_plan.removed:
			var idx: int = active_plan.sequence.find(p.id)
			var onset := _clear_onset(idx)
			if action_clock > onset:
				scale_factor = maxf(0.0, 1.0 - (action_clock - onset) / 0.10)
		if scale_factor <= 0.01: continue
		# Landing squash is only visual; frozen selection suppresses residual motion.
		var squash := 1.0
		if session.selection.is_empty() and landing < 0.18:
			squash = 1.0 - sin(landing / 0.18 * PI) * 0.08
		var origin: Vector2 = p.pos
		canvas.draw_set_transform(origin - BOARD.position, 0, Vector2(1.0 + (1.0-squash)*0.5, squash))
		p.pos = Vector2.ZERO
		Art.draw_panel(canvas, p, time, emphasis, scale_factor)
		canvas.draw_set_transform(-BOARD.position)
	for particle in particles:
		var alpha: float = maxf(0.0, 1.0 - particle.age / particle.life)
		canvas.draw_circle(particle.pos, particle.size * alpha, Color(particle.color, alpha))

	feedback.draw_effects(canvas)

func _clear_onset(index: int) -> float:
	var count: int = active_plan.get("removed", []).size()
	var spacing := maxf(0.011, 0.032 - count * 0.0005)
	if count > 12:
		# Keep effect order, but cap the serial onset span before physical refill.
		spacing = minf(spacing, 0.28 / maxf(1.0, count - 1))
	return float(index) * spacing

func _process(delta: float) -> void:
	time += delta
	feedback.update(delta)
	target_hit = maxf(0, target_hit - delta * 4)
	hero_active = maxf(0, hero_active - delta * 2)
	landing += delta
	for particle in particles:
		particle.age += delta
		particle.pos += particle.vel * delta
	particles = particles.filter(func(p): return p.age < p.life)
	if session.phase == "busy":
		action_clock += delta
		if not falling:
			while played < active_plan.sequence.size() and action_clock >= _clear_onset(played):
				_burst(active_plan.sequence[played], played)
				played += 1
			if action_clock >= clear_duration:
				_start_fall()
		else:
			Motion.step(motion_state, BOARD, delta)
			visual = motion_state.panels
			if motion_state.stalled:
				session.phase = "stalled"
				status = "낙하 중단 · 리셋으로 다시 시험해 주세요"
			if motion_state.ready:
				session.panels = motion_state.panels.duplicate(true)
				falling = false
				session.finish_refill()
				attack_clock = 0
				_cancel_modal()
				visual = session.panels.duplicate(true)
				landing = 0
				sound.tone(0, false, true)
				status = "다음 연결을 찾아보세요"
				var metric := {"event":"commit_to_ready", "wall_ms":(Time.get_ticks_usec()-committed_us)/1000.0,"frames":Engine.get_process_frames()-committed_frame,"specials":active_plan.activated.size(),"removed":active_plan.removed.size(),"movie":capture_mode,"next_phase":session.phase}
				metric.profile=motion_state.profile.duplicate(true)
				metric.profile.clear_wall_ms=(fall_started_us-committed_us)/1000.0
				metric.profile.fall_wall_ms=(Time.get_ticks_usec()-fall_started_us)/1000.0
				metric.profile.fall_sim_s=motion_state.elapsed
				metric.profile.quiet_sim_s=motion_state.quiet
				if record_timings:
					timings.append(metric)
					print("TIMING ", JSON.stringify(metric))
				active_plan = {}
	elif not sandbox and session.phase == "enemy_attack":
		attack_clock += delta
		if attack_clock >= ATTACK_SECONDS:
			session.finish_attack()
			attack_clock = 0
			status = "반격 완료 · 다음 연결을 선택하세요"
	if demo: _demo(delta)
	queue_redraw()
	if board_surface: board_surface.queue_redraw()
	if overlay_surface: overlay_surface.queue_redraw()

func _burst(id: int, index: int) -> void:
	for p in visual:
		if p.id != id: continue
		if not feedback.consume(id,p.pos,COLORS[p.color]): return
		sound.tone(index)
		for i in range(7):
			var angle := TAU * i / 7.0
			particles.append({"pos":p.pos,"vel":Vector2.from_angle(angle)*rng.randf_range(65,180),"size":rng.randf_range(2,6),"color":COLORS[p.color],"age":0.0,"life":0.25})
		if p.kind != "heart": target_hit = 1
		break

func _start_fall() -> void:
	feedback.finish()
	fall_started_us=Time.get_ticks_usec()
	motion_state = Motion.start(session.panels, BOARD, 48, session.next_id, rng)
	session.next_id = motion_state.next_id
	visual = motion_state.panels
	falling = true
	fall_clock = 0
	sound.tone(mini(active_plan.removed.size(), 14), true)
	status = "채우는 중"

func _after_draw() -> void:
	if feedback_pending:
		var metric := {"event":"press_to_draw","wall_ms":(Time.get_ticks_usec()-pressed_us)/1000.0,"movie":capture_mode}
		timings.append(metric)
		print("TIMING ", JSON.stringify(metric))
		feedback_pending = false

func _cancel_modal() -> void:
	_cancel_detail_candidate()
	modal_pointer = -99
	modal_index = -1
	modal_offer = -1
	modal_phase = ""

func _cancel_detail_candidate() -> void:
	detail_pointer=-99
	detail_index=-1
	detail_action=""

func _detail_close_hit(pos:Vector2) -> bool:
	return UI.DETAIL_CLOSE.has_point(pos) or (Rect2(0,0,720,1080).has_point(pos) and not UI.DETAIL_PANEL.has_point(pos))

func cancel_input() -> void:
	session.cancel()
	_cancel_modal()

func move_pointer(pos: Vector2, pointer: int) -> void:
	session.move(screen_to_board(pos),pointer)
	if pointer==detail_pointer:
		if (detail_action=="open" and not UI.owned_rect(detail_index).has_point(pos)) or (detail_action=="close" and not _detail_close_hit(pos)):
			_cancel_detail_candidate()
	if pointer == modal_pointer:
		var rect: Rect2 = UI.reward_rect(modal_index,session.reward_options.size()) if modal_phase == "reward" else UI.SUMMARY_CONTINUE
		if not rect.has_point(pos): _cancel_modal()

func press(pos: Vector2, pointer: int) -> void:
	# Reset is the only transition input; all clocks and pending effects are owned here.
	if not sandbox and RESET.has_point(pos):
		reset_board()
		return
	if detail_relic!="":
		if RESET.has_point(pos):reset_board();return
		if detail_pointer==-99 and _detail_close_hit(pos):
			detail_pointer=pointer
			detail_action="close"
		return
	if detail_pointer!=-99:return
	if session.phase in ["reward","summary","between","victory","defeat"]:
		if RESET.has_point(pos):
			reset_board()
			return
		if modal_pointer != -99: return
		if session.phase == "reward":
			for i in range(session.reward_options.size()):
				if UI.reward_rect(i,session.reward_options.size()).has_point(pos):modal_index=i
		elif UI.SUMMARY_CONTINUE.has_point(pos):modal_index=0
		if modal_index>=0:
			modal_pointer=pointer
			modal_offer=session.offer_serial
			modal_phase=session.phase
		return
	if session.phase == "stalled" and RESET.has_point(pos):
		reset_board()
		return
	if session.owner != -99 or session.phase != "ready": return
	if RESET.has_point(pos):
		reset_board()
		return
	if MUTE.has_point(pos):
		sound.muted = not sound.muted
		return
	if session.phase != "ready": return
	if not session.skill_mode:
		for i in range(session.relics.size()):
			if UI.owned_rect(i).has_point(pos):
				detail_pointer=pointer
				detail_index=i
				detail_action="open"
				return
	if SKILL.has_point(pos):
		if session.charge >= session.charge_required:
			session.skill_mode = not session.skill_mode
			status = "색 선택 → 패널 선택" if session.skill_mode else "누르고 확인 · 놓으면 소거"
		return
	for i in range(4):
		if session.skill_mode and UI.color_rect(i).has_point(pos):
			session.skill_color = i
			return
	pressed_us = Time.get_ticks_usec()
	if session.begin(screen_to_board(pos), pointer):
		landing = 1
		feedback_pending = true
		queue_redraw()

func release(pos: Vector2, pointer: int) -> void:
	if detail_relic!="" or detail_pointer!=-99:
		if pointer!=detail_pointer:return
		var index:=detail_index
		var action:=detail_action
		_cancel_detail_candidate()
		if action=="close" and detail_relic!="" and _detail_close_hit(pos):detail_relic=""
		elif action=="open" and session.phase=="ready" and not session.skill_mode and session.owner==-99 and index>=0 and index<session.relics.size() and UI.owned_rect(index).has_point(pos):
			detail_relic=session.relics[index]
			session.cancel()
		return
	if session.phase in ["reward","summary","between","victory","defeat"] or modal_pointer != -99:
		if pointer != modal_pointer: return
		var index := modal_index
		var serial := modal_offer
		var previous_phase := modal_phase
		_cancel_modal()
		if session.phase != previous_phase: return
		if session.phase == "reward" and index < session.reward_options.size() and UI.reward_rect(index,session.reward_options.size()).has_point(pos):
			var id: String=session.reward_options[index]
			if session.choose_relic(id,serial):
				last_summary = Session.Relics.DEFS[id].name+" 획득"
				status="새 유물 적용 · 다음 연결을 선택하세요" if sandbox else "다음 전투를 눌러 출발하세요"
		elif session.phase == "between" and UI.SUMMARY_CONTINUE.has_point(pos):
			_advance_fight()
		elif session.phase in ["victory","defeat"] and UI.SUMMARY_CONTINUE.has_point(pos):
			reset_board()
		elif session.phase == "summary" and UI.SUMMARY_CONTINUE.has_point(pos):
			session.continue_summary()
			status="보상 2회 완료 · 자유롭게 계속 시험하세요"
		return
	var result: Dictionary = session.release(screen_to_board(pos), pointer)
	if result.is_empty(): return
	if result.mode == "skill":
		hero_active = 1
		visual = session.panels.duplicate(true)
		sound.tone(6, true)
		last_summary = "%d개 변환 완료 · 다음 소거로 연결하세요" % result.targets.size()
		status = "변환 완료 · 소거 횟수는 그대로"
		return
	feedback.start(result,visual)
	active_plan = result
	action_clock = 0
	played = 0
	falling = false
	clear_duration = _clear_onset(result.sequence.size()) + 0.12
	if result.sequence.size() > 12:
		clear_duration = _clear_onset(result.sequence.size()-1) + 0.10
	committed_us = Time.get_ticks_usec()
	committed_frame = Engine.get_process_frames()
	last_summary = "피해 %d  ·  회복 %d (유효 %d / 초과 %d)" % [result.damage,result.heal_raw,result.heal_effective,result.heal_overflow]
	if not result.spawn.is_empty(): last_summary += "  ·  " + ("강화핵 생성" if result.spawn.kind == "strong" else "물감핵 생성")
	status = "연쇄!" if result.activated.size() > 0 else "팝!"

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if primary_touch != -99: return
			primary_touch = event.index
			press(event.position, event.index)
		elif event.index == primary_touch:
			if event.canceled: cancel_input()
			else: release(event.position, event.index)
			primary_touch = -99
	elif event is InputEventScreenDrag:
		move_pointer(event.position, event.index)
	elif event is InputEventMouseButton and not event.device == InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press(event.position, -1)
			else: release(event.position, -1)
	elif event is InputEventMouseMotion:
		move_pointer(event.position, -1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		detail_relic=""
		cancel_input()
		session.skill_mode = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		if session != null: cancel_input()
		primary_touch = -99

func _demo(delta: float) -> void:
	if session.phase == "reward":
		var point: Vector2=UI.reward_rect(0,session.reward_options.size()).get_center()
		press(point,-1)
		release(point,-1)
	demo_wait += delta
	if demo_step == 0 and demo_wait > 1.0:
		_demo_select(false, 6)
		demo_step = 1
		demo_wait = 0
	elif demo_step == 1 and demo_wait > 1.0:
		release(demo_point, -1)
		demo_step = 2
		demo_wait = 0
	elif demo_step == 2 and session.phase == "ready" and demo_wait > 1.4:
		_demo_select(true, 1)
		demo_step = 3
		demo_wait = 0
	elif demo_step == 3 and demo_wait > 1.0:
		release(demo_point, -1)
		demo_step = 4
		demo_wait = 0
	elif demo_step == 4 and session.phase == "ready" and demo_wait > 1.4:
		session.skill_mode = true
		session.skill_color = 2
		for p in session.panels:
			if p.kind == "normal":
				demo_point = board_to_screen(p.pos)
				press(demo_point, -1)
				break
		demo_step = 5
		demo_wait = 0
	elif demo_step == 5 and demo_wait > 1.0:
		release(demo_point, -1)
		demo_step = 6
		demo_wait = 0
	elif demo_step == 6 and demo_wait > 1.0:
		_demo_select(false, 2)
		demo_step = 7
		demo_wait = 0
	elif demo_step == 7 and demo_wait > 0.8:
		release(demo_point, -1)
		demo_step = 8
		demo_wait = 0
	elif demo_step == 8 and session.phase == "ready" and demo_wait > 1.4:
		var file := FileAccess.open("/tmp/chroma-timings.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(timings, "  "))
		get_tree().quit()

func _demo_select(special: bool, minimum: int) -> void:
	var best: Dictionary = {}
	for p in session.panels:
		if special and p.kind not in ["core", "strong"]: continue
		var plan: Dictionary = session.plan_for(p.id)
		if plan.valid and plan.removed.size() >= minimum:
			best = p
			break
	if best.is_empty():
		for p in session.panels:
			if session.plan_for(p.id).valid:
				best = p
				break
	if not best.is_empty():
		demo_point = board_to_screen(best.pos)
		press(demo_point, -1)

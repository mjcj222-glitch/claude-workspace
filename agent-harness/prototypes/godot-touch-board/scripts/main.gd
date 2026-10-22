extends Node2D
const Session = preload("res://scripts/board_session.gd")
const LegacyRunSession = preload("res://scripts/board_run_session.gd")
const RunSession = preload("res://scripts/board_area_session.gd")
const AreaUI = preload("res://scripts/board_area_ui.gd")
const ATTACK_SECONDS := 0.45
const TRANSITION_REPEAT_MS := 500
const TRANSITION_REPEAT_RADIUS := 44.0
const Motion = preload("res://scripts/board_motion.gd")
const Rules = preload("res://scripts/board_rules.gd")
const Layout = preload("res://scripts/board_layout.gd")
const PanelView = preload("res://scripts/board_panel_view.gd")
const Art = preload("res://scripts/board_art.gd")
const UI = preload("res://scripts/board_ui.gd")
const Bombs=preload("res://scripts/board_bombs.gd")
const Feedback = preload("res://scripts/board_feedback.gd")
const QualityFX = preload("res://scripts/board_quality_fx.gd")
const Sound = preload("res://scripts/board_audio.gd")
const COLORS := [Color("ff705d"), Color("6edb6b"), Color("ffcf5b"), Color("61b7ff"), Color("ff86b5")]
const BOARD := Rect2(30, 290, 660, 530)
const RESET = UI.RESET
const SKILL = UI.SKILL
const MUTE = UI.MUTE
var session = RunSession.new()
var sandbox := false
var short_run := false
var run_seed := 20261021
var fixed_seed := false
var configured_seed := 20261021
var lifecycle=preload("res://scripts/board_lifecycle.gd").new()
var attack_clock := 0.0
var transition_repeat_until_ms := 0
var transition_repeat_at := Vector2.INF
var rng := RandomNumberGenerator.new()
var particle_rng := RandomNumberGenerator.new()
var sound: Node
var font: Font
var font_bold: Font
var font_display: Font
var font_body: Font
var ready_age := 0.0
var _skill_was_ready := true
var time := 0.0
var visual: Array = []
var particles: Array = []
var feedback = Feedback.new()
var quality_fx = QualityFX.new()
var reduced_effects := false
var selection_trace: Array = []
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
var shop_notice := ""
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
			if presenter.session.selection.is_empty(): presenter.quality_fx.draw_overlay(presenter,self)
			if presenter.session.phase in ["ready","busy"] and presenter.detail_relic=="" and presenter.session.selection.is_empty():
				presenter.feedback.draw_hud(presenter,self)
			presenter.UI.draw_modal(presenter,self)
			presenter.UI.draw_details(presenter,self)
			presenter.lifecycle.draw(presenter,self)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font = load("res://assets/fonts/Pretendard-Medium.otf")
	font_body = font
	font_bold = load("res://assets/fonts/Pretendard-SemiBold.otf")
	font_display = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	font_display.fallbacks = [font]
	sound = Sound.new()
	add_child(sound)
	RenderingServer.frame_post_draw.connect(_after_draw)
	run_start = Time.get_ticks_usec()
	var args := OS.get_cmdline_user_args()
	sandbox = "--sandbox" in args
	short_run = "--short-run" in args
	for arg in args:
		if arg.begins_with("--seed="):
			run_seed = int(arg.trim_prefix("--seed="))
			fixed_seed = true
			configured_seed = run_seed
	demo = "--demo" in args and sandbox
	capture_mode = "--capture" in args
	board_surface = BoardSurface.new()
	board_surface.presenter = self
	board_surface.position = Layout.board_to_screen(BOARD.position,BOARD,UI.BOARD_SCREEN)
	board_surface.size = BOARD.size
	board_surface.scale = Layout.board_scale(BOARD,UI.BOARD_SCREEN)
	board_surface.clip_contents = true
	board_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_surface)
	overlay_surface = ModalSurface.new()
	overlay_surface.presenter = self
	add_child(overlay_surface)
	reset_board()
	lifecycle.setup(self,args)

func reset_board() -> void:
	_cancel_modal()
	detail_relic=""
	shop_notice=""
	feedback.reset()
	quality_fx.reset()
	selection_trace.clear()
	ready_age = 0.0
	_skill_was_ready = true
	if fixed_seed:
		run_seed=configured_seed
	else:
		var entropy=RandomNumberGenerator.new()
		entropy.randomize()
		var fresh=int(entropy.randi())
		run_seed=fresh if fresh!=run_seed else (fresh+1) % 4294967296
	rng.seed = run_seed
	particle_rng.seed = run_seed ^ 0x514C495459
	session = Session.new() if sandbox else (LegacyRunSession.new() if short_run else RunSession.new())
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
		session.open_departure()
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
	transition_repeat_until_ms = 0
	transition_repeat_at = Vector2.INF
	if sound:
		sound.reset_feedback()
	landing = 1
	status = "누르고 확인 · 놓으면 소거"
	last_summary = "같은 색 2개부터"
	queue_redraw()

func _advance_fight(departure_point: Vector2 = Vector2.INF) -> void:
	if sandbox or session.phase != "between": return
	var packed := Motion.initial_board(BOARD, 48, session.next_id, rng)
	if not session.begin_next_fight(packed.panels, packed.next_id): return
	if departure_point.is_finite():
		# Suppress only a repeated departing-control tap. Other board targets
		# remain available immediately; physics/readiness are unchanged.
		transition_repeat_at = departure_point
		transition_repeat_until_ms = Time.get_ticks_msec() + TRANSITION_REPEAT_MS
	_cancel_modal()
	detail_relic = ""
	shop_notice = ""
	feedback.reset()
	quality_fx.reset()
	selection_trace.clear()
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

func _enter_area_node(at:Vector2,serial:int)->void:
	if session.phase!="map" or session.selected_node=="":return
	var node:Dictionary=session.NODES[session.selected_node]
	var packed:Dictionary={"panels":[],"next_id":session.next_id}
	if node.kind=="fight":
		packed={"panels":session.panels.duplicate(true),"next_id":session.next_id} if session.history.is_empty() else Motion.initial_board(BOARD,48,session.next_id,rng)
	if not session.enter_node(serial,packed.panels,packed.next_id):return
	transition_repeat_at=at;transition_repeat_until_ms=Time.get_ticks_msec()+TRANSITION_REPEAT_MS
	feedback.reset();quality_fx.reset();selection_trace.clear();particles.clear();active_plan={};motion_state={};falling=false
	action_clock=0;attack_clock=0;feedback_pending=false;target_hit=0;hero_active=0;landing=1
	visual=session.panels.duplicate(true)
	status="누르고 확인 · 놓으면 소거"

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
	return Layout.board_to_screen(pos,BOARD,UI.BOARD_SCREEN)

func screen_to_board(pos: Vector2) -> Vector2:
	return Layout.screen_to_board(pos,BOARD,UI.BOARD_SCREEN)

func draw_panels(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(-BOARD.position)
	var preview: Dictionary = session.selection
	if preview.get("valid",false) and preview.get("mode","")=="clear":
		for blast in preview.get("blasts",[]):
			canvas.draw_arc(blast.pos,blast.radius,0,TAU,64,Color(1,.68,.25,.7),2.4,true)
	for source in PanelView.draw_order(visual):
		var p: Dictionary = source.duplicate()
		var emphasis := ""
		var scale_factor := 1.0
		if not preview.is_empty() and preview.get("valid", false):
			if preview.mode == "skill":
				if p.id in preview.targets:
					emphasis = "convert"
					if preview.converted.has(p.id):p.color = preview.converted[p.id]
					if preview.get("planted",{}).has(p.id):p.kind=preview.planted[p.id]
				elif p.id in preview.connected: emphasis = "chain"
			else:
				if p.id in preview.direct: emphasis = "direct"
				elif p.id in preview.removed: emphasis = "chain"
				if preview.converted.has(p.id): p.color = preview.converted[p.id]
		if not active_plan.is_empty() and not falling and active_plan.mode == "clear" and p.id in active_plan.removed:
			if active_plan.converted.has(p.id): p.color = active_plan.converted[p.id]
			var idx: int = active_plan.sequence.find(p.id)
			var onset := _clear_onset(idx)
			if action_clock > onset:
				scale_factor = maxf(0.0, 1.0 - (action_clock - onset) / 0.10)
		if scale_factor <= 0.01: continue
		# Landing squash is only visual; frozen selection suppresses residual motion.
		var squash := 1.0
		if not Bombs.is_bomb(p.kind) and not reduced_effects and session.selection.is_empty() and landing < 0.18:
			squash = 1.0 - sin(landing / 0.18 * PI) * 0.08
		var origin: Vector2 = p.pos
		canvas.draw_set_transform(origin - BOARD.position, 0, Vector2(1.0 + (1.0-squash)*0.5, squash))
		p.pos = Vector2.ZERO
		Art.draw_panel(canvas, p, time, emphasis, scale_factor)
		canvas.draw_set_transform(-BOARD.position)
	if not preview.is_empty() and preview.get("valid",false):
		# Short curved stitches only cross actual contact boundaries. They never
		# imply a drag path or a connection to a future falling position.
		for edge in selection_trace:
			var a: Vector2=edge[0]
			var b: Vector2=edge[1]
			var direction := a.direction_to(b)
			var middle := a.lerp(b,0.5)
			var points := PackedVector2Array()
			for i in range(9):
				var t := float(i)/8.0
				points.append(middle+direction*lerpf(-10,10,t)+direction.orthogonal()*sin(PI*t)*2.5)
			canvas.draw_polyline(points,Color(0.15,0.95,0.83,0.30),7,true)
			canvas.draw_polyline(points,Color("e8fff4"),2.1,true)
	for particle in ([] if reduced_effects else particles):
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
	if lifecycle.modal!="":
		queue_redraw()
		if overlay_surface:overlay_surface.queue_redraw()
		return
	time += delta
	feedback.update(delta)
	var now_ready: bool = session.charge >= session.charge_required
	if now_ready and not _skill_was_ready: ready_age = 0.0
	if now_ready and session.phase == "ready": ready_age += delta
	elif not now_ready: ready_age = -1.0
	_skill_was_ready = now_ready
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
	quality_fx.update(delta)
	var impact:Dictionary=quality_fx.take_impact()
	if not impact.is_empty():
		target_hit=1.0
		sound.impact(int(impact.tier),int(impact.weak_bonus)>0)
		if record_timings:timings.append({"event":"attack_impact","damage":impact.damage,"base_damage":impact.base_damage,"weak_bonus":impact.weak_bonus,"action_clock":action_clock,"encounter":-1 if sandbox else session.combat.encounter})
	lifecycle.checkpoint(self)
	if demo: _demo(delta)
	queue_redraw()
	if board_surface: board_surface.queue_redraw()
	if overlay_surface: overlay_surface.queue_redraw()

func _burst(id: int, index: int) -> void:
	for p in visual:
		if p.id != id: continue
		var color_index: int=active_plan.get("effective_colors",{}).get(id,p.color) if p.kind=="normal" else p.color
		var effect_color: Color=COLORS[color_index]
		if not feedback.consume(id,p.pos,effect_color): return
		quality_fx.panel_removed(id,p.pos,effect_color,p.kind)
		sound.panel(index,p.kind)
		_advance_clear_rng_budget()
		for i in range(7):
			var angle := TAU * i / 7.0
			particles.append({"pos":p.pos,"vel":Vector2.from_angle(angle)*particle_rng.randf_range(65,180),"size":particle_rng.randf_range(2,6),"color":effect_color,"age":0.0,"life":0.25})
		break

func _advance_clear_rng_budget() -> void:
	# Fixed compatibility budget, independent of the visual particle loop.
	# Removing it would change every later refill for an existing seed/input.
	for i in range(7):
		rng.randf_range(65,180)
		rng.randf_range(2,6)

func _start_fall() -> void:
	feedback.finish()
	quality_fx.action_finished()
	fall_started_us=Time.get_ticks_usec()
	motion_state = Motion.start(session.panels, BOARD, 48, session.next_id, rng)
	Bombs.prepare_supply(motion_state.pending,String(active_plan.get("bomb_spawn_kind","")),int(active_plan.get("bomb_spawn_color",0)))
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
	lifecycle.cancel()
	session.cancel()
	selection_trace.clear()
	_cancel_modal()

func _cache_selection_trace() -> void:
	selection_trace.clear()
	var plan: Dictionary=session.selection
	if plan.is_empty() or not plan.get("valid",false): return
	var ids: Array=plan.targets if plan.get("mode","")=="skill" else plan.direct
	var indexed: Dictionary={}
	for p in session.panels:
		if p.id in ids: indexed[p.id]=p
	var graph := Rules.contact_graph(session.panels)
	for id in indexed:
		for neighbor in graph[id]:
			if neighbor>id and indexed.has(neighbor):
				selection_trace.append([indexed[id].pos,indexed[neighbor].pos])

func move_pointer(pos: Vector2, pointer: int) -> void:
	if lifecycle.modal!="" or lifecycle.choice==2:lifecycle.move(pos,pointer);return
	session.move(screen_to_board(pos),pointer)
	if pointer==detail_pointer:
		if (detail_action=="open" and not UI.owned_rect(detail_index).has_point(pos)) or (detail_action=="close" and not _detail_close_hit(pos)):
			_cancel_detail_candidate()
	if pointer == modal_pointer:
		var rect: Rect2 = UI.modal_rect(modal_phase,modal_index,session.reward_options.size())
		if not rect.has_point(pos): _cancel_modal()

func press(pos: Vector2, pointer: int) -> void:
	if lifecycle.modal!="":lifecycle.press(pos,pointer);return
	if lifecycle.choice==2:return
	if lifecycle.retry_hit(pos):
		if session.owner==-99 and modal_pointer==-99 and detail_pointer==-99:lifecycle.press_retry(pos,pointer)
		return
	# Reset is the only transition input; all clocks and pending effects are owned here.
	if not sandbox and RESET.has_point(pos):
		lifecycle.request_new(self)
		return
	if MUTE.has_point(pos) and session.owner==-99 and modal_pointer==-99 and detail_pointer==-99:
		sound.muted=not sound.muted
		return
	if UI.EFFECTS.has_point(pos) and session.owner==-99 and modal_pointer==-99 and detail_pointer==-99:
		reduced_effects=not reduced_effects
		quality_fx.reduced_effects=reduced_effects
		feedback.reduced_effects=reduced_effects
		return
	if session.phase in ["ready","departure"] and Time.get_ticks_msec() < transition_repeat_until_ms and pos.distance_to(transition_repeat_at) <= TRANSITION_REPEAT_RADIUS:
		return
	if detail_relic!="":
		if RESET.has_point(pos):lifecycle.request_new(self);return
		if detail_pointer==-99 and _detail_close_hit(pos):
			detail_pointer=pointer
			detail_action="close"
		return
	if detail_pointer!=-99:return
	if session.phase in ["map","rest","event","spoils","departure","reward","summary","route","shop","between","victory","defeat"]:
		if RESET.has_point(pos):
			lifecycle.request_new(self)
			return
		if modal_pointer != -99: return
		if AreaUI.active(session.phase):
			modal_index=AreaUI.hit(session.phase,pos)
		elif session.phase=="departure":
			for i in range(2):
				if UI.character_rect(i).has_point(pos):modal_index=i
			if UI.DEPART.has_point(pos):modal_index=2
		elif session.phase == "reward":
			for i in range(session.reward_options.size()):
				if UI.reward_rect(i,session.reward_options.size()).has_point(pos):modal_index=i
		elif session.phase in ["route","shop"]:
			for i in range(2):
				if UI.modal_rect(session.phase,i).has_point(pos): modal_index=i
			if session.phase == "shop" and UI.SUMMARY_CONTINUE.has_point(pos): modal_index=2
		elif UI.SUMMARY_CONTINUE.has_point(pos):modal_index=0
		if modal_index>=0:
			modal_pointer=pointer
			modal_offer=session.offer_serial
			modal_phase=session.phase
		return
	if session.phase == "stalled" and RESET.has_point(pos):
		lifecycle.request_new(self)
		return
	if session.owner != -99 or session.phase != "ready": return
	if RESET.has_point(pos):
		lifecycle.request_new(self)
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
			status = ("일반 패널 선택 → 핵 심기" if session.character_id=="noa" else "색 선택 → 패널 선택") if session.skill_mode else "누르고 확인 · 놓으면 소거"
		return
	for i in range(4):
		if session.skill_mode and session.character_id!="noa" and UI.color_rect(i).has_point(pos):
			session.skill_color = i
			return
	pressed_us = Time.get_ticks_usec()
	if session.begin(screen_to_board(pos), pointer):
		_cache_selection_trace()
		landing = 1
		feedback_pending = true
		queue_redraw()

func release(pos: Vector2, pointer: int) -> void:
	if lifecycle.modal!="" or lifecycle.choice==2:lifecycle.release(self,pos,pointer);return
	_release_action(pos,pointer)
	lifecycle.dirty=true
	lifecycle.checkpoint(self)

func _release_action(pos: Vector2, pointer: int) -> void:
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
	if session.phase in ["map","rest","event","spoils","departure","reward","summary","route","shop","between","victory","defeat"] or modal_pointer != -99:
		if pointer != modal_pointer: return
		var index := modal_index
		var serial := modal_offer
		var previous_phase := modal_phase
		_cancel_modal()
		if session.phase != previous_phase or serial != session.offer_serial: return
		if AreaUI.active(session.phase) and AreaUI.rect(session.phase,index).has_point(pos):
			if session.phase=="map":
				if index<8:session.select_node(AreaUI.ORDER[index],serial)
				else:_enter_area_node(pos,serial)
			elif session.phase=="rest":session.rest_choice("heal" if index==0 else "leave",serial)
			elif session.phase=="event":session.event_choice("trade" if index==0 else "supplies",serial)
			else:session.confirm_spoils(serial)
		elif session.phase=="departure" and UI.modal_rect("departure",index).has_point(pos):
			if index in [0,1]:session.select_departure(Session.Characters.IDS[index],serial)
			elif index==2 and session.start_departure(serial):
				transition_repeat_at=pos
				transition_repeat_until_ms=Time.get_ticks_msec()+TRANSITION_REPEAT_MS
				status="능력을 확인하고 첫 연결을 선택하세요"
		elif session.phase == "reward" and index < session.reward_options.size() and UI.reward_rect(index,session.reward_options.size()).has_point(pos):
			var id: String=session.reward_options[index]
			if session.choose_relic(id,serial):
				last_summary = Session.Relics.DEFS[id].name+" 획득"
				status="새 유물 적용 · 다음 연결을 선택하세요" if sandbox else "다음 경로를 골라주세요"
				shop_notice=""
		elif session.phase == "route" and index in [0,1] and UI.route_rect(index).has_point(pos):
			if session.choose_route("safe" if index == 0 else "elite"):
				_advance_fight(pos)
		elif session.phase == "shop" and UI.modal_rect("shop",index).has_point(pos):
			if index == 2:
				if session.leave_shop(): _advance_fight(pos)
			elif index in [0,1]:
				var hp_before: int = session.hp
				var gold_before: int = session.gold
				var bought_relic: String = session.shop_remaining_relic()
				if session.buy_shop("heal" if index == 0 else "relic"):
					shop_notice = ("생명 +%d" % (session.hp-hp_before) if index == 0 else Session.Relics.DEFS[bought_relic].name+" 획득") + " · %d G 사용" % (gold_before-session.gold)
				else:
					shop_notice = "잔액·재고·생명을 확인해 주세요"
		elif session.phase == "between" and UI.SUMMARY_CONTINUE.has_point(pos):
			_advance_fight()
		elif session.phase in ["victory","defeat"] and UI.SUMMARY_CONTINUE.has_point(pos):
			lifecycle.request_new(self)
		elif session.phase == "summary" and UI.SUMMARY_CONTINUE.has_point(pos):
			session.continue_summary()
			status="보상 2회 완료 · 자유롭게 계속 시험하세요"
		return
	var hp_before:int=-1 if sandbox else session.combat.enemy_hp
	var result: Dictionary = session.release(screen_to_board(pos), pointer)
	selection_trace.clear()
	if result.is_empty(): return
	if result.mode == "skill":
		hero_active = 1
		var changed:Dictionary={}
		for p in visual:
			if result.converted.has(p.id) and p.color!=result.converted[p.id]:changed[p.id]=result.converted[p.id]
		quality_fx.skill_activated(changed)
		visual = session.panels.duplicate(true)
		sound.tone(6, true)
		last_summary = "핵 설치 완료 · 다음 입력에서 눌러 기동" if session.character_id=="noa" else "%d개 변환 완료 · 다음 소거로 연결하세요" % result.targets.size()
		status = "핵 심기 완료 · 소거 횟수는 그대로" if session.character_id=="noa" else "변환 완료 · 소거 횟수는 그대로"
		return
	feedback.start(result,visual)
	active_plan = result
	action_clock = 0
	played = 0
	falling = false
	clear_duration = _clear_onset(result.sequence.size()) + 0.12
	if result.sequence.size() > 12:
		clear_duration = _clear_onset(result.sequence.size()-1) + 0.10
	quality_fx.action_started(result,visual,clear_duration,hp_before)
	committed_us = Time.get_ticks_usec()
	committed_frame = Engine.get_process_frames()
	last_summary = UI.damage_line(result) + " · 회복 %d" % result.heal_effective if not sandbox else "피해 %d  ·  회복 %d (유효 %d / 초과 %d)" % [result.damage,result.heal_raw,result.heal_effective,result.heal_overflow]
	if result.get("bomb_spawn_kind","")!="":last_summary+=" · "+("대형 폭탄 준비" if result.bomb_spawn_kind=="big_bomb" else "폭탄 준비")
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
			if event.pressed and event.double_click and session.phase in ["ready","departure"] and transition_repeat_until_ms > 0 and event.position.distance_to(transition_repeat_at) <= TRANSITION_REPEAT_RADIUS:
				return
			if event.pressed: press(event.position, -1)
			else: release(event.position, -1)
	elif event is InputEventMouseMotion:
		move_pointer(event.position, -1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		detail_relic=""
		cancel_input()
		session.skill_mode = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if lifecycle.request_quit(self):get_tree().quit()
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

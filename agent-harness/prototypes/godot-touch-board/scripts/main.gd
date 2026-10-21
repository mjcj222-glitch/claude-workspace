extends Node2D
const Session = preload("res://scripts/board_session.gd")
const Motion = preload("res://scripts/board_motion.gd")
const Rules = preload("res://scripts/board_rules.gd")
const Art = preload("res://scripts/board_art.gd")
const Sound = preload("res://scripts/board_audio.gd")
const COLORS := [Color("ff705d"), Color("6edb6b"), Color("ffcf5b"), Color("61b7ff"), Color("ff86b5")]
const BOARD := Rect2(30, 290, 660, 530)
const RESET := Rect2(558, 24, 130, 64)
const SKILL := Rect2(181, 884, 362, 90)
const MUTE := Rect2(565, 895, 118, 77)
var session = Session.new()
var rng := RandomNumberGenerator.new()
var sound: Node
var font: Font
var font_bold: Font
var time := 0.0
var visual: Array = []
var particles: Array = []
var active_plan: Dictionary = {}
var action_clock := 0.0
var fall_clock := 0.0
var clear_duration := 0.0
var falling := false
var played := 0
var target_hit := 0.0
var hero_active := 0.0
var landing := 1.0
var status := "누르고 확인 · 놓으면 터져요"
var last_summary := "같은 색 2개부터 · 6 / 12개 연결 → 물감핵"
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

class BoardSurface extends Control:
	var presenter: Node2D
	func _draw() -> void:
		if presenter: presenter.draw_panels(self)


func _ready() -> void:
	font = load("res://assets/ChromaSans.otf") if ResourceLoader.exists("res://assets/ChromaSans.otf") else ThemeDB.fallback_font
	font_bold = font
	sound = Sound.new()
	add_child(sound)
	RenderingServer.frame_post_draw.connect(_after_draw)
	run_start = Time.get_ticks_usec()
	var args := OS.get_cmdline_user_args()
	demo = "--demo" in args
	capture_mode = "--capture" in args
	board_surface = BoardSurface.new()
	board_surface.presenter = self
	board_surface.position = BOARD.position
	board_surface.size = BOARD.size
	board_surface.clip_contents = true
	board_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_surface)
	reset_board()

func reset_board() -> void:
	rng.seed = 20261021
	session = Session.new()
	session.bounds = BOARD
	var packed := Motion.pack([], BOARD, 48, 1, rng)
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
	visual = session.panels.duplicate(true)
	particles.clear()
	active_plan = {}
	falling = false
	action_clock = 0
	landing = 1
	status = "누르고 확인 · 놓으면 터져요"
	last_summary = "같은 색 2개부터 · 6 / 12개 연결 → 물감핵"
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
	draw_rect(Rect2(0, 0, 720, 1080), Color("101219"))
	for i in range(12):
		draw_circle(Vector2(360, 320), 480 - i * 24, Color(0.035, 0.038, 0.062, 0.08))
	_text(Vector2(31, 57), "C H R O M A", 25)
	_text(Vector2(32, 80), "TOUCH LAB  /  물감 연쇄 실험실", 18, Color("8f96ad"))
	_box(RESET, Color("252a38"), 10, Color("3a4255"))
	_center(Vector2(623, 65), "↻ 리셋", 23)
	_text(Vector2(34, 126), "누적 피해", 21, Color("929ab0"))
	_text(Vector2(32, 165), str(session.damage_total).pad_zeros(3), 35, COLORS[0])
	_text(Vector2(34, 192), "반격 없는 표적", 18, Color("929ab0"))
	Art.draw_target(self, Vector2(360, 160), time, target_hit)
	_text(Vector2(565, 126), "생명", 21, Color("929ab0"))
	_text(Vector2(565, 160), "%d / %d" % [session.hp, session.max_hp], 25, COLORS[4])
	_box(Rect2(565, 176, 118, 6), Color("302938"), 3)
	_box(Rect2(565, 176, 118 * float(session.hp) / session.max_hp, 6), COLORS[4], 3)
	for i in range(3):
		draw_circle(Vector2(40 + i * 20, 228), 5, COLORS[2] if i < session.actions % 3 else Color("39404f"))
	_text(Vector2(104, 233), "TURN %02d" % (session.actions / 3 + 1), 20, Color("b6bdd0"))
	_text(Vector2(517, 233), "충전 %d / 3" % session.charge, 21, COLORS[1])
	_box(Rect2(25, 247, 670, 590), Color("080a0f"), 24, Color("384050"))
	_box(Rect2(34, 255, 652, 31), Color("151a23"), 12)
	var preview: Dictionary = session.selection
	var line := status
	if not preview.is_empty():
		if not preview.valid:
			line = "연결된 패널 2개 이상을 골라주세요"
		elif preview.mode == "skill":
			line = "%d개 변환  →  같은 색 연결 %d개  /  놓으면 적용" % [preview.targets.size(), preview.connected.size()]
		else:
			line = "직접 %d + 연쇄 %d   피해 %d / 회복 +%d" % [preview.direct.size(), preview.removed.size() - preview.direct.size(), preview.damage, preview.heal_effective]
	_center(Vector2(360, 277), line, 22, Color("e1e5f1"))
	# Faint walls, never draw fake connectivity bridges.
	for y in range(310, 810, 25):
		draw_circle(Vector2(40, y), 1, Color("242a35"))
		draw_circle(Vector2(680, y), 1, Color("242a35"))
	_box(Rect2(41, 846, 638, 27), Color("1a1e29"), 10)
	_center(Vector2(360, 865), last_summary, 20, Color("bec5d7"))
	Art.draw_hero(self, Vector2(102, 935), time, hero_active)
	_center(Vector2(102, 1001), "리오 · 변환사", 20, Color("b4b9cf"))
	var skill_ready: bool = session.charge >= 3
	_box(SKILL, Color("22393d") if skill_ready else Color("242735"), 18, COLORS[1] if session.skill_mode else Color("3b4e59"))
	_text(Vector2(202, 913), "색을 잇는 붓", 25, Color("e9f7f2"))
	_text(Vector2(202, 940), "최대 4개 변환 · 소거 무료", 20, Color("a7bdc4"))
	_text(Vector2(202, 961), "패널을 눌러 미리보기" if session.skill_mode else ("사용 가능  →  탭하여 선택" if skill_ready else "수동 소거 %d회 후 준비" % (3-session.charge)), 19, COLORS[1] if skill_ready else Color("8e96ad"))
	_box(MUTE, Color("252a38"), 11)
	_center(Vector2(624, 945), "소리 OFF" if sound.muted else "소리 ON", 21)
	for i in range(4):
		var rect := Rect2(190 + i * 88, 986, 76, 61)
		_box(rect, COLORS[i].darkened(0.65), 10, COLORS[i] if session.skill_color == i else Color("343b4e"))
		_center(rect.position + Vector2(38,39), ["불꽃", "새잎", "번개", "물결"][i], 21, COLORS[i])
	_center(Vector2(360, 1072), "영역 밖으로 이동하면 취소 · 핵은 1개로 발동", 18, Color("8992a8"))

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
		if falling:
			var t := clampf(fall_clock / 0.44, 0, 1)
			p.pos = p.from.lerp(p.pos, 1.0 - pow(1.0 - t, 2.0))
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

func _clear_onset(index: int) -> float:
	return float(index) * maxf(0.011, 0.032 - active_plan.get("removed", []).size() * 0.0005)

func _process(delta: float) -> void:
	time += delta
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
			fall_clock += delta
			if fall_clock >= 0.44:
				falling = false
				session.phase = "ready"
				visual = session.panels.duplicate(true)
				landing = 0
				sound.tone(0, false, true)
				status = "다음 연결을 찾아보세요"
				var metric := {"event":"commit_to_ready", "wall_ms":(Time.get_ticks_usec()-committed_us)/1000.0,"frames":Engine.get_process_frames()-committed_frame,"specials":active_plan.activated.size(),"removed":active_plan.removed.size(),"movie":capture_mode}
				if record_timings:
					timings.append(metric)
					print("TIMING ", JSON.stringify(metric))
				active_plan = {}
	if demo: _demo(delta)
	queue_redraw()
	if board_surface: board_surface.queue_redraw()

func _burst(id: int, index: int) -> void:
	for p in visual:
		if p.id != id: continue
		sound.tone(index)
		for i in range(7):
			var angle := TAU * i / 7.0
			particles.append({"pos":p.pos,"vel":Vector2.from_angle(angle)*rng.randf_range(65,180),"size":rng.randf_range(2,6),"color":COLORS[p.color],"age":0.0,"life":0.25})
		if p.kind != "heart": target_hit = 1
		break

func _start_fall() -> void:
	var packed := Motion.pack(session.panels, BOARD, 48, session.next_id, rng)
	session.panels = packed.panels
	session.next_id = packed.next_id
	visual = session.panels.duplicate(true)
	falling = true
	fall_clock = 0
	sound.tone(mini(active_plan.removed.size(), 14), true)
	status = "물감이 내려오는 중…"

func _after_draw() -> void:
	if feedback_pending:
		var metric := {"event":"press_to_draw","wall_ms":(Time.get_ticks_usec()-pressed_us)/1000.0,"movie":capture_mode}
		timings.append(metric)
		print("TIMING ", JSON.stringify(metric))
		feedback_pending = false

func press(pos: Vector2, pointer: int) -> void:
	if session.owner != -99 or session.phase != "ready": return
	if RESET.has_point(pos):
		reset_board()
		return
	if MUTE.has_point(pos):
		sound.muted = not sound.muted
		return
	if session.phase != "ready": return
	if SKILL.has_point(pos):
		if session.charge >= 3:
			session.skill_mode = not session.skill_mode
			status = "색을 고른 뒤 일반 패널을 누르세요" if session.skill_mode else "누르고 확인 · 놓으면 터져요"
		return
	for i in range(4):
		if Rect2(190+i*88,986,76,61).has_point(pos):
			session.skill_color = i
			return
	pressed_us = Time.get_ticks_usec()
	if session.begin(pos, pointer):
		landing = 1
		feedback_pending = true
		queue_redraw()

func release(pos: Vector2, pointer: int) -> void:
	var result: Dictionary = session.release(pos, pointer)
	if result.is_empty(): return
	if result.mode == "skill":
		hero_active = 1
		visual = session.panels.duplicate(true)
		sound.tone(6, true)
		last_summary = "%d개 변환 완료 · 다음 소거로 연결하세요" % result.targets.size()
		status = "변환 완료 · 소거 횟수는 그대로"
		return
	active_plan = result
	action_clock = 0
	played = 0
	falling = false
	clear_duration = _clear_onset(result.sequence.size()) + 0.12
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
			if event.canceled: session.cancel()
			else: release(event.position, event.index)
			primary_touch = -99
	elif event is InputEventScreenDrag:
		session.move(event.position, event.index)
	elif event is InputEventMouseButton and not event.device == InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press(event.position, -1)
			else: release(event.position, -1)
	elif event is InputEventMouseMotion:
		session.move(event.position, -1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		session.cancel()
		session.skill_mode = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		if session != null: session.cancel()
		primary_touch = -99

func _demo(delta: float) -> void:
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
				demo_point = p.pos
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
		var plan: Dictionary = Rules.plan(session.panels, p.id, session.hp, session.max_hp)
		if plan.valid and plan.removed.size() >= minimum:
			best = p
			break
	if best.is_empty():
		for p in session.panels:
			if Rules.plan(session.panels,p.id,session.hp,session.max_hp).valid:
				best = p
				break
	if not best.is_empty():
		demo_point = best.pos
		press(demo_point, -1)

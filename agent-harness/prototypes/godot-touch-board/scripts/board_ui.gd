extends RefCounted
## Presentation only. BOARD_SCREEN translates the unchanged logical board;
## controller must translate pointer positions back before calling session.
const Art = preload("res://scripts/board_art.gd")
const COLORS = [Color("ff705d"), Color("6edb6b"), Color("ffcf5b"), Color("61b7ff"), Color("ff86b5")]
const BOARD_SCREEN = Rect2(30, 250, 660, 530)
const RESET = Rect2(608, 12, 88, 88)
const SKILL = Rect2(180, 846, 412, 100)
const MUTE = Rect2(608, 850, 88, 88)
const HERO_RECT = Rect2(30, 842, 130, 112)
const TARGET_RECT = Rect2(250, 42, 220, 166)
const MUTED = Color("929bb0")
const INK = Color("0c1017")
const MINT = Color("a2f4d6")

static func color_rect(index: int) -> Rect2:
	return Rect2(150 + 136 * index, 966, 120, 88)

static func _line(view, center: Vector2, text: String, size: int, width: float, color: Color) -> void:
	# Status/results can contain longer numbers, including overflow healing.
	# Preserve all information; critical copy never shrinks below 22 logical px.
	var actual_size := size
	while actual_size > 22 and view.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_size).x > width:
		actual_size -= 1
	view._center(center, text, actual_size, color)

static func draw(view) -> void:
	var session = view.session
	var preview: Dictionary = session.selection
	var skill_ready: bool = session.charge >= session.charge_required
	view.draw_rect(Rect2(0, 0, 720, 1080), Color("0e121b"))
	# Quiet warm top band, thin accent and restrained typography.
	view.draw_rect(Rect2(0, 0, 720, 208), Color("131925"))
	view.draw_rect(Rect2(28, 28, 3, 38), MINT)
	view._text(Vector2(44, 48), "C H R O M A", 25)
	view._text(Vector2(45, 74), "물감 연쇄 실험실", 20, MUTED)
	view._box(RESET, Color("222c3b"), 18, Color("354358"))
	view._center(RESET.get_center() + Vector2(0,-5), "↻", 29, Color("e2e8f1"))
	view._center(RESET.get_center() + Vector2(0,23), "리셋", 22, MUTED)

	# Target has a reserved central portrait band, with counters to either side.
	view._text(Vector2(31, 113), "피해", 22, MUTED)
	view._text(Vector2(29, 158), str(session.damage_total).pad_zeros(3), 41, COLORS[0])
	view._text(Vector2(31, 183), "반격 없는 표적", 20, MUTED)
	Art.draw_target(view, TARGET_RECT.get_center(), view.time, view.target_hit)
	view._text(Vector2(528, 123), "생명", 22, MUTED)
	view._text(Vector2(527, 158), "%d / %d" % [session.hp, session.max_hp], 27, COLORS[4])
	view._box(Rect2(529, 174, 160, 6), Color("342a39"), 3)
	view._box(Rect2(529, 174, 160 * float(session.hp) / session.max_hp, 6), COLORS[4], 3)

	view._text(Vector2(30, 207), "TURN %02d" % (session.actions / 3 + 1), 22, Color("c3ccdc"))
	for i in range(3):
		view.draw_circle(Vector2(143+i*21,201), 5, COLORS[2] if i < session.actions % 3 else Color("3d4657"))
	view._text(Vector2(536, 207), "충전 %d / %d" % [session.charge, session.charge_required], 22, MINT if skill_ready else MUTED)

	# Full 660x530 body field is retained; no high/low rows are cropped.
	view._box(Rect2(24, 214, 672, 578), Color("05080d"), 22, Color("3a465c"))
	view._box(Rect2(32, 221, 656, 26), Color("161e2a"), 10)
	var headline: String = view.status
	var result: String = view.last_summary
	var result_color := Color("bfcbdc")
	if not preview.is_empty():
		if not preview.get("valid", false):
			headline = "같은 색 2개부터 골라주세요"
		elif preview.mode == "skill":
			headline = "%d개 변환 → 연결 %d개" % [preview.targets.size(), preview.connected.size()]
			result = "놓으면 변환 · 소거 횟수는 그대로"
			result_color = MINT
		else:
			var outcome := "놓으면 소거"
			if not preview.spawn.is_empty(): outcome = "강화핵 생성" if preview.spawn.kind == "strong" else "물감핵 생성"
			if preview.get("ash_reserve", false): outcome += " · 충전 예약"
			headline = "직접 %d · 연쇄 %d / %s" % [preview.direct.size(), preview.removed.size()-preview.direct.size(), outcome]
			result = "피해 %d   회복 %d → %d  (초과 %d)" % [preview.damage,preview.heal_raw,preview.heal_effective,preview.heal_overflow]
			result_color = Color("fff0c7")
	_line(view, Vector2(360,241), headline, 22, 628, Color("eef2f9"))
	view.draw_line(Vector2(32,813),Vector2(688,813),Color("273245"),1)
	view._box(Rect2(72,799,576,29),Color("0e121b"),0)
	_line(view, Vector2(360,820), result, 22, 626, result_color)

	# A single character and one actionable ability; palette is contextual.
	Art.draw_hero(view, HERO_RECT.get_center(), view.time, view.hero_active > 0.0)
	view._center(Vector2(HERO_RECT.get_center().x,971), "리오 · 변환사", 20, MUTED)
	var skill_bg := Color("203c3e") if skill_ready else Color("222938")
	view._box(SKILL, skill_bg, 20, MINT if session.skill_mode else Color("3b555e"))
	view._text(SKILL.position+Vector2(22,35), "색을 잇는 붓", 26, Color("ecfff8"))
	view._text(SKILL.position+Vector2(22,65), "색 선택 중 · 다시 눌러 취소" if session.skill_mode else "최대 %d개 변환 · 소거 무료" % (5 if "pigment" in session.relics else 4), 22, Color("adccc9"))
	var charge_label := "색 선택" if session.skill_mode else ("준비" if skill_ready else "%d / %d" % [session.charge, session.charge_required])
	view._text(SKILL.position+Vector2(22,88), "색을 고르고 패널을 누르세요" if session.skill_mode else ("눌러서 사용" if skill_ready else "수동 소거로 충전"), 22, MINT if skill_ready else MUTED)
	view._box(Rect2(SKILL.end.x-96,SKILL.position.y+12,80,30),Color("12282c") if skill_ready else Color("171e2a"),10)
	view._center(Vector2(SKILL.end.x-56,SKILL.position.y+35),charge_label,20,MINT if skill_ready else MUTED)
	view._box(MUTE, Color("222c3b"), 18, Color("354358"))
	view._center(MUTE.get_center()+Vector2(0,-6), "소리", 22, Color("d8e1ef"))
	view._center(MUTE.get_center()+Vector2(0,22), "OFF" if view.sound.muted else "ON", 22, MUTED if view.sound.muted else MINT)
	if session.skill_mode:
		for i in range(4):
			var rect := color_rect(i)
			var selected: bool = session.skill_color == i
			view._box(rect, COLORS[i].darkened(0.74 if not selected else 0.59),18,COLORS[i] if selected else Color("364152"))
			# Atlas glyphs make color choice identifiable without reading labels.
			Art.draw_panel(view,{"pos":rect.position+Vector2(34,34),"radius":19.0,"color":i,"kind":"normal"},view.time)
			view._text(rect.position+Vector2(61,42),"✓" if selected else "",22,Color.WHITE)
			view._center(rect.position+Vector2(60,73),["불꽃","새잎","번개","물결"][i],24,COLORS[i])
	else:
		view._text(Vector2(181,988), "성장 실험 · 3/6회 유물 · 9회 요약", 20, Color("bac6d8"))
		var owned_names: Array[String] = []
		for id in session.relics: owned_names.append(RELIC_COPY[id].name)
		view._text(Vector2(181,1020), "누르고 확인, 놓으면 소거" if owned_names.is_empty() else " + ".join(owned_names), 22, Color("e6edf7"))
		view._text(Vector2(181,1048), "충전 예약 · 다음 스킬 사용 후 2회" if session.ash_reserved else "보드 밖으로 움직이면 취소", 20, MUTED)

const SUMMARY_CONTINUE = Rect2(84, 670, 552, 88)
const RELIC_COPY = {
	"pigment": {"name":"번짐 안료", "change":"스킬 변환 4개 → 5개", "lines":["선택한 패널을 포함해", "일반 패널을 최대 5개 변환해요."]},
	"lens": {"name":"응축 렌즈", "change":"물감핵 생성 6/12개 → 5/11개", "lines":["직접 연결한 일반 공격 패널로", "물감핵을 더 빨리 만들어요."]},
	"ash": {"name":"잿빛 보석", "change":"일반 공격 6개 직접 연결 → 예약", "lines":["다음 스킬 사용 후 충전이 3회 → 2회.", "한 번만 적용되며 예약은 쌓이지 않아요."]}
}

static func reward_rect(index: int, count: int) -> Rect2:
	# A full card is one target. At360-wide this is296x63px.
	var top := 316.0 if count >= 3 else 384.0
	return Rect2(64, top + index * 138, 592, 126)

static func _modal_box(canvas: CanvasItem, rect: Rect2, color: Color, border: Color, radius: int = 18) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	canvas.draw_style_box(style,rect)

static func _modal_text(view, canvas: CanvasItem, at: Vector2, text: String, size: int, color: Color, centered: bool = false) -> void:
	var origin := at
	if centered:
		origin.x -= view.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2.0
	canvas.draw_string(view.font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func draw_modal(view, canvas: CanvasItem) -> void:
	var session = view.session
	if session.phase != "reward" and session.phase != "summary":
		return
	# Overlay child renders after the board. Reset remains visible and usable.
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.025,0.035,0.055,0.92))
	_modal_box(canvas,Rect2(32,216,656,576),Color("151e2c"),Color("526579"),24)
	if session.phase == "reward":
		_modal_text(view,canvas,Vector2(64,257),"유물을 골라주세요",30,Color("f1fff8"))
		_modal_text(view,canvas,Vector2(64,287),"%d / 2 선택 · 새로운 유물 하나를 골라요" % session.reward_round,22,MUTED)
		var count: int = session.reward_options.size()
		for i in range(count):
			var id: String = session.reward_options[i]
			var copy: Dictionary = RELIC_COPY[id]
			var rect := reward_rect(i,count)
			var tint: Color = [MINT,COLORS[2],COLORS[3]][["pigment","lens","ash"].find(id)]
			_modal_box(canvas,rect,Color("213041"),tint.darkened(0.35))
			canvas.draw_rect(Rect2(rect.position+Vector2(0,20),Vector2(3,86)),tint)
			_modal_text(view,canvas,rect.position+Vector2(22,31),copy.name,27,tint)
			_modal_text(view,canvas,rect.position+Vector2(22,60),copy.change,22,Color("f2f5fa"))
			for row in range(copy.lines.size()):
				_modal_text(view,canvas,rect.position+Vector2(22,85+25*row),copy.lines[row],22,Color("b9c7db"))
		_modal_text(view,canvas,Vector2(360,768),"원하는 카드 위에서 눌렀다 놓으세요",22,MUTED,true)
	else:
		_modal_text(view,canvas,Vector2(64,259),"9회 성장 실험 완료",30,Color("f1fff8"))
		_modal_text(view,canvas,Vector2(64,293),"유물을 고른 뒤 연결이 어떻게 달라졌나요?",22,MUTED)
		var labels := ["구간", "소거 행동", "제거 패널", "생성 핵"]
		var columns := [115.0,278.0,441.0,589.0]
		for i in range(labels.size()):
			_modal_text(view,canvas,Vector2(columns[i],352),labels[i],22,MUTED,true)
		for i in range(3):
			var stat: Dictionary = session.stats[i]
			var y := 398.0+i*64
			_modal_box(canvas,Rect2(57,y-31,606,53),Color("202d3e"),Color("2d4055"),10)
			var values := ["%d–%d회" % [i*3+1,i*3+3],str(stat.actions),str(stat.removed),str(stat.cores)]
			for col in range(values.size()):
				_modal_text(view,canvas,Vector2(columns[col],y+4),values[col],25,Color("eff4fc") if col else MINT,true)
		var names: Array[String] = []
		for id in session.relics:
			names.append(RELIC_COPY[id].name)
		_modal_text(view,canvas,Vector2(360,583),"선택 유물 · " + " + ".join(names),22,Color("c5d7e8"),true)
		_modal_text(view,canvas,Vector2(360,623),"이후에는 추가 보상 없이 자유롭게 플레이해요.",22,MUTED,true)
		_modal_box(canvas,SUMMARY_CONTINUE,Color("28564e"),MINT,18)
		_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"계속 플레이",28,Color("e9fff7"),true)

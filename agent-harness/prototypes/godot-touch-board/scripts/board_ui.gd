extends RefCounted
## Presentation only. BOARD_SCREEN translates the unchanged logical board;
## controller must translate pointer positions back before calling session.
const RelicArt = preload("res://scripts/board_relic_art.gd")
const MaterialArt = preload("res://scripts/board_skin.gd")
const Art = preload("res://scripts/board_art.gd")
const COLORS = [Color("ff705d"), Color("6edb6b"), Color("ffcf5b"), Color("61b7ff"), Color("ff86b5")]
const BOARD_SCREEN = Rect2(30, 268, 660, 530)
const WEAKNESS_BASELINE := Vector2(529,127)
const ELEMENT_NAMES := ["불꽃","새잎","번개","물결"]
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
	var context: Dictionary = {}
	if not view.sandbox:
		context = preview.get("combat_context",session.combat.damage_context())
	view.draw_rect(Rect2(0, 0, 720, 1080), Color("071319"))
	# Quiet warm top band, thin accent and restrained typography.
	view.draw_rect(Rect2(0, 0, 720, 208), Color("10232b"))
	view.draw_rect(Rect2(28, 28, 3, 38), MINT)
	_modal_text(view,view,Vector2(44,48),"CHROMA",30,MaterialArt.GOLD,false,true)
	view._text(Vector2(45, 74), "물감 연쇄 실험실" if view.sandbox else "짧은 연금술 탐험 · 시제품", 20, MUTED)
	MaterialArt.button(view,RESET,Color("617e7c"))
	MaterialArt.glyph(view,RESET.get_center()+Vector2(0,-13),"reset",Color("c1d2cd"),29)
	view._center(RESET.get_center() + Vector2(0,23), "리셋", 22, MUTED)

	if not view.sandbox:
		view._text(Vector2(529,74), "%d G" % session.gold,22,COLORS[2])
		var weak: int = context.get("weakness_color",session.combat.weak_color)
		Art.draw_panel(view,{"pos":WEAKNESS_BASELINE+Vector2(-20,-7),"radius":14.0,"color":weak,"kind":"normal"},view.time)
		view._text(WEAKNESS_BASELINE,"약점 · "+weakness_name(weak),22,COLORS[weak])
	# Target has a reserved central portrait band, with counters to either side.
	if view.sandbox:
		view._text(Vector2(31, 113), "피해", 22, MUTED)
		_modal_text(view,view,Vector2(29,158),str(session.damage_total).pad_zeros(3),41,COLORS[0])
		view._text(Vector2(31, 183), "반격 없는 표적", 20, MUTED)
	else:
		view._text(Vector2(31,113), "%s %d/3" % ["강타 수호자" if session.combat.encounter == 2 else ("정예 표적" if session.combat.encounter == 1 and session.route == "elite" else session.combat.enemy_name),session.combat.encounter+1],22,MUTED)
		_modal_text(view,view,Vector2(29,158),"%d / %d" % [session.combat.enemy_hp,session.combat.enemy_max_hp],41,COLORS[0])
		view._text(Vector2(31,183), "예고 %d 피해" % int(context.get("incoming_damage",session.combat.incoming_damage)),22,COLORS[2])
	Art.draw_target(view, TARGET_RECT.get_center(), view.time, view.target_hit)
	if view.sandbox:
		view._text(Vector2(528,123),"생명",22,MUTED)
		view._text(Vector2(527,158),"%d / %d" % [session.hp,session.max_hp],27,COLORS[4])
	else:
		view._text(Vector2(527,158),"생명 %d / %d" % [session.hp,session.max_hp],25,COLORS[4])
	view._box(Rect2(529, 174, 160, 6), Color("342a39"), 3)
	view._box(Rect2(529, 174, 160 * float(session.hp) / session.max_hp, 6), COLORS[4], 3)

	view._text(Vector2(30, 207), "TURN %02d" % (session.actions / 3 + 1) if view.sandbox else "행동 %d/3" % session.combat.actions_in_turn, 22, Color("c3ccdc"))
	for i in range(3):
		view.draw_circle(Vector2(143+i*21,201), 5, COLORS[2] if i < (session.actions % 3 if view.sandbox else session.combat.actions_in_turn) else Color("3d4657"))
	view._text(Vector2(536, 207), "충전 %d / %d" % [session.charge, session.charge_required], 22, MINT if skill_ready else MUTED)

	# Full 660x530 body field is retained; no high/low rows are cropped.
	MaterialArt.frame(view,Rect2(24,214,672,596),MINT,true)
	view.draw_rect(Rect2(35,220,650,44),Color("10272e"))
	var headline: String = view.status
	var secondary := ""
	if not view.sandbox:
		if session.phase == "ready":
			var intent_copy: Array = intent_lines(context)
			headline = intent_copy[0]
			secondary = intent_copy[1]
		elif session.phase == "enemy_attack": headline = "적의 반격 · %d 피해" % session.combat.last_attack_damage
	var result: String = view.last_summary
	if not view.sandbox and session.phase == "ready": result = "약점 패널 2개당 피해 +1"
	var result_color := Color("bfcbdc")
	if not preview.is_empty():
		if not preview.get("valid", false):
			headline = "같은 색 2개부터 골라주세요"
			secondary = "놓아도 행동을 쓰지 않아요"
		elif preview.mode == "skill":
			headline = "%d개 변환 → 연결 %d개" % [preview.targets.size(), preview.connected.size()]
			secondary = "변환만 적용 · 피해와 소거 행동 없음"
			result = "놓으면 변환 · 소거 횟수는 그대로"
			result_color = MINT
		else:
			var outcome := "놓으면 소거"
			if not preview.spawn.is_empty(): outcome = "강화핵 생성" if preview.spawn.kind == "strong" else "물감핵 생성"
			if preview.get("ash_reserve", false): outcome += " · 충전 예약"
			headline = "직접 %d · 연쇄 %d / %s" % [preview.direct.size(), preview.removed.size()-preview.direct.size(), outcome]
			secondary = preview_effect_line(preview)
			result = "공격 %d개 · 약점 %d개 · 회복 %d → %d (초과 %d)" % [preview.get("normal_count",0),preview.get("weak_count",0),preview.heal_raw,preview.heal_effective,preview.heal_overflow] if not view.sandbox else "피해 %d   회복 %d → %d  (초과 %d)" % [preview.damage,preview.heal_raw,preview.heal_effective,preview.heal_overflow]
			result_color = Color("fff0c7")
	_line(view, Vector2(360,236), headline, 22, 628, Color("eef2f9"))
	_line(view, Vector2(360,260), secondary, 22, 628, MINT if preview.get("mitigates_intent",false) else Color("c5d4e5"))
	view.draw_line(Vector2(32,813),Vector2(688,813),Color("273245"),1)
	view._box(Rect2(72,799,576,29),Color("071319"),0)
	_line(view, Vector2(360,820), result, 22, 626, result_color)

	# A single character and one actionable ability; palette is contextual.
	MaterialArt.frame(view,HERO_RECT.grow(3),MaterialArt.GOLD,true)
	Art.draw_hero(view, HERO_RECT.get_center(), view.time, view.hero_active > 0.0)
	if not view.sandbox and session.phase == "enemy_attack":
		view.draw_rect(HERO_RECT,Color(1.0,0.2,0.2,0.22 * sin(PI * minf(1.0,view.attack_clock/view.ATTACK_SECONDS))))
	view._center(Vector2(HERO_RECT.get_center().x,971), "리오", 22, MUTED)
	var usable: bool = session.phase == "ready" and skill_ready
	var skill_state := "selected" if session.skill_mode else ("ready" if usable else "disabled")
	MaterialArt.button(view,SKILL,MINT,skill_state)
	if usable and view.get("ready_age") != null:
		MaterialArt.ready_sheen(view,SKILL,float(view.ready_age))
	MaterialArt.glyph(view,SKILL.position+Vector2(29,28),"brush",MaterialArt.GOLD,25)
	_modal_text(view,view,SKILL.position+Vector2(52,37),"색을 잇는 붓",28,Color("ecfff8"),false,true)
	view._text(SKILL.position+Vector2(20,66),"색 선택 중 · 다시 누르면 취소" if session.skill_mode else "최대 %d개 변환 · 소거 무료" % (5 if "pigment" in session.relics else 4),22,Color("c0d8d0"))
	var charge_label := "%d / %d" % [session.charge,session.charge_required]
	_modal_text(view,view,SKILL.position+Vector2(355,35),charge_label,24,MINT if skill_ready else Color("c2cbd0"),true)
	view._text(SKILL.position+Vector2(20,91),"색을 골라 패널에 적용" if session.skill_mode else ("준비 · 눌러서 사용" if usable else "소거로 충전"),22,MINT if usable else MUTED)
	var count: int = maxi(1,session.charge_required)
	var segment_width := 76.0/count
	for i in range(count):
		var segment := Rect2(SKILL.end.x-96+i*segment_width,SKILL.position.y+79,segment_width-4,8)
		view.draw_rect(segment, MINT if i < session.charge else Color("425457"))
	MaterialArt.button(view,MUTE,Color("617e7c"))
	MaterialArt.glyph(view,MUTE.get_center()+Vector2(0,-14),"muted" if view.sound.muted else "sound",Color("a7beba"),28)
	view._center(MUTE.get_center()+Vector2(0,25),"OFF" if view.sound.muted else "ON",22,MUTED if view.sound.muted else MINT)
	if session.skill_mode:
		for i in range(4):
			var rect := color_rect(i)
			var selected: bool = session.skill_color == i
			MaterialArt.button(view,rect,COLORS[i],"selected" if selected else "normal")
			# Atlas glyphs make color choice identifiable without reading labels.
			Art.draw_panel(view,{"pos":rect.position+Vector2(34,34),"radius":19.0,"color":i,"kind":"normal"},view.time)
			view._text(rect.position+Vector2(61,42),"✓" if selected else "",22,Color.WHITE)
			view._center(rect.position+Vector2(60,73),ELEMENT_NAMES[i],24,COLORS[i])
	else:
		view._text(Vector2(181,988), "성장 실험 · 3/6회 유물 · 9회 요약" if view.sandbox else "짧은 탐험 · 전투 %d / 3" % (session.combat.encounter+1), 20, Color("bac6d8"))
		if session.relics.is_empty():
			view._text(Vector2(181,1020), "누르고 확인, 놓으면 소거", 22, Color("e6edf7"))
			view._text(Vector2(181,1048), "보드 밖으로 움직이면 취소" if view.sandbox else "3회 소거마다 적이 반격해요", 20, MUTED)
		else:
			# Owned strip replaces helper copy; palette owns the same area only
			# while skill mode is open. Each hit target remains44px at360wide.
			view.draw_rect(Rect2(176,966,520,104),Color("071319"))
			for i in range(session.relics.size()):
				var rect:=owned_rect(i)
				MaterialArt.frame(view,rect,MaterialArt.GOLD)
				RelicArt.draw_icon(view,session.relics[i],rect.grow(-5))
			if session.relics.size()<=2:
				view._text(Vector2(399,989), "보유 유물 %d"%session.relics.size(),22,MINT)
				view._text(Vector2(399,1018), "아이콘을 눌러 설명",22,Color("d8e3ef"))
				view._text(Vector2(399,1047), "다음 스킬 후 충전 2회" if session.ash_reserved else ("3/6회 선택 · 9회 요약" if view.sandbox else "전투 %d/3 · 처치 %d" % [session.combat.encounter+1,session.combat.enemies_defeated]),20,MUTED)

			elif session.ash_reserved:
				view._text(Vector2(497,1002),"잿빛 예약",22,MINT)
				view._text(Vector2(497,1034),"다음 충전 2회",22,Color("d8e3ef"))

const SUMMARY_CONTINUE = Rect2(84, 670, 552, 88)
const NEXT_BATTLE = SUMMARY_CONTINUE
const RESTART = SUMMARY_CONTINUE
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
	# All modal layers share the same cut-metal / dark-glass material.
	MaterialArt.frame(canvas,rect,border,rect.size.y>300)

static func _modal_text(view, canvas: CanvasItem, at: Vector2, text: String, size: int, color: Color, centered: bool = false, display: bool = false) -> void:
	var origin := at
	var selected_font: Font = view.font
	if display and view.get("font_display") != null: selected_font = view.font_display
	elif size >= 24 and view.get("font_bold") != null: selected_font = view.font_bold
	if centered:
		origin.x -= selected_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2.0
	canvas.draw_string(selected_font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func draw_modal(view, canvas: CanvasItem) -> void:
	var session = view.session
	if session.phase in ["route","shop"]:
		draw_route_shop_modal(view,canvas)
		return
	if session.phase in ["between","victory","defeat"]:
		draw_run_modal(view,canvas)
		return
	if session.phase != "reward" and session.phase != "summary":
		return
	# Overlay child renders after the board. Reset remains visible and usable.
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.025,0.035,0.055,0.92))
	_modal_box(canvas,Rect2(32,216,656,576),Color("151e2c"),Color("526579"),24)
	if session.phase == "reward":
		_modal_text(view,canvas,Vector2(64,257),"유물을 골라주세요" if view.sandbox else "승리 보상 · 유물을 골라주세요",30,Color("f1fff8"),false,true)
		_modal_text(view,canvas,Vector2(64,287),"%d / 2 선택 · 새로운 유물 하나를 골라요" % session.reward_round if view.sandbox else "승리 골드 지급 · %d G 보유 · 유물 %d / 2" % [session.gold,session.reward_round],22,MUTED)
		var count: int = session.reward_options.size()
		for i in range(count):
			var id: String = session.reward_options[i]
			var copy: Dictionary = RELIC_COPY[id]
			var rect := reward_rect(i,count)
			var tint: Color = [MINT,COLORS[2],COLORS[3]][["pigment","lens","ash"].find(id)]
			MaterialArt.button(canvas,rect,tint,"pressed" if view.modal_phase == "reward" and view.modal_index == i else "normal")
			canvas.draw_rect(Rect2(rect.position+Vector2(0,20),Vector2(3,86)),tint)
			RelicArt.draw_icon(canvas,id,Rect2(rect.position+Vector2(10,15),Vector2(100,100)))
			_modal_text(view,canvas,rect.position+Vector2(119,31),copy.name,27,tint)
			_modal_text(view,canvas,rect.position+Vector2(119,60),copy.change,22,Color("f2f5fa"))
			for row in range(copy.lines.size()):
				_modal_text(view,canvas,rect.position+Vector2(119,85+25*row),copy.lines[row],22,Color("b9c7db"))
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
		MaterialArt.button(canvas,SUMMARY_CONTINUE,MINT,"pressed" if view.modal_index >= 0 and view.modal_phase == session.phase and (session.phase != "shop" or view.modal_index == 2) else "ready")
		_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"계속 플레이",28,Color("e9fff7"),true)


const DETAIL_PANEL = Rect2(48,310,624,430)
const DETAIL_CLOSE = Rect2(84,650,552,88)

static func owned_rect(index:int)->Rect2:
	return Rect2(180+104*index,974,88,88)

static func draw_details(view,canvas:CanvasItem)->void:
	if view.detail_relic=="":return
	var id:String=view.detail_relic
	if not RELIC_COPY.has(id):return
	var copy:Dictionary=RELIC_COPY[id]
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.025,0.035,0.055,0.92))
	_modal_box(canvas,DETAIL_PANEL,Color("172333"),Color("819691"),24)
	RelicArt.draw_icon(canvas,id,Rect2(76,337,116,116))
	_modal_text(view,canvas,Vector2(210,380),copy.name,32,MINT)
	_modal_text(view,canvas,Vector2(210,419),"보유 중 · 성장 실험 유물" if view.sandbox else "보유 중 · 이번 탐험에 적용",22,MUTED)
	_modal_text(view,canvas,Vector2(84,493),copy.change,25,Color("fff0c7"))
	for row in range(copy.lines.size()):
		_modal_text(view,canvas,Vector2(84,540+32*row),copy.lines[row],24,Color("d5dfec"))
	_modal_text(view,canvas,Vector2(360,620),"설명을 닫아도 보드와 충전은 유지돼요",22,MUTED,true)
	MaterialArt.button(canvas,DETAIL_CLOSE,MINT,"ready")
	_modal_text(view,canvas,DETAIL_CLOSE.get_center()+Vector2(0,9),"닫기",28,Color("e9fff7"),true)


static func draw_run_modal(view,canvas:CanvasItem)->void:
	var session = view.session
	var combat = session.combat
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.025,0.035,0.055,0.94))
	_modal_box(canvas,Rect2(32,216,656,576),Color("151e2c"),Color("526579"),24)
	var heading: String = "다음 전투 준비" if session.phase == "between" else ("탐험 성공!" if session.phase == "victory" else "탐험 종료")
	_modal_text(view,canvas,Vector2(360,278),heading,36,MINT,true,true)
	var lines: Array[String] = []
	if session.phase == "between":
		lines = ["전투 %d 승리 · 유물 획득 완료" % (combat.encounter+1), "생명 %d / 30 · 충전 %d / %d" % [session.hp,session.charge,session.charge_required], "생명·충전·유물·예약을 이어갑니다", "새 보드에서 전투 %d / 3 시작" % (combat.encounter+2)]
	elif session.phase == "victory":
		lines = ["적 3명 처치 · 생명 %d / 30" % session.hp, "선택 경로 · " + route_name(session.route), "사용 %d G · 남은 %d G" % [session.gold_spent,session.gold], "유효 소거 %d회 · 보유 유물 %d개" % [session.actions,session.relics.size()]]
	else:
		lines = ["도달 전투 %d / 3 · 적 %d명 처치" % [combat.encounter+1,combat.enemies_defeated], "선택 경로 · " + route_name(session.route), "사용 %d G · 남은 %d G" % [session.gold_spent,session.gold], "유효 소거 %d회 · 보유 유물 %d개" % [session.actions,session.relics.size()]]
	for i in range(lines.size()):
		_modal_text(view,canvas,Vector2(360,352+i*56),lines[i],26,Color("eff4fc") if i<2 else MUTED,true)
	for i in range(session.relics.size()):
		RelicArt.draw_icon(canvas,session.relics[i],Rect2(360-(session.relics.size()*88-16)/2.0+i*88,554,72,72))
	MaterialArt.button(canvas,SUMMARY_CONTINUE,MINT,"pressed" if view.modal_index >= 0 and view.modal_phase == session.phase and (session.phase != "shop" or view.modal_index == 2) else "ready")
	_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"다음 전투" if session.phase == "between" else "새 탐험 시작",28,Color("e9fff7"),true)


static func route_name(id:String)->String:
	return "안전한 길" if id == "safe" else ("정예의 길" if id == "elite" else "선택 전")

static func route_rect(index:int)->Rect2:
	return Rect2(64,350+156*index,592,140)

static func shop_rect(index:int)->Rect2:
	return route_rect(index)

static func modal_rect(phase:String,index:int,reward_count:int=0)->Rect2:
	if phase == "reward": return reward_rect(index,reward_count)
	if phase == "route": return route_rect(index)
	if phase == "shop" and index < 2: return shop_rect(index)
	return SUMMARY_CONTINUE

static func draw_route_shop_modal(view,canvas:CanvasItem)->void:
	var session = view.session
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.025,0.035,0.055,0.94))
	_modal_box(canvas,Rect2(32,216,656,576),Color("151e2c"),Color("526579"),24)
	_modal_text(view,canvas,Vector2(64,257),"두 번째 전투 · 경로 선택" if session.phase == "route" else "작은 상점 · 선택 구매",30,MINT,false,true)
	_modal_text(view,canvas,Vector2(64,292),"생명 %d / 30 · 보유 %d G" % [session.hp,session.gold],26,Color("fff0c7"))
	if session.phase == "route":
		_modal_text(view,canvas,Vector2(64,324),"매 3회 소거 반격 · 경감/일반 공격 교대",22,MUTED)
		for i in range(2):
			var id: String = "safe" if i == 0 else "elite"
			var info: Dictionary = session.combat.ROUTES[id]
			var rect := route_rect(i)
			var tint: Color = MINT if i == 0 else COLORS[0]
			var pressed: bool = view.modal_phase == "route" and view.modal_index == i
			MaterialArt.button(canvas,rect,tint,"pressed" if pressed else "normal")
			_modal_text(view,canvas,rect.position+Vector2(24,33),info.name,29,tint)
			_modal_text(view,canvas,rect.position+Vector2(24,64),"적 HP %d · 승리 %d G" % [info.hp,info.gold],26,Color("f2f5fa"))
			_modal_text(view,canvas,rect.position+Vector2(24,95),info.pattern,25,Color("d3e0ed"))
			_modal_text(view,canvas,rect.position+Vector2(24,124),"4개 연결 기회가 없으면 공격 %d" % (5 if i == 0 else 6),22,MUTED)
		_modal_text(view,canvas,Vector2(360,705),"카드를 눌렀다 놓으면 전투로 출발해요",23,Color("d3e0ed"),true)
		_modal_text(view,canvas,Vector2(360,754),"확정 후에는 경로를 바꿀 수 없어요",22,MUTED,true)
		return
	_modal_text(view,canvas,Vector2(64,324),view.shop_notice if view.shop_notice != "" else "구매는 선택 · 스킬 충전과 턴은 그대로",22,MUTED)
	for i in range(2):
		var rect := shop_rect(i)
		var sold: bool = session.shop_heal_sold if i == 0 else session.shop_relic_sold
		var price: int = session.SHOP_HEAL_PRICE if i == 0 else session.SHOP_RELIC_PRICE
		var gain: int = session.shop_heal_gain()
		var relic: String = session.shop_remaining_relic()
		var enabled: bool = not sold and session.gold >= price and (gain > 0 if i == 0 else relic != "")
		var tint: Color = MINT if enabled else MUTED
		var pressed: bool = view.modal_phase == "shop" and view.modal_index == i and enabled
		MaterialArt.button(canvas,rect,tint,"disabled" if not enabled else ("pressed" if pressed else "normal"))
		if i == 0:
			Art.draw_panel(canvas,{"pos":rect.position+Vector2(58,69),"radius":33.0,"color":4,"kind":"heart"},view.time)
		else:
			if relic == "" and sold and not session.relics.is_empty(): relic = session.relics.back()
			if relic != "": RelicArt.draw_icon(canvas,relic,Rect2(rect.position+Vector2(10,20),Vector2(100,100)))
		var name: String = "생명 회복" if i == 0 else (RELIC_COPY[relic].name if relic != "" else "미보유 유물 없음")
		_modal_text(view,canvas,rect.position+Vector2(119,32),name,27,tint)
		var change: String = "4 G · 생명 %d → %d (+%d)" % [session.hp,session.hp+gain,gain] if i == 0 else "8 G · 남은 유물 1개 획득"
		_modal_text(view,canvas,rect.position+Vector2(119,63),change,24,Color("f2f5fa") if enabled else MUTED)
		var effect: String = "최대 8 회복 · 한 번만 구매" if i == 0 else (RELIC_COPY[relic].change if relic != "" else "새로운 유물은 추가하지 않아요")
		_modal_text(view,canvas,rect.position+Vector2(119,94),effect,22,MUTED)
		var state: String = "구매 완료" if sold else ("생명 가득 · 구매 불가" if i == 0 and gain == 0 else ("골드 부족" if session.gold < price else "눌렀다 놓으면 구매"))
		_modal_text(view,canvas,rect.position+Vector2(119,124),state,22,tint)
	MaterialArt.button(canvas,SUMMARY_CONTINUE,MINT,"pressed" if view.modal_index >= 0 and view.modal_phase == session.phase and (session.phase != "shop" or view.modal_index == 2) else "ready")
	_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"최종 전투로",28,Color("e9fff7"),true)


static func weakness_name(color:int)->String:
	return ELEMENT_NAMES[color] if color >= 0 and color < ELEMENT_NAMES.size() else "없음"

static func damage_line(plan:Dictionary)->String:
	return "피해 %d = 기본 %d + 약점 %d" % [plan.get("damage",0),plan.get("base_damage",plan.get("damage",0)),plan.get("weak_bonus",0)]

static func intent_lines(context:Dictionary)->Array[String]:
	var incoming: int = context.get("incoming_damage",0)
	var intent: String = context.get("intent","plain")
	if intent == "slam":
		if context.get("mitigation_success",false): return ["강타 약화 · 피해%d" % incoming, "이번 턴 동안 약화를 유지해요"]
		return ["강타 10 → 4: 한 번에 약점 %d개" % int(context.get("slam_weak_required",2)), "또는 공격 패널 %d개 소거" % int(context.get("slam_normal_required",8))]
	if intent == "direct4":
		if context.get("mitigation_success",false): return ["조건 성공 · 다음 공격 %d" % incoming, ""]
		return ["4개 이상 연결을 한 번 지우면 공격 %d → %d" % [incoming,incoming-4], ""]
	return ["3회 소거 후 공격 %d" % incoming, ""]

static func preview_effect_line(plan:Dictionary)->String:
	var text := damage_line(plan)
	var context: Dictionary = plan.get("combat_context",{})
	if context.get("intent","") == "slam":
		text += " · " + ("강타 약화 유지" if context.get("mitigation_success",false) else ("강타 약화" if plan.get("mitigates_intent",false) else "강타 조건 미충족"))
	elif context.get("intent","") == "direct4":
		text += " · " + ("경감 유지" if context.get("mitigation_success",false) else ("공격 경감" if plan.get("mitigates_intent",false) else "경감 조건 미충족"))
	return text

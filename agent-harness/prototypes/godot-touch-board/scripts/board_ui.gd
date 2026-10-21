extends RefCounted
## Presentation only. BOARD_SCREEN translates the unchanged logical board;
## controller must translate pointer positions back before calling session.
const RelicArt = preload("res://scripts/board_relic_art.gd")
const MaterialArt = preload("res://scripts/board_premium_skin.gd")
const SkillState = preload("res://scripts/board_skill_presentation.gd")
const CharacterUI = preload("res://scripts/board_character_ui.gd")
const Characters = preload("res://scripts/board_characters.gd")
const DEPART = CharacterUI.DEPART
const Art = preload("res://scripts/board_art.gd")
const COLORS = [Color("ff705d"), Color("6edb6b"), Color("ffcf5b"), Color("61b7ff"), Color("ff86b5")]
const BOARD_SCREEN = Rect2(30,390,660,530)
const STAGE_RECT = Rect2(0,0,720,315)
const WEAKNESS_BASELINE := Vector2(552,329)
const ELEMENT_NAMES := ["불꽃","새잎","번개","물결"]
const RESET = Rect2(616,0,88,88)
const SKILL = Rect2(190,950,240,112)
const EFFECTS = Rect2(424,0,88,88)
const MUTE = Rect2(520,0,88,88)
const HERO_RECT = Rect2(8,920,180,160)
const TARGET_RECT = Rect2(180,68,360,235)
const MUTED = Color("b9adc7")
const INK = Color("100c16")
const MINT = Color("dfb5ff")

static func color_rect(index: int) -> Rect2:
	return Rect2(96+136*index,220,120,88)

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
	var blocked: bool = view.detail_relic != ""
	var skill: Dictionary = SkillState.snapshot(session,blocked)
	var context: Dictionary = {} if view.sandbox else preview.get("combat_context",session.combat.damage_context())
	# Stage illustration is encounter-aware: only the actual final enemy is dragon.
	view.draw_rect(Rect2(0,0,720,1080),Color("0e0a14"))
	Art.draw_battle_stage(view,view,STAGE_RECT)
	view.draw_rect(Rect2(0,0,720,58),Color(0.035,0.015,0.065,0.84))
	view.draw_line(Vector2(0,58),Vector2(720,58),MaterialArt.GOLD.darkened(0.5),1)
	_modal_text(view,view,Vector2(23,40),"CHROMA",30,MaterialArt.GOLD,false,true)
	_modal_text(view,view,Vector2(322,39),"실험" if view.sandbox else "%d / 3"%(session.combat.encounter+1),26,Color("fff0d3"),true)
	view.draw_rect(Rect2(280,62,160,30),Color(0.035,0.015,0.065,0.85))
	view._center(Vector2(360,85),"행동 %d / 3"%(session.actions%3 if view.sandbox else session.combat.actions_in_turn),22,MUTED)
	view._text(Vector2(187,39),"%d G"%(0 if view.sandbox else session.gold),24,MaterialArt.GOLD)
	Art._star(view,EFFECTS.get_center()+Vector2(0,-13),12,Color("ad8dc8") if view.reduced_effects else Color("e3c2ff"))
	view._center(EFFECTS.get_center()+Vector2(0,18),"절제" if view.reduced_effects else "효과",20,MUTED)
	MaterialArt.glyph(view,MUTE.get_center()+Vector2(0,-13),"muted" if view.sound.muted else "sound",MUTED,27)
	view._center(MUTE.get_center()+Vector2(0,18),"OFF" if view.sound.muted else "ON",20,MUTED)
	MaterialArt.glyph(view,RESET.get_center()+Vector2(0,-13),"reset",MaterialArt.GOLD,28)
	view._center(RESET.get_center()+Vector2(0,18),"리셋",20,MUTED)
	# Seventy-five pixel combat rail; all values derive from the live session.
	MaterialArt.frame(view,Rect2(20,304,680,86),MaterialArt.GOLD,true)
	var enemy_name: String = "반격 없는 표적" if view.sandbox else ("결정룡 · 최종 전투" if session.combat.encounter==2 else session.combat.enemy_name)
	if not view.sandbox and session.combat.encounter==1 and session.route=="elite":enemy_name="정예 "+enemy_name
	view._text(Vector2(38,329),enemy_name,22,Color("fff0da"))
	var shown_hp:int=0 if view.sandbox else view.quality_fx.display_enemy_hp(session.combat.enemy_hp)
	var hp_text: String = "피해 %d"%session.damage_total if view.sandbox else "%d / %d"%[shown_hp,session.combat.enemy_max_hp]
	_modal_text(view,view,Vector2(385,329),hp_text,24,Color("ffe8ee"),true)
	if not view.sandbox:
		var weak: int = context.get("weakness_color",session.combat.weak_color)
		Art.draw_panel(view,{"pos":WEAKNESS_BASELINE+Vector2(-21,-7),"radius":12.0,"color":weak,"kind":"normal"},view.time)
		view._text(WEAKNESS_BASELINE,"약점 "+weakness_name(weak),22,COLORS[weak])
		view.draw_rect(Rect2(40,335,640,3),Color("321329"))
		view.draw_rect(Rect2(40,335,640*float(shown_hp)/session.combat.enemy_max_hp,3),Color("ed3465"))
	var lines: Array = [view.status,""] if view.sandbox else intent_lines(context)
	if not preview.is_empty():
		if not preview.get("valid",false):
			lines=["일반 공격 패널을 골라주세요","하트·기존 핵에는 심을 수 없어요" if session.character_id=="noa" else "하트·핵은 변환하지 않아요"] if preview.get("mode","")=="skill" else ["같은 색 2개부터 골라주세요","놓아도 행동을 쓰지 않아요"]
		elif preview.mode == "skill":
			lines=["%d개 변환 → 연결 %d개"%[preview.targets.size(),preview.connected.size()],"놓으면 변환 · 소거 행동 없음"] if session.character_id!="noa" else ["강화핵 심기" if "pigment" in session.relics else "물감핵 심기","놓으면 설치 · 다음 입력에서 핵을 눌러 기동"]
		else:
			lines=["직접 %d · 연쇄 %d"%[preview.direct.size(),preview.removed.size()-preview.direct.size()],preview_effect_line(preview)]
			var effects := "회복 %d → %d · 초과 %d"%[preview.heal_raw,preview.heal_effective,preview.heal_overflow]
			if not preview.spawn.is_empty(): effects += " · "+("강화핵 생성" if preview.spawn.kind=="strong" else "물감핵 생성")
			if preview.get("ash_reserve",false): effects += " · 충전 예약"
			view.draw_rect(Rect2(32,278,656,30),Color(0.035,0.015,0.065,0.90))
			_line(view,Vector2(360,300),effects,22,640,Color("fff0d3"))
	elif session.phase=="enemy_attack": lines=["적의 반격 · %d 피해"%session.combat.last_attack_damage,""]
	if not view.sandbox and session.phase=="ready" and session.combat.encounter==0 and session.actions<3 and preview.is_empty():
		var hint:String="스킬 → 색 → 일반 패널 · 변환 후 직접 소거" if session.character_id=="rio" else "스킬 → 일반 패널에 핵 심기 → 핵을 눌러 기동"
		view.draw_rect(Rect2(16,260,688,38),Color(0.035,0.015,0.065,0.9))
		if session.skill_uses>0:
			hint=("심은 핵을 눌러 폭발 · 단독 기동도 행동1회" if session.character_id=="noa" else "변환한 같은 색 묶음을 누르고 놓아 소거") if session.actions==0 else "소거3회 충전 · 하트도 행동 · 예고를 확인하세요"
		_line(view,Vector2(360,286),hint,23,672,MINT)
	_line(view,Vector2(360,361),lines[0],22,640,Color("fff0e6"))
	_line(view,Vector2(360,384),lines[1],22,640,MINT)
	# One cached mesh shades the board once. Logical coordinates are unchanged.
	MaterialArt.frame(view,Rect2(24,388,672,534),MaterialArt.GOLD,true)
	# The dock never overlaps a live panel or ingress area.
	MaterialArt.frame(view,Rect2(4,922,712,154),MaterialArt.GOLD,true)
	Art.draw_premium_hero(view,HERO_RECT,view.time,view.hero_active>0.0)
	view._text(Vector2(22,1067),Characters.definition(session.character_id).name+(" · 임시 초상" if session.character_id=="noa" else ""),22,Color("fff0dc"))
	view.draw_rect(Rect2(199,928,491,17),Color("321f45"))
	view.draw_rect(Rect2(201,930,487*float(session.hp)/session.max_hp,13),Color("a650df"))
	_modal_text(view,view,Vector2(446,946),"생명 %d / %d"%[session.hp,session.max_hp],22,Color.WHITE,true)
	Art.draw_skill_button(view,SKILL,skill.illuminated,0.0 if view.reduced_effects else float(view.ready_age))
	_modal_text(view,view,Vector2(310,1006),Characters.definition(session.character_id).button,30,Color("fff0ff") if skill.illuminated else MUTED,true,true)
	_modal_text(view,view,Vector2(310,1032),(("패널 선택" if skill.plants_core else "색 선택") if session.skill_mode else skill.status_text)+" · "+skill.charge_text,22,Color("f3d6ff") if skill.illuminated else MUTED,true)
	view._center(Vector2(310,1070),("강화핵1개 · 행동 없음" if "pigment" in session.relics else "물감핵1개 · 행동 없음") if skill.plants_core else "최대 %d개 · 행동 없음"%skill.conversion_max,22,MUTED)
	if skill.reservation_text!="":view._text(Vector2(446,970),skill.reservation_text,22,MINT)
	for i in range(3):
		var rect := owned_rect(i)
		MaterialArt.frame(view,rect,MaterialArt.GOLD)
		if i<session.relics.size(): RelicArt.draw_icon(view,session.relics[i],rect.grow(-6))
		else: view._center(rect.get_center()+Vector2(0,8),"·",28,Color("66536f"))
	if session.skill_mode and not skill.plants_core:
		for i in range(4):
			var rect := color_rect(i)
			var selected: bool = session.skill_color==i
			MaterialArt.button(view,rect,COLORS[i],"selected" if selected else "normal")
			Art.draw_panel(view,{"pos":rect.position+Vector2(33,34),"radius":19.0,"color":i,"kind":"normal"},view.time)
			view._text(rect.position+Vector2(65,42),"✓" if selected else "",22,Color.WHITE)
			view._center(rect.position+Vector2(60,74),ELEMENT_NAMES[i],24,COLORS[i])

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
	if session.phase=="departure":
		CharacterUI.draw(view,canvas)
		return
	if session.phase in ["route","shop"]:
		draw_route_shop_modal(view,canvas)
		return
	if session.phase in ["between","victory","defeat"]:
		draw_run_modal(view,canvas)
		return
	if session.phase != "reward" and session.phase != "summary":
		return
	# Overlay child renders after the board. Reset remains visible and usable.
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.035,0.015,0.065,0.94))
	_modal_box(canvas,Rect2(32,216,656,576),Color("1a1029"),Color("b59164"),24)
	if session.phase == "reward":
		_modal_text(view,canvas,Vector2(64,257),"유물을 골라주세요" if view.sandbox else "승리 보상 · 유물을 골라주세요",30,Color("fff1ff"),false,true)
		_modal_text(view,canvas,Vector2(64,287),"%d / 2 선택 · 새로운 유물 하나를 골라요" % session.reward_round if view.sandbox else "승리 골드 지급 · %d G 보유 · 유물 %d / 2" % [session.gold,session.reward_round],22,MUTED)
		var count: int = session.reward_options.size()
		for i in range(count):
			var id: String = session.reward_options[i]
			var copy: Dictionary = relic_copy(id,session)
			var rect := reward_rect(i,count)
			var tint: Color = [MINT,COLORS[2],COLORS[3]][["pigment","lens","ash"].find(id)]
			MaterialArt.button(canvas,rect,tint,"pressed" if view.modal_phase == "reward" and view.modal_index == i else "normal")
			canvas.draw_rect(Rect2(rect.position+Vector2(0,20),Vector2(3,86)),tint)
			RelicArt.draw_icon(canvas,id,Rect2(rect.position+Vector2(10,15),Vector2(100,100)))
			_modal_text(view,canvas,rect.position+Vector2(119,31),copy.name,27,tint)
			_modal_text(view,canvas,rect.position+Vector2(119,60),copy.change,22,Color("f2f5fa"))
			for row in range(copy.lines.size()):
				_modal_text(view,canvas,rect.position+Vector2(119,85+25*row),copy.lines[row],22,Color("cdbeda"))
		_modal_text(view,canvas,Vector2(360,768),"원하는 카드 위에서 눌렀다 놓으세요",22,MUTED,true)
	else:
		_modal_text(view,canvas,Vector2(64,259),"9회 성장 실험 완료",30,Color("fff1ff"))
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
				_modal_text(view,canvas,Vector2(columns[col],y+4),values[col],25,Color("f7efff") if col else MINT,true)
		var names: Array[String] = []
		for id in session.relics:
			names.append(RELIC_COPY[id].name)
		_modal_text(view,canvas,Vector2(360,583),"선택 유물 · " + " + ".join(names),22,Color("c5d7e8"),true)
		_modal_text(view,canvas,Vector2(360,623),"이후에는 추가 보상 없이 자유롭게 플레이해요.",22,MUTED,true)
		MaterialArt.button(canvas,SUMMARY_CONTINUE,MINT,"pressed" if view.modal_index >= 0 and view.modal_phase == session.phase and (session.phase != "shop" or view.modal_index == 2) else "ready")
		_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"계속 플레이",28,Color("fff0ff"),true)


const DETAIL_PANEL = Rect2(48,310,624,430)
const DETAIL_CLOSE = Rect2(84,650,552,88)

static func owned_rect(index:int)->Rect2:
	return Rect2(440+88*index,976,88,88)

static func draw_details(view,canvas:CanvasItem)->void:
	if view.detail_relic=="":return
	var id:String=view.detail_relic
	if not RELIC_COPY.has(id):return
	var copy:Dictionary=relic_copy(id,view.session)
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.035,0.015,0.065,0.94))
	_modal_box(canvas,DETAIL_PANEL,Color("211432"),Color("c8a676"),24)
	RelicArt.draw_icon(canvas,id,Rect2(76,337,116,116))
	_modal_text(view,canvas,Vector2(210,380),copy.name,32,MINT)
	_modal_text(view,canvas,Vector2(210,419),"보유 중 · 성장 실험 유물" if view.sandbox else "보유 중 · 이번 탐험에 적용",22,MUTED)
	_modal_text(view,canvas,Vector2(84,493),copy.change,25,Color("fff0c7"))
	for row in range(copy.lines.size()):
		_modal_text(view,canvas,Vector2(84,540+32*row),copy.lines[row],24,Color("e1d4ed"))
	_modal_text(view,canvas,Vector2(360,620),"설명을 닫아도 보드와 충전은 유지돼요",22,MUTED,true)
	MaterialArt.button(canvas,DETAIL_CLOSE,MINT,"ready")
	_modal_text(view,canvas,DETAIL_CLOSE.get_center()+Vector2(0,9),"닫기",28,Color("fff0ff"),true)


static func draw_run_modal(view,canvas:CanvasItem)->void:
	var session = view.session
	var combat = session.combat
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.035,0.015,0.065,0.94))
	_modal_box(canvas,Rect2(32,216,656,576),Color("1a1029"),Color("b59164"),24)
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
		_modal_text(view,canvas,Vector2(360,352+i*56),lines[i],26,Color("f7efff") if i<2 else MUTED,true)
	if session.phase in ["victory","defeat"]:
		_modal_text(view,canvas,Vector2(360,315),Characters.definition(session.character_id).name+" · "+Characters.definition(session.character_id).role,24,MINT,true)
	for i in range(session.relics.size()):
		RelicArt.draw_icon(canvas,session.relics[i],Rect2(360-(session.relics.size()*88-16)/2.0+i*88,554,72,72))
	MaterialArt.button(canvas,SUMMARY_CONTINUE,MINT,"pressed" if view.modal_index >= 0 and view.modal_phase == session.phase and (session.phase != "shop" or view.modal_index == 2) else "ready")
	_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"다음 전투" if session.phase == "between" else "캐릭터 선택으로",28,Color("fff0ff"),true)


static func route_name(id:String)->String:
	return "안전한 길" if id == "safe" else ("정예의 길" if id == "elite" else "선택 전")

static func route_rect(index:int)->Rect2:
	return Rect2(64,350+156*index,592,140)

static func shop_rect(index:int)->Rect2:
	return route_rect(index)

static func modal_rect(phase:String,index:int,reward_count:int=0)->Rect2:
	if phase=="departure":return character_rect(index) if index<2 else DEPART
	if phase == "reward": return reward_rect(index,reward_count)
	if phase == "route": return route_rect(index)
	if phase == "shop" and index < 2: return shop_rect(index)
	return SUMMARY_CONTINUE

static func draw_route_shop_modal(view,canvas:CanvasItem)->void:
	var session = view.session
	canvas.draw_rect(Rect2(0,208,720,872),Color(0.035,0.015,0.065,0.94))
	_modal_box(canvas,Rect2(32,216,656,576),Color("1a1029"),Color("b59164"),24)
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
			_modal_text(view,canvas,rect.position+Vector2(24,95),info.pattern,25,Color("e3d5ed"))
			_modal_text(view,canvas,rect.position+Vector2(24,124),"4개 연결 기회가 없으면 공격 %d" % (5 if i == 0 else 6),22,MUTED)
		_modal_text(view,canvas,Vector2(360,705),"카드를 눌렀다 놓으면 전투로 출발해요",23,Color("e3d5ed"),true)
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
		var effect: String = "최대 8 회복 · 한 번만 구매" if i == 0 else (relic_copy(relic,session).change if relic != "" else "새로운 유물은 추가하지 않아요")
		_modal_text(view,canvas,rect.position+Vector2(119,94),effect,22,MUTED)
		var state: String = "구매 완료" if sold else ("생명 가득 · 구매 불가" if i == 0 and gain == 0 else ("골드 부족" if session.gold < price else "눌렀다 놓으면 구매"))
		_modal_text(view,canvas,rect.position+Vector2(119,124),state,22,tint)
	MaterialArt.button(canvas,SUMMARY_CONTINUE,MINT,"pressed" if view.modal_index >= 0 and view.modal_phase == session.phase and (session.phase != "shop" or view.modal_index == 2) else "ready")
	_modal_text(view,canvas,SUMMARY_CONTINUE.get_center()+Vector2(0,9),"최종 전투로",28,Color("fff0ff"),true)


static func weakness_name(color:int)->String:
	return ELEMENT_NAMES[color] if color >= 0 and color < ELEMENT_NAMES.size() else "없음"

static func character_rect(index:int)->Rect2:
	return CharacterUI.character_rect(index)

static func relic_copy(id:String,session)->Dictionary:
	return Characters.pigment_copy(session.character_id) if id=="pigment" else RELIC_COPY[id]

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

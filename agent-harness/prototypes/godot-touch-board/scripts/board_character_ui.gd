extends RefCounted
## Departure only; all buttons share the controller's pointer/serial ownership.
const Characters=preload("res://scripts/board_characters.gd")
const MaterialArt=preload("res://scripts/board_premium_skin.gd")
const PixelHeroes=preload("res://scripts/board_pixel_heroes.gd")
const DEPART=Rect2(84,790,552,96)

static func character_rect(index:int)->Rect2:
	return Rect2(48,278+206*index,624,188)

static func draw(view,canvas:CanvasItem)->void:
	var ui=view.UI
	var session=view.session
	canvas.draw_rect(Rect2(0,88,720,992),Color("100b1b"))
	ui._modal_text(view,canvas,Vector2(360,159),"한 명을 골라 출발하세요",36,Color("fff0d3"),true,true)
	ui._modal_text(view,canvas,Vector2(360,200),"선택한 한 캐릭터로 한 구역을 탐험합니다",25,Color("dfc8ec"),true)
	ui._modal_text(view,canvas,Vector2(360,240),"색을 바꾸는 리오 · 색비를 부르는 노아",22,ui.MUTED,true)
	for i in range(Characters.IDS.size()):
		var id:String=Characters.IDS[i]
		var hero:Dictionary=Characters.definition(id)
		var rect:=character_rect(i)
		var selected:bool=session.departure_choice==id
		var pressed:bool=view.modal_phase=="departure" and view.modal_index==i
		MaterialArt.button(canvas,rect,Color("dfb5ff"),"pressed" if pressed else ("selected" if selected else "normal"))
		PixelHeroes.draw(canvas,Rect2(rect.position+Vector2(4,16),Vector2(132,156)),id,view.time,"skill" if selected else "idle",view.reduced_effects)
		ui._modal_text(view,canvas,rect.position+Vector2(142,39),hero.name+" · "+hero.role+("  ✓" if selected else ""),31,Color("fff0d3"),false,true)
		ui._modal_text(view,canvas,rect.position+Vector2(142,72),hero.summary,24,Color("e8c9ff"))
		for row in range(3):ui._modal_text(view,canvas,rect.position+Vector2(142,103+29*row),hero.lines[row],23,Color("e6dfed"))
	var hint:String="카드를 고른 뒤 출발을 눌러주세요"
	if session.departure_choice=="rio":hint="번짐 안료: 변환색 낙하 1회 추가"
	elif session.departure_choice=="noa":hint="번짐 안료: 고정 낙하 2회 → 3회"
	ui._modal_text(view,canvas,Vector2(360,723),hint,25,Color("e8c9ff"),true)
	ui._modal_text(view,canvas,Vector2(360,759),"스킬 피해 없음 · 고정 낙하 중 충전 정지",23,ui.MUTED,true)
	var enabled:bool=not session.departure_choice.is_empty()
	MaterialArt.button(canvas,DEPART,Color("dfb5ff"),"disabled" if not enabled else ("pressed" if view.modal_index==2 else "ready"))
	var label:String=Characters.definition(session.departure_choice).name+"로 출발" if enabled else "캐릭터를 선택하세요"
	ui._modal_text(view,canvas,DEPART.get_center()+Vector2(0,11),label,32,Color("fff0ff") if enabled else ui.MUTED,true,true)
	ui._modal_text(view,canvas,Vector2(360,941),"출발 후 변경 불가 · 승패와 리셋 후 다시 선택",23,ui.MUTED,true)
	ui._modal_text(view,canvas,Vector2(360,980),"완료 행동마다 자동 저장 · 진행 중 종료는 직전으로" if view.lifecycle.enabled else "저장하지 않는 테스트 탐험",22,ui.MUTED,true)

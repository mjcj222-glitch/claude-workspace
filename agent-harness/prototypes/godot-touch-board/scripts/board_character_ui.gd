extends RefCounted
## Departure only; all buttons share the controller's pointer/serial ownership.
const Characters=preload("res://scripts/board_characters.gd")
const MaterialArt=preload("res://scripts/board_premium_skin.gd")
const Art=preload("res://scripts/board_art.gd")
const DEPART=Rect2(84,790,552,96)

static func character_rect(index:int)->Rect2:
	return Rect2(48,278+206*index,624,188)

static func draw(view,canvas:CanvasItem)->void:
	var ui=view.UI
	var session=view.session
	canvas.draw_rect(Rect2(0,88,720,992),Color("100b1b"))
	ui._modal_text(view,canvas,Vector2(360,159),"한 명을 골라 출발하세요",36,Color("fff0d3"),true,true)
	ui._modal_text(view,canvas,Vector2(360,200),"선택한 한 캐릭터로 한 구역을 탐험합니다",25,Color("dfc8ec"),true)
	ui._modal_text(view,canvas,Vector2(360,240),"능력은 다르게 · 초상화는 공용 임시 자산",22,ui.MUTED,true)
	for i in range(Characters.IDS.size()):
		var id:String=Characters.IDS[i]
		var hero:Dictionary=Characters.definition(id)
		var rect:=character_rect(i)
		var selected:bool=session.departure_choice==id
		var pressed:bool=view.modal_phase=="departure" and view.modal_index==i
		MaterialArt.button(canvas,rect,Color("dfb5ff"),"pressed" if pressed else ("selected" if selected else "normal"))
		if i==0:
			for color in range(3):Art.draw_panel(canvas,{"pos":rect.position+Vector2(42+color*22,62+color*24),"radius":23.0,"color":color,"kind":"normal"},view.time)
		else:Art.draw_panel(canvas,{"pos":rect.position+Vector2(70,92),"radius":42.0,"color":3,"kind":"core"},view.time)
		ui._modal_text(view,canvas,rect.position+Vector2(142,39),hero.name+" · "+hero.role+("  ✓" if selected else ""),31,Color("fff0d3"),false,true)
		ui._modal_text(view,canvas,rect.position+Vector2(142,72),hero.summary,24,Color("e8c9ff"))
		for row in range(3):ui._modal_text(view,canvas,rect.position+Vector2(142,103+29*row),hero.lines[row],23,Color("e6dfed"))
	var hint:String="카드를 고른 뒤 출발을 눌러주세요"
	if session.departure_choice=="rio":hint="번짐 안료: 변환4개 → 5개"
	elif session.departure_choice=="noa":hint="번짐 안료: 심는 핵을 강화핵으로"
	ui._modal_text(view,canvas,Vector2(360,723),hint,25,Color("e8c9ff"),true)
	ui._modal_text(view,canvas,Vector2(360,759),"스킬은 행동·피해 없음 · 소거3회 충전",23,ui.MUTED,true)
	var enabled:bool=not session.departure_choice.is_empty()
	MaterialArt.button(canvas,DEPART,Color("dfb5ff"),"disabled" if not enabled else ("pressed" if view.modal_index==2 else "ready"))
	var label:String=Characters.definition(session.departure_choice).name+"로 출발" if enabled else "캐릭터를 선택하세요"
	ui._modal_text(view,canvas,DEPART.get_center()+Vector2(0,11),label,32,Color("fff0ff") if enabled else ui.MUTED,true,true)
	ui._modal_text(view,canvas,Vector2(360,941),"출발 후 변경 불가 · 승패와 리셋 후 다시 선택",23,ui.MUTED,true)
	ui._modal_text(view,canvas,Vector2(360,980),"저장되지 않는 짧은 탐험 프로토타입",22,ui.MUTED,true)

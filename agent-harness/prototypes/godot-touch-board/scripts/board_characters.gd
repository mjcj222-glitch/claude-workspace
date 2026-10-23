extends RefCounted
## Immutable hero definitions and pure skill plans. No physics/combat mutation.
const Rules = preload("res://scripts/board_rules.gd")
const IDS := ["rio", "noa"]
const DEFS := {
	"rio": {"name":"리오", "role":"변환사", "skill":"색 물결", "button":"변환", "summary":"색을 모아 큰 연결을 만드는 운영", "lines":["색 선택 → 일반 패널을 누르고 놓기", "고른 원래 색 전체를 목표 색으로", "변환 후 같은 색 묶음을 직접 소거"]},
	"noa": {"name":"노아", "role":"핵술사", "skill":"별빛 소나기", "button":"소나기", "summary":"핵을 심고 폭발 시점을 고르는 운영", "lines":["스킬 → 일반 패널 하나를 누르고 놓기", "핵 설치 + 같은 색 낙하 2회", "직접 소거 → 일반 낙하 색 고정"]},
}

static func definition(id:String)->Dictionary:
	return DEFS.get(id,DEFS.rio).duplicate(true)

static func skill_plan(panels:Array,start_id:int,color:int,relics:Array,hero:String)->Dictionary:
	var result:Dictionary={"valid":false,"targets":[],"converted":{},"connected":[],"planted":{},"character_id":hero}
	if hero not in IDS:return result
	var indexed:Dictionary=Rules._index(panels)
	if indexed.size()!=panels.size() or not indexed.has(start_id) or indexed[start_id].kind!="normal":return result
	if hero=="rio":
		if color not in range(4) or color==indexed[start_id].color:return result
		for panel in panels:
			if panel.kind=="normal" and panel.color==indexed[start_id].color:
				result.targets.append(panel.id);result.converted[panel.id]=color
		result.valid=true
		result["rain_refills"]=1 if relics.has("pigment") else 0
		result["rain_color"]=color
		var future:Array=panels.duplicate(true)
		for panel in future:
			if result.converted.has(panel.id):panel.color=color
		result.connected=Rules.plan(future,start_id,30,30).removed
		return result
	result["rain_refills"]=3 if relics.has("pigment") else 2
	result["rain_color"]=int(indexed[start_id].color)
	var kind:String="strong" if relics.has("pigment") else "core"
	result.valid=true
	result.targets=[start_id]
	result.planted={start_id:kind}
	# Ghost the same existing core planner's connected reach. It is not a clear,
	# damage, enemy mitigation, or a promise about any future fallen board.
	var future:Array=panels.duplicate(true)
	for p in future:
		if p.id==start_id:p.kind=kind
	result.connected=Rules.plan(future,start_id,30,30).removed
	return result

static func pigment_copy(hero:String)->Dictionary:
	if hero=="noa":
		return {"name":"번짐 안료","change":"강화핵 + 고정 낙하 2 → 3회","lines":["일반 낙하만 · 하트는 그대로", "고정 낙하 중에는 충전하지 않아요."]}
	return {"name":"번짐 안료","change":"색 물결 뒤 고정 낙하 1회","lines":["다음 소거의 일반 낙하도 목표 색", "그 소거는 충전하지 않아요."]}

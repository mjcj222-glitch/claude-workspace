extends RefCounted
## Immutable hero definitions and pure skill plans. No physics/combat mutation.
const Rules = preload("res://scripts/board_rules.gd")
const IDS := ["rio", "noa"]
const DEFS := {
	"rio": {"name":"리오", "role":"변환사", "skill":"물감 변환", "button":"변환", "summary":"색을 모아 큰 연결을 만드는 운영", "lines":["색 선택 → 일반 패널을 누르고 놓기", "가까운 일반 패널 최대4개를 변환", "변환 후 같은 색 묶음을 직접 소거"]},
	"noa": {"name":"노아", "role":"핵술사", "skill":"촉매 심기", "button":"핵 심기", "summary":"핵을 심고 폭발 시점을 고르는 운영", "lines":["스킬 → 일반 패널 하나를 누르고 놓기", "그 자리에 같은 색 물감핵을 설치", "다음 입력에서 핵을 눌러 폭발"]},
}

static func definition(id:String)->Dictionary:
	return DEFS.get(id,DEFS.rio).duplicate(true)

static func skill_plan(panels:Array,start_id:int,color:int,relics:Array,hero:String)->Dictionary:
	if hero=="rio":
		var result:Dictionary=Rules.skill_plan(panels,start_id,color,relics)
		result["planted"]={}
		result["character_id"]=hero
		return result
	var result:Dictionary={"valid":false,"targets":[],"converted":{},"connected":[],"planted":{},"character_id":hero}
	if hero!="noa":return result
	var indexed:Dictionary=Rules._index(panels)
	if indexed.size()!=panels.size() or not indexed.has(start_id) or indexed[start_id].kind!="normal":return result
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
		return {"name":"번짐 안료","change":"심는 핵: 일반핵 → 강화핵","lines":["이번 스킬로 심는 핵만", "변환 범위가 접촉1단계 → 2단계."]}
	return {"name":"번짐 안료","change":"스킬 변환 4개 → 5개","lines":["선택한 패널을 포함해", "일반 패널을 최대5개 변환해요."]}

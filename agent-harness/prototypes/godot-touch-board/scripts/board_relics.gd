extends RefCounted
## Stable identifiers and concise player-facing copy; no mutable session state.

const IDS := ["pigment", "lens", "ash", "petal"]
const DEFS := {
 "petal":{"id":"petal","name":"수호 꽃잎","change":"직접 하트 3개 → 예고 약화 · 회복 절반","description":"직접 연결한 하트 3개 이상으로 현재 조건부 공격을 약화합니다. 하트 회복은 개당 1입니다. 일반 공격은 약화하지 않고 중첩되지 않습니다."},
	"pigment": {
		"id": "pigment",
		"name": "번짐 안료",
		"change": "변환 최대 4개 → 5개",
		"description": "선택한 패널부터 가까운 일반 공격 패널을 하나 더 변환합니다. 하트와 핵은 건너지 않습니다.",
	},
	"lens": {
		"id": "lens",
		"name": "응축 렌즈",
		"change": "물감핵 6개 → 5개 · 강화핵 12개 → 11개",
		"description": "직접 연결한 일반 공격 패널로 핵을 더 일찍 만듭니다. 한 행동에 하나만 생성합니다. 강화핵 발동 뒤 준비되는 폭탄은 대형으로 강화합니다.",
	},
	"ash": {
		"id": "ash",
		"name": "잿빛 보석",
		"change": "다음 스킬 사용 후 충전 3회 → 2회 예약",
		"description": "직접 연결한 일반 공격 패널 6개부터 충전을 예약합니다. 하트·기존 핵·추가 연쇄는 세지 않습니다.",
	},
}

static func available(owned: Array) -> Array:
	var result: Array = []
	if owned.size()>=3:return result.slice(0,3)
	for id in IDS:
		if not owned.has(id):
			result.append(id)
	return result.slice(0,3)

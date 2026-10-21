extends RefCounted
const Rules = preload("res://scripts/board_rules.gd")
const FIGHTS := [
	{"name":"연습 표적", "hp":24, "attack":4, "every":3},
	{"name":"수호 표적", "hp":36, "attack":5, "every":3},
	{"name":"격동 표적", "hp":48, "attack":6, "every":3},
]
const ROUTES := {
	"safe": {"name":"안전한 길", "hp":36, "gold":4, "pattern":"경감 7→3 · 일반 5"},
	"elite": {"name":"정예의 길", "hp":44, "gold":8, "pattern":"경감 8→4 · 일반 6"},
}
var route: String = "safe"
var encounter: int = 0
var enemy_hp: int = 24
var enemy_max_hp: int = 24
var enemy_name: String = "연습 표적"
var turn: int = 0
var actions_in_turn: int = 0
var incoming_damage: int = 4
var mitigation_active: bool = false
var mitigation_success: bool = false
var fallback_plain: bool = false
var enemies_defeated: int = 0
var last_attack_damage: int = 0
var attacks_total: int = 0

var _turn_prepared: bool = false
var _attack_taken: bool = false
var _victory_counted: bool = false

func start_fight(index: int, panels: Array, selected_route: String = "safe") -> void:
	route = selected_route if ROUTES.has(selected_route) else "safe"
	encounter = clampi(index, 0, FIGHTS.size()-1)
	weak_color = 0 if encounter == 0 else (3 if encounter == 2 else (2 if route == "elite" else 1))
	var definition: Dictionary = FIGHTS[encounter]
	enemy_max_hp = int(ROUTES[route].hp) if encounter == 1 else int(definition.hp)
	enemy_hp = enemy_max_hp
	enemy_name = definition.name
	turn = 0
	actions_in_turn = 0
	last_attack_damage = 0
	_victory_counted = false
	_attack_taken = false
	_turn_prepared = false
	prepare_turn(panels)

func prepare_turn(panels: Array) -> void:
	# Each intent is frozen from the CURRENT settled board. Query the same
	# canonical rule planner used by player previews; no skill/future/RNG search.
	if _turn_prepared:
		return
	_turn_prepared = true
	intent_serial += 1
	intent = "plain"
	mitigation_active = false
	mitigation_success = false
	fallback_plain = false
	if encounter == 0:
		incoming_damage = 4
	elif encounter == 2:
		incoming_damage = 6
		if turn % 2 == 0:
			intent = "slam"
			incoming_damage = 10
			for panel in panels:
				var candidate: Dictionary = Rules.plan(panels, int(panel.id), 0, 1, [], damage_context())
				if candidate.get("valid", false) and candidate.get("mitigates_intent", false):
					mitigation_active = true
					break
			if not mitigation_active:
				intent = "plain"
				incoming_damage = 6
				fallback_plain = true
	else:
		incoming_damage = 5 + _route_attack_bonus()
		if turn % 2 == 0:
			for panel in panels:
				var candidate: Dictionary = Rules.plan(panels, int(panel.id), 0, 1, [], damage_context())
				if candidate.get("valid", false) and _direct_count(candidate) >= 4:
					mitigation_active = true
					intent = "direct4"
					incoming_damage = 7 + _route_attack_bonus()
					break
			fallback_plain = not mitigation_active

func _route_attack_bonus() -> int:
	return 1 if encounter == 1 and route == "elite" else 0

func _direct_count(plan: Dictionary) -> int:
	var unique: Dictionary = {}
	for id in plan.get("direct", []):
		unique[id] = true
	return unique.size()

func record_clear(plan: Dictionary) -> void:
	# Skill and invalid gestures are not combat actions; guard the API as well
	# as relying on the controller to only forward committed clear plans.
	if not plan.get("valid", false) or plan.get("mode", "clear") != "clear":
		return
	if enemy_hp <= 0 or _attack_taken or actions_in_turn >= 3:
		return
	enemy_hp = maxi(0, enemy_hp - maxi(0, int(plan.get("damage", 0))))
	actions_in_turn += 1
	if mitigation_active:
		if intent == "slam" and (int(plan.get("weak_count",0)) >= 2 or int(plan.get("normal_count",0)) >= 8):
			mitigation_success = true
			incoming_damage = 4
		elif intent == "direct4" and _direct_count(plan) >= 4:
			mitigation_success = true
			incoming_damage = 3 + _route_attack_bonus()

func resolve() -> String:
	# Victory precedes the third-clear retaliation check.
	if enemy_hp <= 0:
		if not _victory_counted:
			enemies_defeated += 1
			_victory_counted = true
		return "win"
	return "attack" if actions_in_turn >= 3 else "ready"

func take_attack() -> int:
	if _attack_taken or enemy_hp <= 0 or actions_in_turn < 3:
		return 0
	_attack_taken = true
	last_attack_damage = incoming_damage
	attacks_total += 1
	return last_attack_damage

func next_turn(panels: Array) -> void:
	# Called after attack animation; duplicate calls cannot skip turns.
	if not _attack_taken or enemy_hp <= 0:
		return
	actions_in_turn = 0
	turn += 1
	_attack_taken = false
	_turn_prepared = false
	prepare_turn(panels)

func telegraph_text() -> String:
	if mitigation_active:
		if mitigation_success:
			return "조건 성공 · 다음 공격 %d" % incoming_damage
		if intent == "slam":
			return "약점 2개 또는 일반 패널 8개를 한 번에 지우면 강타 10 → 4"
		return "4개 이상 연결을 한 번 지우면 공격 %d → %d" % [7 + _route_attack_bonus(), 3 + _route_attack_bonus()]
	return "3회 소거 후 공격 %d" % incoming_damage

var weak_color: int = 0
var intent: String = "plain"
var intent_serial: int = 0
func damage_context() -> Dictionary:
	return {"weakness_color":weak_color,"intent":intent,"intent_serial":intent_serial,
		"incoming_damage":incoming_damage,"mitigation_success":mitigation_success}

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
var pending_damage:int=0
var pending_shield:int=0
var pending_removed:int=0
var pending_base:int=0
var pending_weak:int=0
var pending_specials:int=0
var pending_big_bombs:int=0
var pending_bombs:int=0
var strike_settled:bool=false
var shield_hp:int=0
var shield_color:int=0
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
	_reset_bank()
	shield_hp=12 if encounter==2 else 0
	var counts=[0,0,0,0]
	for panel in panels:
		if panel.kind=="normal":counts[panel.color]+=1
	shield_color=counts.find(counts.max())
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
	pending_damage+=maxi(0,int(plan.get("damage",0)))
	pending_shield+=maxi(0,int(plan.get("shield_damage",0)))
	pending_removed+=plan.get("removed",[]).size()
	pending_base+=int(plan.get("base_damage",plan.get("damage",0)))
	pending_weak+=int(plan.get("weak_bonus",0))
	pending_specials+=plan.get("activated",[]).size()
	pending_bombs+=plan.get("blasts",[]).size()
	for blast in plan.get("blasts",[]):
		if blast.get("kind","")=="big_bomb":pending_big_bombs+=1
	actions_in_turn += 1
	if mitigation_active:
		if intent == "slam" and (plan.get("petal_guard",false) or Rules.slam_mitigated(int(plan.get("weak_count",0)), int(plan.get("normal_count",0)), plan.get("combat_context", damage_context()))):
			mitigation_success = true
			incoming_damage = 4
		elif intent == "direct4" and (_direct_count(plan) >= 4 or plan.get("petal_guard",false)):
			mitigation_success = true
			incoming_damage = 3 + _route_attack_bonus()

func _reset_bank()->void:
	pending_damage=0;pending_shield=0;pending_removed=0;pending_base=0;pending_weak=0;pending_specials=0;pending_bombs=0;pending_big_bombs=0;strike_settled=false

func bank_plan()->Dictionary:
	return {"damage":pending_damage,"base_damage":pending_base,"weak_bonus":pending_weak,"shield_damage":pending_shield,"shield_broken":shield_hp>0 and pending_shield>=shield_hp,"combat_context":{"shield_color":shield_color},"core_activations":maxi(0,pending_specials-pending_bombs),"bomb_activations":pending_bombs,"big_bombs":pending_big_bombs}

func settle_attack()->bool:
	if actions_in_turn<3 or strike_settled or enemy_hp<=0:return false
	strike_settled=true
	enemy_hp=maxi(0,enemy_hp-pending_damage)
	shield_hp=maxi(0,shield_hp-pending_shield)
	pending_damage=0;pending_shield=0;pending_removed=0;pending_base=0;pending_weak=0;pending_specials=0;pending_bombs=0;pending_big_bombs=0
	return true

func resolve() -> String:
	if actions_in_turn>=3 and not strike_settled:return "strike"
	# Victory precedes retaliation only after the single banked attack.
	if enemy_hp <= 0:
		if not _victory_counted:
			enemies_defeated += 1
			_victory_counted = true
		return "win"
	return "attack" if actions_in_turn >= 3 else "ready"

func take_attack() -> int:
	if _attack_taken or enemy_hp <= 0 or actions_in_turn < 3 or not strike_settled:
		return 0
	_attack_taken = true
	last_attack_damage = incoming_damage
	attacks_total += 1
	return last_attack_damage

func next_turn(panels: Array) -> void:
	# Called after attack animation; duplicate calls cannot skip turns.
	if not _attack_taken or enemy_hp <= 0:
		return
	_reset_bank()
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
			var context := damage_context()
			return "약점 %d개 또는 일반 패널 %d개를 한 번에 지우면 강타 10 → 4" % [context.slam_weak_required, context.slam_normal_required]
		return "4개 이상 연결을 한 번 지우면 공격 %d → %d" % [7 + _route_attack_bonus(), 3 + _route_attack_bonus()]
	return "3회 소거 후 공격 %d" % incoming_damage

var weak_color: int = 0
var intent: String = "plain"
var intent_serial: int = 0
func damage_context() -> Dictionary:
	return {"shield_hp":maxi(0,shield_hp-pending_shield),"shield_color":shield_color,"weakness_color":weak_color,"intent":intent,"intent_serial":intent_serial,
		"incoming_damage":incoming_damage,"mitigation_success":mitigation_success,
		"slam_weak_required":Rules.SLAM_WEAK_REQUIRED,"slam_normal_required":Rules.SLAM_NORMAL_REQUIRED}

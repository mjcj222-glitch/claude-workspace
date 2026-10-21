extends "res://scripts/board_session.gd"
## Three-fight orchestration; inherited clear/skill accounting remains the only
## authority for player resources. No timers, visual callbacks or motion rules.
var combat = preload("res://scripts/board_combat.gd").new()

func _init() -> void:
	hp = max_hp

func initialize_board(fresh_panels: Array, fresh_next_id: int) -> void:
	panels = fresh_panels.duplicate(true)
	next_id = fresh_next_id
	cancel()
	skill_mode = false
	combat.start_fight(0, panels)
	phase = "ready"

func release(point: Vector2, pointer: int) -> Dictionary:
	var result: Dictionary = super.release(point, pointer)
	if result.get("valid", false) and result.get("mode", "") == "clear":
		combat.record_clear(result)
	return result

func finish_refill() -> void:
	if phase != "busy":
		return
	cancel()
	skill_mode = false
	# Enemy death precedes a scheduled third-action retaliation, while the
	# killing clear has already received all ordinary accounting in release.
	var outcome: String = combat.resolve()
	if outcome == "win":
		if combat.encounter < 2:
			reward_round = rewards_taken + 1
			reward_options = Relics.available(relics)
			offer_serial += 1
			phase = "reward"
		else:
			reward_options = []
			phase = "victory"
	elif outcome == "attack":
		hp = maxi(0, hp - combat.take_attack())
		phase = "enemy_attack"
	else:
		phase = "ready"

func finish_attack() -> void:
	if phase != "enemy_attack":
		return
	cancel()
	skill_mode = false
	if hp <= 0:
		phase = "defeat"
	else:
		combat.next_turn(panels)
		phase = "ready"

func choose_relic(id: String, serial: int) -> bool:
	if not super.choose_relic(id, serial):
		return false
	phase = "between"
	return true

func begin_next_fight(fresh_panels: Array, fresh_next_id: int) -> bool:
	if phase != "between" or combat.encounter >= 2:
		return false
	panels = fresh_panels.duplicate(true)
	next_id = fresh_next_id
	cancel()
	skill_mode = false
	combat.start_fight(combat.encounter + 1, panels)
	phase = "ready"
	return true

extends RefCounted
const Relics = preload("res://scripts/board_relics.gd")
const Rules = preload("res://scripts/board_rules.gd")
var panels: Array = []
var bounds := Rect2(30, 290, 660, 530)
var hp := 14
var max_hp := 30
var damage_total := 0
var actions := 0
var charge := 3
var charge_required := 3
var ash_reserved := false
var relics: Array = []
var reward_options: Array = []
var reward_round := 0
var rewards_taken := 0
var offer_serial := 0
var summary_shown := false
var stats: Array = [{"actions":0,"removed":0,"cores":0},{"actions":0,"removed":0,"cores":0},{"actions":0,"removed":0,"cores":0}]
var phase := "ready"
var selection: Dictionary = {}
var owner := -99
var skill_mode := false
var skill_color := 0
var next_id := 1

func begin(point: Vector2, pointer: int) -> bool:
	if phase != "ready" or owner != -99 or not bounds.has_point(point):
		return false
	var id := -1
	var nearest := INF
	for p in panels:
		var distance: float = point.distance_to(p.pos)
		if distance <= p.radius and distance < nearest:
			id = p.id
			nearest = distance
	if id < 0:
		return false
	owner = pointer
	if skill_mode and charge >= charge_required:
		selection = skill_plan_for(id, skill_color)
		selection["consume_ash"] = ash_reserved
		selection["recharge_required"] = 2 if ash_reserved else 3
		selection["mode"] = "skill"
	else:
		selection = plan_for(id)
		selection["mode"] = "clear"
	return true

func move(point: Vector2, pointer: int) -> void:
	if pointer == owner and not bounds.has_point(point):
		cancel()

func cancel() -> void:
	selection = {}
	owner = -99

func release(point: Vector2, pointer: int) -> Dictionary:
	if phase != "ready" or pointer != owner:
		return {}
	if not bounds.has_point(point) or selection.is_empty() or not selection.get("valid", false):
		cancel()
		return {}
	var result := selection.duplicate(true)
	cancel()
	if result.mode == "skill":
		for p in panels:
			if result.converted.has(p.id):
				p.color = result.converted[p.id]
		charge = 0
		charge_required = result.recharge_required
		if result.consume_ash: ash_reserved = false
		skill_mode = false
		return result
	phase = "busy"
	actions += 1
	charge = mini(charge + 1, charge_required)
	if result.ash_reserve: ash_reserved = true
	if actions <= 9:
		var stage: Dictionary = stats[(actions-1)/3]
		stage.actions += 1
		stage.removed += result.removed.size()
		if not result.spawn.is_empty(): stage.cores += 1
	damage_total += result.damage
	hp += result.heal_effective
	var survivors: Array = []
	for p in panels:
		if p.id not in result.removed:
			var survivor: Dictionary = p.duplicate(true)
			if result.converted.has(p.id):
				survivor.color = result.converted[p.id]
			survivors.append(survivor)
	if not result.spawn.is_empty():
		var p: Dictionary = result.spawn.duplicate(true)
		p.id = next_id
		next_id += 1
		p.radius = 37.0
		survivors.append(p)
	panels = survivors
	return result

func plan_for(id: int) -> Dictionary:
	return Rules.plan(panels, id, hp, max_hp, relics.duplicate())

func skill_plan_for(id: int, color: int) -> Dictionary:
	return Rules.skill_plan(panels, id, color, relics.duplicate())

func finish_refill() -> void:
	if phase != "busy": return
	cancel()
	skill_mode = false
	if (actions == 3 and rewards_taken == 0) or (actions == 6 and rewards_taken == 1):
		reward_round = rewards_taken + 1
		reward_options = Relics.available(relics)
		offer_serial += 1
		phase = "reward"
	elif actions == 9 and not summary_shown:
		summary_shown = true
		phase = "summary"
	else:
		phase = "ready"

func choose_relic(id: String, serial: int) -> bool:
	if phase != "reward" or serial != offer_serial or id not in reward_options or id in relics:
		return false
	relics.append(id)
	rewards_taken += 1
	reward_options = []
	cancel()
	phase = "ready"
	return true

func continue_summary() -> void:
	if phase == "summary":
		cancel()
		phase = "ready"

extends RefCounted
const Rules = preload("res://scripts/board_rules.gd")
var panels: Array = []
var bounds := Rect2(30, 290, 660, 530)
var hp := 14
var max_hp := 30
var damage_total := 0
var actions := 0
var charge := 3
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
	if skill_mode and charge >= 3:
		selection = Rules.skill_plan(panels, id, skill_color)
		selection["mode"] = "skill"
	else:
		selection = Rules.plan(panels, id, hp, max_hp)
		selection["mode"] = "clear"
	return true

func move(point: Vector2, pointer: int) -> void:
	if pointer == owner and not bounds.has_point(point):
		cancel()

func cancel() -> void:
	selection = {}
	owner = -99

func release(point: Vector2, pointer: int) -> Dictionary:
	if pointer != owner:
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
		skill_mode = false
		return result
	phase = "busy"
	actions += 1
	charge = mini(charge + 1, 3)
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

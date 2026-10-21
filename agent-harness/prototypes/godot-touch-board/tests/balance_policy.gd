extends RefCounted
## Shared pure selector for normal simulation and actual UI capture.
static func best_clear(s, policy: String) -> Dictionary:
	if s.combat.encounter != 2:
		return _early_best_clear(s)
	var best: Dictionary = {}
	var best_value := -INF
	var ordered: Array = s.panels.duplicate()
	ordered.sort_custom(func(a, b): return int(a.id) < int(b.id))
	for panel in ordered:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false): continue
		var lethal: bool = plan.damage >= s.combat.enemy_hp
		var active: bool = s.combat.mitigation_active and not s.combat.mitigation_success
		var qualifies: bool = plan.get("mitigates_intent",false)
		var value: float = plan.damage * 10000.0 + plan.normal_count
		if policy == "intent-aware":
			if lethal: value += 1000000000.0
			elif active and qualifies: value += 10000000.0
		elif policy == "avoid-intent" and active and not qualifies:
			value += 10000000000.0
		if value > best_value:
			best_value = value
			best = {"id":panel.id,"point":panel.pos,"plan":plan,"score":value}
	return best

static func _early_best_clear(s) -> Dictionary:
	var best: Dictionary = {}
	var best_value := -INF
	for panel in s.panels:
		var plan: Dictionary = s.plan_for(panel.id)
		if not plan.get("valid",false):
			continue
		# Prefer an immediate lethal clear over defensive progress. Otherwise
		# satisfy the active plan-based intent once, then maximize damage.
		var lethal: bool = plan.damage >= s.combat.enemy_hp
		var mitigates: bool = s.combat.mitigation_active and not s.combat.mitigation_success and plan.get("mitigates_intent",false)
		var value: float = plan.damage * 10.0 + plan.removed.size() + plan.heal_effective * (15.0 if s.hp <= 10 else 5.0)
		if lethal: value += 100000.0
		elif mitigates: value += 10000.0
		if value > best_value:
			best_value = value
			best = {"id":panel.id,"point":panel.pos,"plan":plan,"score":value}
	return best

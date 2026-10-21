extends RefCounted
const Bombs=preload("res://scripts/board_bombs.gd")
const SLAM_WEAK_REQUIRED := 2
const SLAM_NORMAL_REQUIRED := 8
## Pure, deterministic plans over a frozen contact snapshot. No animation or state mutation.

static func contact_graph(panels: Array, tolerance: float = 1.5) -> Dictionary:
	var graph: Dictionary = {}
	for panel in panels:
		graph[int(panel.id)] = []
	for i in range(panels.size()):
		for j in range(i + 1, panels.size()):
			var a: Dictionary = panels[i]
			var b: Dictionary = panels[j]
			var reach: float = float(a.radius) + float(b.radius) + maxf(0.0, tolerance)
			if a.pos.distance_squared_to(b.pos) <= reach * reach:
				graph[int(a.id)].append(int(b.id))
				graph[int(b.id)].append(int(a.id))
	for id in graph:
		graph[id].sort()
	return graph

static func _index(panels: Array) -> Dictionary:
	var out: Dictionary = {}
	for panel in panels:
		out[int(panel.id)] = panel
	return out

static func _distances(graph: Dictionary, start: int) -> Dictionary:
	if not graph.has(start):
		return {}
	var distance: Dictionary = {start: 0}
	var queue: Array = [start]
	var cursor := 0
	while cursor < queue.size():
		var id: int = queue[cursor]
		cursor += 1
		for neighbor in graph[id]:
			if not distance.has(neighbor):
				distance[neighbor] = int(distance[id]) + 1
				queue.append(neighbor)
	return distance

static func _ordered(ids: Array, distance: Dictionary) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a: int, b: int) -> bool:
		var da: int = distance.get(a, 2147483647)
		var db: int = distance.get(b, 2147483647)
		return a < b if da == db else da < db)
	return out

static func _special(panel: Dictionary) -> bool:
	return panel.kind == "core" or panel.kind == "strong" or Bombs.is_bomb(panel.kind)

static func _component(graph: Dictionary, indexed: Dictionary, colors: Dictionary, start: int) -> Array:
	var is_heart: bool = indexed[start].kind == "heart"
	var color: int = colors[start]
	var found: Dictionary = {start: true}
	var queue: Array = [start]
	var cursor := 0
	while cursor < queue.size():
		var id: int = queue[cursor]
		cursor += 1
		for neighbor in graph[id]:
			if found.has(neighbor):
				continue
			if (indexed[neighbor].kind == "heart") != is_heart:
				continue
			if int(colors[neighbor]) != color:
				continue
			found[neighbor] = true
			queue.append(neighbor)
	return queue

static func _empty_plan() -> Dictionary:
	return {"valid": false, "direct": [], "removed": [], "activated": [], "converted": {}, "damage": 0, "heal_raw": 0, "heal_effective": 0, "heal_overflow": 0, "spawn": {}, "sequence": [], "direct_normals": 0, "ash_reserve": false, "base_damage": 0, "weak_count": 0, "weak_bonus": 0, "normal_count": 0, "effective_colors": {}, "combat_context": {}, "mitigates_intent": false, "blasts":[], "bomb_spawn_kind":"", "bomb_spawn_color":-1}

static func plan(panels: Array, start_id: int, hp: int, max_hp: int, relics: Array = [], combat_context: Dictionary = {}) -> Dictionary:
	# Evaluate relic ownership once; the returned plan contains values, not live state.
	var has_lens := relics.has("lens")
	var has_ash := relics.has("ash")
	var result := _empty_plan()
	result.combat_context = combat_context.duplicate(true)
	var indexed := _index(panels)
	if not indexed.has(start_id) or indexed.size() != panels.size():
		return result
	var graph := contact_graph(panels)
	var distance := _distances(graph, start_id)
	var colors: Dictionary = {}
	for id in indexed:
		colors[id] = int(indexed[id].color)
	var direct := _ordered(_component(graph, indexed, colors, start_id), distance)
	if direct.size() < 2 and not _special(indexed[start_id]):
		return result
	result.valid = true
	result.direct = direct.duplicate()
	var removed: Dictionary = {}
	var pending: Dictionary = {}
	var activated: Dictionary = {}
	# Claim prevents later competing cores from recoloring the same snapshot panel.
	var claimed: Dictionary = {}
	var direct_normals := 0
	for id in direct:
		removed[id] = true
		if indexed[id].kind == "normal":
			direct_normals += 1
		if _special(indexed[id]):
			pending[id] = true
	while not pending.is_empty():
		var core_id: int = _ordered(pending.keys(), distance)[0]
		pending.erase(core_id)
		if activated.has(core_id):
			continue
		activated[core_id] = true
		removed[core_id] = true
		result.activated.append(core_id)
		if Bombs.is_bomb(indexed[core_id].kind):
			var blast_radius:float=Bombs.radius(indexed[core_id].kind)
			result.blasts.append({"id":core_id,"pos":indexed[core_id].pos,"radius":blast_radius,"kind":indexed[core_id].kind,"color":int(colors[core_id])})
			for id in _ordered(indexed.keys(),distance):
				if indexed[id].pos.distance_squared_to(indexed[core_id].pos)>blast_radius*blast_radius:continue
				removed[id]=true
				if _special(indexed[id]) and not activated.has(id):pending[id]=true
			continue
		if indexed[core_id].kind=="strong" and result.bomb_spawn_kind=="":
			result.bomb_spawn_kind="big_bomb" if has_lens else "bomb"
			# First activated strong core in the existing distance/ID order owns
			# the single supply. Size and attribute are independent snapshot data.
			result.bomb_spawn_color=int(colors[core_id])
		var radius := 2 if indexed[core_id].kind == "strong" else 1
		var core_distance := _distances(graph, core_id)
		var core_color: int = colors[core_id]
		for id in _ordered(core_distance.keys(), distance):
			if int(core_distance[id]) > radius:
				continue
			if _special(indexed[id]) and not activated.has(id):
				pending[id] = true
			elif indexed[id].kind == "normal" and not removed.has(id) and not claimed.has(id):
				claimed[id] = true
				if int(colors[id]) != core_color:
					colors[id] = core_color
					result.converted[id] = core_color
		# The graph remains the action-start graph: cleared positions remain anchors,
		# but removed panels can never be recolored or counted for damage a second time.
		for id in _component(graph, indexed, colors, core_id):
			removed[id] = true
			if _special(indexed[id]) and not activated.has(id):
				pending[id] = true
	result.removed = _ordered(removed.keys(), distance)
	result.sequence = result.removed.duplicate()
	# Only canonical, actually removed normals participate, using the color left
	# by all ordered core conversions. Aggregate once across the whole action.
	var weakness_color := int(result.combat_context.get("weakness_color", -1))
	for id in result.removed:
		if indexed[id].kind == "normal":
			result.damage += 1
			result.normal_count += 1
			result.effective_colors[id] = int(colors[id])
			if weakness_color >= 0 and weakness_color < 4 and int(colors[id]) == weakness_color:
				result.weak_count += 1
		elif indexed[id].kind == "heart":
			result.heal_raw += 2
	result.base_damage = result.damage
	result.weak_bonus = int(int(result.weak_count) / 2)
	result.damage = int(result.base_damage) + int(result.weak_bonus)
	var intent := String(result.combat_context.get("intent", "plain"))
	if intent == "slam":
		result.mitigates_intent = slam_mitigated(int(result.weak_count), int(result.normal_count), result.combat_context)
	elif intent == "direct4":
		# direct was constructed by a visited-set traversal; its IDs are unique.
		result.mitigates_intent = result.direct.size() >= 4
	result.heal_effective = mini(int(result.heal_raw), maxi(0, max_hp - hp))
	result.heal_overflow = int(result.heal_raw) - int(result.heal_effective)
	result.direct_normals = direct_normals
	result.ash_reserve = has_ash and direct_normals >= 6
	var core_threshold := 5 if has_lens else 6
	var strong_threshold := 11 if has_lens else 12
	if direct_normals >= core_threshold:
		result.spawn = {"pos": indexed[start_id].pos, "color": int(indexed[start_id].color), "kind": "strong" if direct_normals >= strong_threshold else "core"}
	return result

static func slam_mitigated(weak_count: int, normal_count: int, combat_context: Dictionary) -> bool:
	# The same frozen threshold decision serves preview, fairness, and commit.
	var weak_required := int(combat_context.get("slam_weak_required", SLAM_WEAK_REQUIRED))
	var normal_required := int(combat_context.get("slam_normal_required", SLAM_NORMAL_REQUIRED))
	return weak_count >= weak_required or normal_count >= normal_required

static func skill_plan(panels: Array, start_id: int, target_color: int, relics: Array = []) -> Dictionary:
	var target_limit := 5 if relics.has("pigment") else 4
	var result := {"valid": false, "targets": [], "converted": {}, "connected": []}
	var indexed := _index(panels)
	if not indexed.has(start_id) or indexed.size() != panels.size() or indexed[start_id].kind != "normal" or target_color < 0 or target_color > 3:
		return result
	var normals: Array = []
	var colors: Dictionary = {}
	for panel in panels:
		colors[int(panel.id)] = int(panel.color)
		if panel.kind == "normal":
			normals.append(panel)
	var normal_graph := contact_graph(normals)
	var distances := _distances(normal_graph, start_id)
	var targets := _ordered(distances.keys(), distances).slice(0, target_limit)
	result.valid = true
	result.targets = targets
	for id in targets:
		result.converted[id] = target_color
		colors[id] = target_color
	var graph := contact_graph(panels)
	result.connected = _ordered(_component(graph, indexed, colors, start_id), _distances(graph, start_id))
	return result

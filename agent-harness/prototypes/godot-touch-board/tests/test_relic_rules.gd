extends SceneTree
const Rules = preload("res://scripts/board_rules.gd")
var checks := 0
var failures := 0

func p(id: int, x: float, color: int = 0, kind: String = "normal") -> Dictionary:
	return {"id": id, "pos": Vector2(x, 0), "radius": 10.0, "color": color, "kind": kind}

func line(count: int, color: int = 0) -> Array:
	var panels: Array = []
	for id in range(count):
		panels.append(p(id, id * 20.0, color))
	return panels

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func _init() -> void:
	var board := line(6, 1)
	var before := board.duplicate(true)
	var base_skill := Rules.skill_plan(board, 2, 0)
	var pigment_skill := Rules.skill_plan(board, 2, 0, ["pigment"])
	check(base_skill.targets == [2, 1, 3, 0], "same fixed board base skill selects four")
	check(pigment_skill.targets == [2, 1, 3, 0, 4], "pigment selects five including origin distance then ID")
	check(pigment_skill.converted.size() == 5 and pigment_skill.connected == [2, 1, 3, 0, 4], "pigment preview conversion and result connection agree")
	check(Rules.skill_plan(board, 2, 0, ["pigment", "pigment"]).targets.size() == 5, "duplicate pigment does not stack")
	check(Rules.skill_plan(line(3, 1), 0, 0, ["pigment"]).targets.size() == 3, "pigment cannot invent missing targets")
	var blocked := line(7, 1)
	blocked[3].kind = "heart"
	blocked[3].color = 4
	check(Rules.skill_plan(blocked, 0, 0, ["pigment"]).targets == [0, 1, 2], "pigment paths cannot cross heart")
	blocked[3].kind = "core"
	blocked[3].color = 0
	check(Rules.skill_plan(blocked, 0, 0, ["pigment"]).targets == [0, 1, 2], "pigment paths cannot cross special")
	check(not Rules.skill_plan(blocked, 3, 0, ["pigment"]).valid, "pigment cannot target special")
	check(board == before, "skill relic planning does not mutate board")
	for count in [4, 5, 6, 10, 11, 12]:
		var base := Rules.plan(line(count), 0, 10, 20)
		var enhanced := Rules.plan(line(count), 0, 10, 20, ["lens", "ash"])
		var base_kind := "" if count < 6 else ("strong" if count >= 12 else "core")
		var lens_kind := "" if count < 5 else ("strong" if count >= 11 else "core")
		check(base.spawn.get("kind", "") == base_kind, "base threshold %d" % count)
		check(enhanced.spawn.get("kind", "") == lens_kind, "lens threshold %d" % count)
		check(enhanced.get("direct_normals", -1) == count, "direct normal count %d" % count)
		check(enhanced.get("ash_reserve", false) == (count >= 6), "ash independent six-normal threshold %d" % count)
		check(enhanced.activated.is_empty() and enhanced.removed.size() == count, "new special protected and only original IDs removed %d" % count)
		check(typeof(enhanced.spawn) == TYPE_DICTIONARY and enhanced.spawn.size() <= 3, "at most one spawn descriptor %d" % count)
	check(not Rules.plan(line(8), 0, 10, 20).get("ash_reserve", true), "no ash means no reserved charge")
	check(not Rules.plan(line(8), 0, 10, 20, ["lens"]).get("ash_reserve", true), "lens does not implicitly grant ash")
	var hearts := line(12, 4)
	for panel in hearts:
		panel.kind = "heart"
	var heart_plan := Rules.plan(hearts, 0, 10, 20, ["lens", "ash"])
	check(heart_plan.get("direct_normals", -1) == 0 and not heart_plan.get("ash_reserve", true) and heart_plan.spawn.is_empty(), "hearts neither produce lens core nor ash")
	var core_board := line(6)
	core_board[5].kind = "core"
	var core_plan := Rules.plan(core_board, 0, 10, 20, ["lens", "ash"])
	check(core_plan.get("direct_normals", -1) == 5 and core_plan.spawn.get("kind", "") == "core" and not core_plan.get("ash_reserve", true), "existing core excluded from direct count and ash")
	var chain_board := line(8)
	chain_board[4].kind = "core"
	chain_board[5].color = 1
	var chain := Rules.plan(chain_board, 0, 10, 20, ["lens", "ash"])
	check(chain.damage == 7 and chain.get("direct_normals", -1) == 4, "additional chain clears do not increase direct normals")
	check(not chain.get("ash_reserve", true) and chain.spawn.is_empty(), "additional chain cannot produce lens core or ash")
	var solo := Rules.plan([p(0, 0, 0, "strong")], 0, 10, 20, ["lens", "ash"])
	check(solo.valid and solo.get("direct_normals", -1) == 0 and not solo.get("ash_reserve", true), "solo special never reserves ash")
	var invalid := Rules.plan(line(1), 0, 10, 20, ["ash"])
	check(not invalid.valid and invalid.get("direct_normals", -1) == 0 and not invalid.get("ash_reserve", true), "invalid plan has safe new field defaults")
	var relics: Array = ["lens", "ash"]
	var frozen := Rules.plan(line(6), 0, 10, 20, relics)
	relics.clear()
	check(frozen.get("ash_reserve", false) and frozen.spawn.get("kind", "") == "core", "returned plan does not depend on later relic array mutation")
	var unknown := Rules.plan(line(5), 0, 10, 20, ["unknown"])
	check(unknown.spawn.is_empty() and not unknown.get("ash_reserve", true), "unknown relic IDs cannot modify rules")
	check(Rules.plan(board, 0, 10, 20, ["ash", "lens"]) == Rules.plan(board, 0, 10, 20, ["lens", "ash"]), "relic order does not affect result")
	check(board == before, "clear relic planning does not mutate board")
	var exists := FileAccess.file_exists("res://scripts/board_relics.gd")
	check(exists, "relic definitions file exists")
	if exists:
		var definitions = load("res://scripts/board_relics.gd")
		check(definitions.IDS == ["pigment", "lens", "ash", "petal"], "known relic IDs are stable")
		check(definitions.available(["lens"]) == ["pigment", "ash", "petal"], "available excludes owned relics")
		check(definitions.available(definitions.IDS).is_empty(), "all owned means none available")
		for id in definitions.IDS:
			check(definitions.DEFS[id].id == id and not definitions.DEFS[id].name.is_empty() and not definitions.DEFS[id].change.is_empty() and not definitions.DEFS[id].description.is_empty(), "complete UI definition %s" % id)
	print("RELIC RULES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

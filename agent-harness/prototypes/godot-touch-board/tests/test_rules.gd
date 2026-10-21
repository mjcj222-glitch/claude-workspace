extends SceneTree

const Rules = preload("res://scripts/board_rules.gd")
var checks := 0
var failures := 0

func p(id: int, x: float, y: float = 0.0, color: int = 0, kind: String = "normal") -> Dictionary:
	return {"id": id, "pos": Vector2(x, y), "radius": 10.0, "color": color, "kind": kind}

func line(count: int, color: int = 0) -> Array:
	var out: Array = []
	for id in range(count):
		out.append(p(id, id * 20.0, 0, color))
	return out

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)
	else:
		print("PASS: ", label)

func same(a: Array, b: Array) -> bool:
	return a == b

func _init() -> void:
	var panels := [p(0, 0), p(1, 20), p(2, 42), p(3, 0, 20)]
	var g := Rules.contact_graph(panels)
	check(g.get(0, []) == [1, 3], "contact graph uses physical distance and sorted IDs")
	check(not g.get(1, []).has(2), "visible gap larger than tolerance is not contact")
	check(Rules.contact_graph([p(0, 0), p(1, 21.5)]).get(0, []) == [1], "contact tolerance boundary is inclusive")
	check(not Rules.plan(line(1), 0, 10, 20).valid, "single normal is invalid")
	var two := Rules.plan(line(2), 0, 10, 20)
	check(two.valid and same(two.removed, [0, 1]) and two.damage == 2, "two connected normals clear for two damage")
	check(two.spawn.is_empty(), "two normals do not produce a core")
	check(not Rules.plan([p(0, 0), p(1, 22)], 0, 10, 20).valid, "future position cannot connect separated panels")
	check(not Rules.plan(line(3), 99, 10, 20).valid, "missing touched ID is invalid")
	for amount in [6, 11, 12, 14]:
		var result := Rules.plan(line(amount), 0, 10, 20)
		check(result.valid and result.spawn.get("kind") == ("core" if amount < 12 else "strong"), "%d direct normals produce correct special" % amount)
		check(result.spawn.get("pos") == Vector2.ZERO and result.spawn.get("color") == 0, "%d generated core retains initial touched position/color" % amount)
		check(result.activated.is_empty() and result.removed.size() == amount, "%d new core is protected from current action" % amount)
	var hearts := [p(0, 0, 0, 4, "heart"), p(1, 20, 0, 4, "heart"), p(2, 40, 0, 4, "heart")]
	var healing := Rules.plan(hearts, 0, 18, 20)
	check(healing.valid and healing.damage == 0 and healing.heal_raw == 6 and healing.heal_effective == 2 and healing.heal_overflow == 4, "hearts show raw effective and overflow capped healing")
	check(Rules.plan(hearts, 0, 20, 20).heal_effective == 0, "full HP receives no effective healing")
	check(not Rules.plan([hearts[0]], 0, 0, 20).valid, "single heart is invalid")
	var mixed := [p(0, 0), p(1, 20, 0, 4, "heart")]
	check(not Rules.plan(mixed, 0, 10, 20).valid, "heart does not join attack color")
	var solo := Rules.plan([p(0, 0, 0, 2, "core")], 0, 10, 20)
	check(solo.valid and solo.activated == [0] and solo.removed == [0] and solo.damage == 0, "solo core consumes valid action without normal damage")
	var blast := [p(0, 0, 0, 0, "core"), p(1, 20, 0, 1), p(2, 40), p(3, 60), p(4, 0, 20, 4, "heart")]
	var b := Rules.plan(blast, 0, 10, 20)
	check(b.converted.get(1) == 0 and b.removed == [0, 1, 2, 3] and b.damage == 3, "core converts radius one and follows same color beyond radius")
	check(not b.converted.has(4) and not b.removed.has(4) and b.heal_raw == 0, "core neither converts nor clears hearts")
	blast[0].kind = "strong"
	blast[2].color = 2
	var strong := Rules.plan(blast, 0, 10, 20)
	check(strong.converted.get(2) == 0 and strong.removed.has(3), "strong core converts graph radius two")
	blast[0].kind = "core"
	check(not Rules.plan(blast, 0, 10, 20).removed.has(2), "ordinary core cannot convert radius two")
	var chain := [p(0, 0, 0, 0, "core"), p(1, 20, 0, 1, "core"), p(2, 40, 0, 3), p(3, 60, 0, 1)]
	var c := Rules.plan(chain, 0, 10, 20)
	check(c.activated == [0, 1] and c.removed == [0, 1, 2, 3] and c.damage == 2, "different-color specials in radius activate and chain")
	check(c.activated.size() == 2 and c.removed.size() == 4 and c.spawn.is_empty(), "chain has no duplicates and cannot create another core")
	var six_with_core := line(6)
	six_with_core[5].kind = "core"
	check(Rules.plan(six_with_core, 0, 10, 20).spawn.is_empty(), "existing core does not count toward six direct normals")
	var six_and_blast := line(7)
	six_and_blast[5].kind = "core"
	six_and_blast[6].color = 1
	check(Rules.plan(six_and_blast, 0, 10, 20).spawn.is_empty(), "additional blast normal does not count toward generation")
	var snapshot := chain.duplicate(true)
	Rules.plan(chain, 0, 10, 20)
	check(chain == snapshot, "planning does not mutate snapshot input")
	var reverse := chain.duplicate(true)
	reverse.reverse()
	check(Rules.plan(reverse, 0, 10, 20) == c, "plan independent of input array order")
	var conflict := [p(0, 0, 0, 0, "strong"), p(1, 20, 0, 1, "core"), p(2, 10, 17, 2)]
	var cf := Rules.plan(conflict, 0, 10, 20)
	check(cf.converted.get(2) == 0 and cf.damage == 1 and cf.activated == [0, 1], "earlier conversion wins conflict and damage counts once")
	var diamond := [p(9, 0, 0, 0, "core"), p(3, 20, 0, 1, "core"), p(2, 0, 20, 2, "core"), p(1, 20, 20, 3)]
	check(Rules.plan(diamond, 9, 0, 20).activated == [9, 2, 3], "activation priority is start graph distance then ID")
	var skill := Rules.skill_plan(line(6, 1), 2, 0)
	check(skill.valid and skill.targets == [2, 1, 3, 0] and skill.converted.size() == 4, "skill selects at most four by graph distance then ID")
	check(skill.connected == [2, 1, 3, 0], "skill predicts resulting connected color")
	var blocked := [p(0, 0), p(1, 20, 0, 4, "heart"), p(2, 40, 0, 1), p(3, 60, 0, 2, "core"), p(4, 80, 0, 2)]
	check(Rules.skill_plan(blocked, 0, 1).targets == [0], "skill paths exclude hearts and cannot cross them")
	blocked[1].kind = "core"
	blocked[1].color = 2
	check(Rules.skill_plan(blocked, 0, 1).targets == [0], "skill paths exclude specials")
	check(not Rules.skill_plan(blocked, 1, 0).valid and not Rules.skill_plan(blocked, 99, 0).valid, "skill must target existing normal")
	check(not Rules.skill_plan(blocked, 0, 4).valid, "skill must select an attack color")
	var before_skill := blocked.duplicate(true)
	Rules.skill_plan(blocked, 0, 1)
	check(blocked == before_skill, "skill preview does not mutate snapshot")
	print("RULES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree
## Explicit deterministic boundary fixtures; NOT natural-run balance evidence.
const Rules = preload("res://scripts/board_rules.gd")
const Combat = preload("res://scripts/board_combat.gd")
const UI = preload("res://scripts/board_ui.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func board(count: int, color: int = 0, kind: String = "normal") -> Array:
	var result: Array = []
	for i in range(count): result.append({"id":i,"pos":Vector2(i*20,0),"radius":10.0,"color":color,"kind":kind})
	return result
func context() -> Dictionary:
	return {"intent":"slam","weakness_color":3,"incoming_damage":10,"mitigation_success":false,"slam_weak_required":2,"slam_normal_required":10}
func _init() -> void:
	for count in [1,2,3,4]:
		var panels := board(count+1,3)
		panels[0].kind = "core"
		var p: Dictionary = Rules.plan(panels,0,30,30,[],context())
		check(p.normal_count == count and p.weak_count == count and p.mitigates_intent == (count >= 2),"snapshot W%d boundary uses ordinary final colors and excludes core" % count)
		check(p.damage == count+int(count/2),"W%d weakness damage unchanged by boss condition" % count)
	for count in [8,9,10,11]:
		var p: Dictionary = Rules.plan(board(count,0),0,30,30,[],context())
		check(p.weak_count == 0 and p.mitigates_intent == (count >= 10),"snapshot normal%d boundary" % count)
	var copy := context()
	var frozen: Dictionary = Rules.plan(board(2,3),0,30,30,[],copy)
	copy.slam_weak_required = 4
	check(frozen.mitigates_intent and frozen.combat_context.slam_weak_required == 2,"held threshold remains a value snapshot")
	var c = Combat.new()
	var one_weak := board(2,3)
	one_weak[0].kind = "core"
	c.start_fight(2,one_weak)
	check(c.fallback_plain and c.intent == "plain" and c.incoming_damage == 6,"one weak normal and a core cannot offer slam")
	c.start_fight(2,board(2,3))
	check(c.enemy_hp == 48 and c.intent == "slam" and c.incoming_damage == 10,"weak pair retains approachable ten-to-four slam")
	check(c.damage_context().get("slam_weak_required",-1) == 2 and c.damage_context().get("slam_normal_required",-1) == 8,"combat snapshot publishes current exact thresholds")
	for i in range(2): c.record_clear(Rules.plan(one_weak,0,30,30,[],c.damage_context()))
	check(not c.mitigation_success and c.incoming_damage == 10,"separate one-weak core clears do not accumulate mitigation")
	c.record_clear(Rules.plan(board(2,3),0,30,30,[],c.damage_context()))
	c.settle_attack()
	check(c.mitigation_success and c.incoming_damage == 4 and c.take_attack() == 4,"third action can qualify and receive exactly four")
	c.start_fight(2,board(7))
	check(c.fallback_plain and c.incoming_damage == 6,"seven nonweak normals have ordinary-six fallback")
	c.start_fight(2,board(8))
	check(c.intent == "slam","eight nonweak normals retain fair alternate path")
	var last: Dictionary = Rules.plan(board(8),0,30,30,[],c.damage_context())
	c.enemy_hp = last.damage
	c.record_clear(last)
	c.record_clear(last);c.record_clear(last);c.settle_attack()
	check(c.mitigation_success and c.resolve() == "win" and c.take_attack() == 0,"qualifying killing action still wins before retaliation")
	check(UI.intent_lines(context()) == ["강타 10 → 4: 한 번에 약점 2개","또는 공격 패널 10개 소거"],"telegraph exposes both current boundaries")
	var altered := context()
	altered.slam_weak_required = 4
	altered.slam_normal_required = 11
	check(UI.intent_lines(altered) == ["강타 10 → 4: 한 번에 약점 4개","또는 공격 패널 11개 소거"],"telegraph reads immutable context rather than unrelated live constants")
	print("BALANCE_BOUNDARIES checks=",checks," failures=",failures)
	quit(1 if failures else 0)

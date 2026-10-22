extends SceneTree
const Combat = preload("res://scripts/board_combat.gd")
const Rules = preload("res://scripts/board_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func board(count: int, color: int = 0, kind: String = "normal") -> Array:
	var result: Array = []
	for i in range(count): result.append({"id":i,"pos":Vector2(i*20,0),"radius":10.0,"color":color,"kind":kind})
	return result
func plan(c, count: int, color: int = 0, kind: String = "normal") -> Dictionary:
	return Rules.plan(board(count,color,kind),0,0,30,[],c.damage_context())
func empty_clear() -> Dictionary:
	return {"valid":true,"mode":"clear","damage":0,"direct":[1,2],"weak_count":0,"normal_count":0}
func attack(c) -> int:
	while c.actions_in_turn < 3: c.record_clear(empty_clear())
	return c.take_attack()
func _init() -> void:
	var c = Combat.new()
	check(c.intent_serial == 0,"new object has no prepared intent serial")
	c.start_fight(0,board(2))
	check(c.weak_color == 0 and c.damage_context().get("weakness_color",-1) == 0,"first fight weakness is red")
	check(c.intent_serial == 1 and c.intent == "plain", "first prepared intent advances serial once")
	var serial: int = c.intent_serial
	var context: Dictionary = c.damage_context()
	context["weakness_color"] = 99
	check(c.damage_context().get("weakness_color",-1) == 0,"returned damage context cannot mutate combat")
	c.prepare_turn(board(8,3))
	check(c.intent_serial == serial,"repeated prepare never changes frozen intent")
	c.start_fight(1,board(4),"safe")
	check(c.weak_color == 1 and c.intent == "direct4" and c.incoming_damage == 7,"safe second fight keeps direct-four intent and green weakness")
	c.start_fight(1,board(4),"elite")
	check(c.weak_color == 2 and c.incoming_damage == 8,"elite second fight yellow weakness preserves attack bonus")
	c.start_fight(2,board(2,3),"elite")
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	check(c.enemy_hp == 48 and c.weak_color == 3 and c.intent == "slam" and c.incoming_damage == 10 and c.mitigation_active,"boss available blue pair announces ten-to-four slam")
	check("10" in c.telegraph_text() and "4" in c.telegraph_text(),"slam telegraph exposes actual damage alternatives")
	var visible: Dictionary = plan(c,2,3)
	check(visible.get("mitigates_intent",false),"same canonical rule plan previews available mitigation")
	check(not c.mitigation_success and c.actions_in_turn == 0,"preview alone never latches mitigation")
	c.record_clear(visible)
	check(c.mitigation_success and c.incoming_damage == 4 and c.enemy_hp == 45,"two weak normals latch once and apply three total damage")
	check(attack(c) == 4 and c.take_attack() == 0,"successful boss mitigation attacks exactly once")
	serial = c.intent_serial
	c.next_turn(board(8,3))
	check(c.turn == 1 and c.intent == "plain" and c.incoming_damage == 6 and not c.mitigation_active and c.intent_serial == serial+1,"odd boss turn always plain six and advances context")
	check(attack(c) == 6,"odd boss attack is six not old eight")
	c.next_turn(board(7,0))
	check(c.turn == 2 and c.fallback_plain and c.intent == "plain" and c.incoming_damage == 6,"seven nonweak normals cannot enable slam")
	serial = c.intent_serial
	c.prepare_turn(board(10,0))
	c.record_clear(plan(c,10,0))
	check(c.fallback_plain and not c.mitigation_success and c.incoming_damage == 6 and c.intent_serial == serial,"later board growth cannot activate fallback turn condition")
	check(attack(c) == 6,"fallback turn remains plain six")
	c.start_fight(2,board(8,0))
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	check(c.intent == "slam" and c.incoming_damage == 10,"eight nonweak ordinary normals are an independent slam opportunity")
	c.record_clear(plan(c,7,0))
	check(not c.mitigation_success,"seven actual removed normals do not satisfy eight threshold")
	c.record_clear(plan(c,2,0))
	check(not c.mitigation_success,"normal counts from separate actions never accumulate")
	c.record_clear(plan(c,10,0))
	check(c.mitigation_success and c.incoming_damage == 4 and c.resolve() == "attack","third action may satisfy slam before retaliation")
	check(c.take_attack() == 4,"third-action mitigation uses reduced damage")
	for kind in ["heart","core"]:
		c.start_fight(2,board(10,3,kind))
		c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
		check(c.fallback_plain and c.incoming_damage == 6,"heart/core bodies never count as ordinary boss opportunities")
	var single: Array = board(2,3)
	single[0].kind = "core"
	c.start_fight(2,single)
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	check(c.fallback_plain,"one weak normal plus a core is still below weak threshold")
	c.start_fight(2,board(2,3))
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	var one: Dictionary = Rules.plan(single,0,0,30,[],c.damage_context())
	c.record_clear(one);c.record_clear(one)
	check(not c.mitigation_success,"two separate one-weak clears do not accumulate")
	check(attack(c) == 10,"unmet scheduled slam remains ten")
	c.start_fight(2,board(2,3))
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	c.prepare_turn(board(1,0))
	check(c.mitigation_active and c.incoming_damage == 10,"initial legal opportunity remains frozen if later board loses it")
	var skill: Dictionary = plan(c,2,3)
	skill["mode"] = "skill"
	c.record_clear(skill)
	c.record_clear({"valid":false,"damage":99,"weak_count":3,"normal_count":10})
	check(not c.mitigation_success and c.actions_in_turn == 0 and c.enemy_hp == 48,"skill and invalid plans never damage or mitigate")
	c.record_clear(empty_clear());c.record_clear(empty_clear())
	c.enemy_hp = 3
	c.record_clear(plan(c,2,3))
	check(c.resolve() == "win" and c.take_attack() == 0 and c.mitigation_success,"third clear can kill and mitigate without retaliation")
	var wins: int = c.enemies_defeated
	c.resolve()
	check(c.enemies_defeated == wins,"boss win counts once")
	# The eligibility query and committed calculation both include ordinary
	# panels reached through an existing core, beyond its direct group.
	var normal_chain: Array = board(11,0)
	normal_chain[0].kind = "core"
	normal_chain[1].color = 1
	c.start_fight(2,normal_chain)
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	var chain_plan: Dictionary = Rules.plan(normal_chain,0,0,30,[],c.damage_context())
	check(chain_plan.direct.size() == 1 and chain_plan.normal_count == 10 and c.intent == "slam", "solo core reaching ten ordinary panels enables slam fairly")
	c.record_clear(chain_plan)
	check(c.mitigation_success and c.incoming_damage == 4, "full chain ordinary count satisfies slam on one action")
	var weak_chain: Array = board(4,0)
	weak_chain[0].kind = "strong"
	weak_chain[0].color = 3
	weak_chain[3].color = 3
	c.start_fight(2,weak_chain)
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	chain_plan = Rules.plan(weak_chain,0,0,30,[],c.damage_context())
	check(chain_plan.weak_count == 3 and chain_plan.normal_count == 3 and c.intent == "slam", "final converted weak colors make canonical chain eligible")
	c.record_clear(chain_plan)
	check(c.mitigation_success, "converted weak chain commits same advertised opportunity")
	var skill_only: Array = board(2,0)
	skill_only[1].color = 3
	c.start_fight(2,skill_only)
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	check(c.fallback_plain and c.intent == "plain", "future skill conversion is not a current legal slam opportunity")
	# A held plan owns its exact thresholds, not a later/default recomputation.
	c.start_fight(2,board(3,3))
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	var held_context: Dictionary = c.damage_context()
	held_context.slam_weak_required=4
	held_context.slam_normal_required=11
	var held: Dictionary = Rules.plan(board(3,3),0,0,30,[],held_context)
	held_context.slam_weak_required=2
	c.record_clear(held)
	check(not held.mitigates_intent and not c.mitigation_success and c.incoming_damage==10, "commit uses held threshold four instead of default two")
	c.start_fight(2,board(3,3))
	c.shield_hp=0 # Isolate legacy intent contract; separate prism suite covers shield.
	held_context=c.damage_context()
	held_context.slam_weak_required=2
	held=Rules.plan(board(2,3),0,0,30,[],held_context)
	c.record_clear(held)
	check(held.mitigates_intent and c.mitigation_success and c.incoming_damage==4, "commit honors frozen qualifying threshold instead of live default")
	var reset = Combat.new()
	check(reset.intent_serial == 0 and reset.attacks_total == 0,"new combat resets serial and cumulative attacks")
	print("BOSS_COMBAT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

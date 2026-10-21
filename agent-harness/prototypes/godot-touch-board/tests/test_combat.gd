extends SceneTree
const Combat = preload("res://scripts/board_combat.gd")
const Rules = preload("res://scripts/board_rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func board(count: int, kind: String = "normal") -> Array:
	var result: Array = []
	for i in range(count):
		result.append({"id":i,"pos":Vector2(20*i,0),"radius":10.0,"color":4 if kind=="heart" else 0,"kind":kind})
	return result

func clear_plan(damage: int = 0, direct: Array = [0,1]) -> Dictionary:
	return {"valid":true,"damage":damage,"direct":direct,"removed":direct.duplicate(),"mode":"clear"}

func complete_turn(combat, plan: Dictionary = {}) -> int:
	for i in range(3): combat.record_clear(clear_plan() if plan.is_empty() else plan)
	return combat.take_attack()

func _init() -> void:
	var c = Combat.new()
	c.start_fight(0,board(4))
	check(c.enemy_hp==24 and c.enemy_max_hp==24 and c.turn==0 and c.actions_in_turn==0, "first fight starts at 24 HP and zero-based turn")
	check(c.incoming_damage==4 and not c.mitigation_active and not c.fallback_plain, "first fight announces plain four damage")
	check(c.take_attack()==0 and c.attacks_total==0, "no attack before third clear")
	c.record_clear(clear_plan(3))
	check(c.enemy_hp==21 and c.actions_in_turn==1 and c.resolve()=="ready", "first clear damages enemy and keeps board ready")
	c.record_clear(clear_plan(2))
	check(c.resolve()=="ready" and c.take_attack()==0, "second clear never attacks")
	c.record_clear(clear_plan(1))
	check(c.enemy_hp==18 and c.actions_in_turn==3 and c.resolve()=="attack", "third surviving clear requests attack")
	check(c.take_attack()==4 and c.last_attack_damage==4 and c.attacks_total==1, "announced attack resolves exactly once")
	check(c.take_attack()==0 and c.attacks_total==1, "duplicate attack grants no second hit")
	c.next_turn(board(2))
	check(c.turn==1 and c.actions_in_turn==0 and c.incoming_damage==4 and c.enemy_hp==18, "next turn resets actions while preserving enemy damage")
	check(complete_turn(c)==4 and c.attacks_total==2, "next turn allows exactly one new attack")
	c.start_fight(0,board(2))
	c.record_clear(clear_plan(40))
	check(c.enemy_hp==0 and c.actions_in_turn==1 and c.resolve()=="win", "lethal first clear wins without waiting for third")
	var wins: int = c.enemies_defeated
	check(c.resolve()=="win" and c.enemies_defeated==wins and wins==1, "repeated win resolution increments victory count once")
	check(c.take_attack()==0, "dead enemy cannot retaliate")
	c.start_fight(0,board(2))
	c.record_clear(clear_plan(8))
	c.record_clear(clear_plan(8))
	c.record_clear(clear_plan(8))
	check(c.resolve()=="win" and c.take_attack()==0 and c.enemies_defeated==2, "lethal third clear prioritizes victory over attack")

	c.start_fight(1,board(4))
	check(c.enemy_hp==36 and c.enemy_max_hp==36 and c.actions_in_turn==0 and c.turn==0, "second fight resets local enemy and turn state")
	check(c.mitigation_active and not c.fallback_plain and c.incoming_damage==7, "second fight even turn with available four-link announces mitigation")
	check(c.telegraph_text()=="4개 이상 연결을 한 번 지우면 공격 7 → 3", "mitigation telegraph uses exact approved copy")
	c.record_clear(clear_plan(0,[0,1,2,3]))
	check(c.mitigation_success and c.incoming_damage==3, "actual four-direct clear latches mitigation success")
	check("3" in c.telegraph_text() and "성공" in c.telegraph_text(), "successful condition visibly announces three incoming damage")
	c.record_clear(clear_plan())
	c.record_clear(clear_plan())
	check(c.take_attack()==3, "successful mitigation deals three")
	c.next_turn(board(4))
	check(c.turn==1 and c.incoming_damage==5 and not c.mitigation_active and not c.mitigation_success, "second fight odd turn always plain five")
	check(complete_turn(c)==5, "second fight odd attack remains five despite available link")
	c.next_turn(board(4))
	check(c.turn==2 and c.mitigation_active and c.incoming_damage==7, "next even turn independently prepares condition")
	check(complete_turn(c)==7, "failed mitigation deals announced seven")

	c.start_fight(1,board(2))
	check(c.fallback_plain and not c.mitigation_active and c.incoming_damage==5, "no qualifying initial group locks fallback plain five")
	check("5" in c.telegraph_text() and "4개" not in c.telegraph_text() and "7" not in c.telegraph_text(), "fallback shows plain attack without unavailable condition")
	c.prepare_turn(board(6))
	check(c.fallback_plain and not c.mitigation_active and c.incoming_damage==5, "repeated preparation cannot add condition after initial snapshot")
	c.record_clear(clear_plan(0,[0,1,2,3,4,5]))
	check(not c.mitigation_success and c.incoming_damage==5, "later big clear cannot introduce condition on fallback turn")
	c.record_clear(clear_plan())
	c.record_clear(clear_plan())
	check(c.take_attack()==5, "fallback whole turn remains five")

	var hearts := board(4,"heart")
	c.start_fight(1,hearts)
	check(c.mitigation_active, "four connected hearts qualify for available mitigation")
	c.record_clear(Rules.plan(hearts,0,10,20))
	check(c.mitigation_success and c.incoming_damage==3 and c.enemy_hp==36, "actual heart four-link satisfies condition without attack damage")
	var core_group := board(4)
	core_group[1].kind="core"
	c.start_fight(1,core_group)
	c.record_clear(Rules.plan(core_group,0,10,20))
	check(c.mitigation_success and c.incoming_damage==3, "same-color direct group including core qualifies")
	var solo := board(5)
	solo[0].kind="core"
	solo[1].color=1
	var solo_plan: Dictionary=Rules.plan(solo,0,10,20)
	check(solo_plan.direct.size()==1 and solo_plan.removed.size()==5, "solo special fixture has chain extras but only one direct")
	c.start_fight(1,board(4))
	c.record_clear(solo_plan)
	check(not c.mitigation_success and c.incoming_damage==7, "solo special chain extras never satisfy direct four condition")
	c.record_clear(clear_plan(0,[1,1,2,2]))
	check(not c.mitigation_success, "duplicate direct IDs do not fabricate four-link")

	c.start_fight(2,board(4))
	check(c.enemy_hp==48 and c.enemy_max_hp==48 and c.turn==0 and c.incoming_damage==6 and not c.mitigation_active, "third fight starts six and clears previous mitigation state")
	check(complete_turn(c)==6, "third fight first attack six")
	c.next_turn(board(4))
	check(c.incoming_damage==8 and complete_turn(c)==8, "third fight second attack eight")
	c.next_turn(board(4))
	check(c.incoming_damage==6 and complete_turn(c)==6, "third fight alternates back to six")
	c.start_fight(2,board(4))
	var before_actions: int=c.actions_in_turn
	var before_hp: int=c.enemy_hp
	c.record_clear({"valid":false,"damage":999,"direct":[0,1,2,3]})
	c.record_clear({"valid":true,"mode":"skill","damage":999,"direct":[0,1,2,3]})
	check(c.actions_in_turn==before_actions and c.enemy_hp==before_hp, "invalid and skill plans cannot consume combat actions")
	check(c.resolve()=="ready" and c.actions_in_turn==0, "invalid and skill plans are ignored on an input-ready turn")
	c.next_turn(board(4))
	check(c.turn==0 and c.actions_in_turn==0, "next_turn before attack cannot skip a turn")
	complete_turn(c)
	c.next_turn(board(4))
	c.next_turn(board(4))
	check(c.turn==1 and c.incoming_damage==8, "duplicate next_turn after one attack cannot skip alternation")
	print("COMBAT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

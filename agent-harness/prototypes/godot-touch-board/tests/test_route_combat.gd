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
	var panels: Array = []
	for id in range(count):
		panels.append({"id":id,"pos":Vector2(20*id,0),"radius":10.0,"color":4 if kind=="heart" else 0,"kind":kind})
	return panels

func clear_plan(damage: int = 0, ids: Array = [0,1]) -> Dictionary:
	return {"valid":true,"mode":"clear","damage":damage,"direct":ids,"removed":ids.duplicate()}

func finish_turn(combat) -> int:
	while combat.actions_in_turn < 3:
		combat.record_clear(clear_plan())
	combat.settle_attack()
	return combat.take_attack()

func _init() -> void:
	var c = Combat.new()
	var metadata: Dictionary=c.get_script().get_script_constant_map().get("ROUTES",{})
	check(metadata.get("safe",{})=={"name":"안전한 길","hp":36,"gold":4,"pattern":"경감 7→3 · 일반 5"}, "safe route metadata exact")
	check(metadata.get("elite",{})=={"name":"정예의 길","hp":44,"gold":8,"pattern":"경감 8→4 · 일반 6"}, "elite route metadata exact")
	c.start_fight(1,board(4))
	check(c.get("route")=="safe" and c.enemy_hp==36 and c.incoming_damage==7, "old call defaults safe unchanged")
	c.start_fight(1,board(4),"elite")
	check(c.get("route")=="elite" and c.enemy_hp==44 and c.enemy_max_hp==44, "elite second enemy starts at44 HP")
	check(c.turn==0 and c.mitigation_active and c.incoming_damage==8, "elite condition available announces8")
	check(c.telegraph_text()=="4개 이상 연결을 한 번 지우면 공격 8 → 4", "elite mitigation telegraph exact dynamic numbers")
	c.record_clear(clear_plan(0,[0,1,2,3]))
	check(c.mitigation_success and c.incoming_damage==4, "elite direct four succeeds at4 incoming")
	check(c.telegraph_text()=="조건 성공 · 다음 공격 4", "elite success telegraph shows actual4")
	check(finish_turn(c)==4 and c.last_attack_damage==4, "elite success deals4 once")
	var total: int=c.attacks_total
	check(c.take_attack()==0 and c.attacks_total==total, "elite repeated attack causes no duplicate")
	c.next_turn(board(4))
	check(c.turn==1 and not c.mitigation_active and c.incoming_damage==6, "elite odd turn plain6")
	check(finish_turn(c)==6, "elite odd turn deals6")
	c.next_turn(board(4))
	check(c.turn==2 and c.mitigation_active and c.incoming_damage==8, "elite next even turn restores8 condition")
	check(finish_turn(c)==8, "elite failed condition deals8")
	c.start_fight(1,board(2),"elite")
	check(c.fallback_plain and not c.mitigation_active and c.incoming_damage==6, "elite unavailable condition falls back6")
	check(c.telegraph_text()=="3회 소거 후 공격 6", "elite fallback has no condition text")
	c.prepare_turn(board(6))
	c.record_clear(clear_plan(0,[0,1,2,3,4,5]))
	check(c.incoming_damage==6 and not c.mitigation_success, "elite fallback locked despite later group")
	check(finish_turn(c)==6, "elite fallback actual attack6")
	for kind in ["heart","core"]:
		var panels:=board(4,kind)
		c.start_fight(1,panels,"elite")
		check(c.mitigation_active and c.incoming_damage==8, "%s direct group qualifies for initial condition" % kind)
		c.record_clear(Rules.plan(panels,0,10,20))
		check(c.mitigation_success and c.incoming_damage==4, "%s unique direct group satisfies elite mitigation" % kind)
	c.start_fight(1,board(4),"elite")
	c.record_clear(clear_plan(0,[0,0,1,1]))
	check(not c.mitigation_success and c.incoming_damage==8, "duplicate direct IDs cannot satisfy elite condition")
	var solo:=board(5)
	solo[0].kind="core"
	solo[1].color=1
	c.record_clear(Rules.plan(solo,0,10,20))
	check(not c.mitigation_success and c.incoming_damage==8, "solo-core extra chain excluded from elite condition")
	c.start_fight(1,board(4),"elite")
	c.record_clear(clear_plan(44))
	check(c.enemy_hp==44 and c.resolve()=="ready","lethal contribution remains banked")
	c.record_clear(clear_plan());c.record_clear(clear_plan());c.settle_attack()
	check(c.enemy_hp==0 and c.resolve()=="win" and c.take_attack()==0, "elite lethal bank beats retaliation after third clear")
	var wins: int=c.enemies_defeated
	check(c.resolve()=="win" and c.enemies_defeated==wins, "elite repeated victory counts once")
	c.start_fight(1,board(4),"elite")
	c.record_clear(clear_plan(20))
	c.record_clear(clear_plan(20))
	c.record_clear(clear_plan(4))
	c.settle_attack()
	check(c.resolve()=="win" and c.take_attack()==0, "elite lethal third clear beats retaliation")
	c.start_fight(0,board(4),"elite")
	check(c.enemy_hp==24 and c.incoming_damage==4 and finish_turn(c)==4, "first fight unaffected by elite route")
	c.start_fight(2,board(4),"elite")
	check(c.enemy_hp==48 and c.incoming_damage==6 and finish_turn(c)==6, "final fight first attack unaffected by elite")
	c.next_turn(board(4))
	check(c.incoming_damage==6 and finish_turn(c)==6, "boss odd plain six unaffected by elite")
	c.start_fight(1,board(4),"safe")
	check(c.enemy_hp==36 and c.incoming_damage==7 and c.telegraph_text()=="4개 이상 연결을 한 번 지우면 공격 7 → 3", "explicit safe resets elite bonuses")
	c.record_clear(clear_plan(0,[0,1,2,3]))
	check(c.incoming_damage==3 and finish_turn(c)==3, "explicit safe mitigation still3")
	print("ROUTE COMBAT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
const Run = preload("res://scripts/board_run_session.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String)->void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func board(count: int = 2,color: int = 0)->Array:
	var result: Array = []
	for i in range(count): result.append({"id":i+1,"pos":Vector2(90+i*74,650),"radius":37.0,"color":color,"kind":"normal"})
	return result
func fresh():
	var s = Run.new()
	s.initialize_board(board(),100)
	return s
func _init()->void:
	var s = fresh()
	var p: Dictionary = s.plan_for(1)
	check(p.get("weak_count",-1) == 2 and p.get("base_damage",-1) == 2 and p.get("weak_bonus",-1) == 1 and p.damage == 3,"run clear preview passes enemy weakness into canonical rules")
	check(p.get("combat_context",{}).get("intent_serial",-1) == s.combat.intent_serial,"clear plan carries frozen intent serial")
	s.begin(Vector2(90,650),0)
	var visible: Dictionary = s.selection.duplicate(true)
	s.combat.weak_color = 1
	var executed: Dictionary = s.release(Vector2(90,650),0)
	check(executed == visible and s.damage_total == 3 and s.combat.enemy_hp == 21,"release executes exact snapshot despite live weakness mutation")
	check(s.actions == 1 and s.charge == 3,"weak bonus never duplicates action or charge")
	s = fresh()
	s.skill_mode = true;s.skill_color = 1
	s.begin(Vector2(90,650),0)
	visible = s.selection.duplicate(true)
	check(visible.get("mode","") == "skill" and visible.get("combat_context",{}).get("weakness_color",-1) == 0,"virtual skill hook attaches current combat context")
	s.combat.weak_color = 2
	executed = s.release(Vector2(90,650),0)
	check(executed == visible and s.actions == 0 and s.combat.actions_in_turn == 0 and s.combat.enemy_hp == 24 and s.damage_total == 0,"skill snapshot stays free and causes no damage")
	check(s.charge == 0 and s.phase == "ready" and not s.combat.mitigation_success,"skill consumes charge without mitigating")
	s = fresh()
	s.panels = board(2,3)
	s.combat.start_fight(2,s.panels)
	s.begin(Vector2(90,650),0)
	check(s.selection.get("mitigates_intent",false) and not s.combat.mitigation_success,"boss preview forecasts mitigation without committing")
	s.cancel();s.release(Vector2(90,650),0)
	check(s.actions == 0 and not s.combat.mitigation_success and s.combat.enemy_hp == 48,"cancelled boss preview has no effect")
	var serial: int = s.combat.intent_serial
	s.begin(Vector2(90,650),0);s.release(Vector2(90,650),0)
	check(s.combat.mitigation_success and s.combat.incoming_damage == 4 and s.combat.intent_serial == serial,"valid boss clear latches frozen intent")
	s.finish_refill()
	check(s.phase == "ready" and s.combat.intent_serial == serial,"mid-turn refill does not advance intent")
	for i in range(2):
		s.panels = board(2,0)
		s.begin(Vector2(90,650),0);s.release(Vector2(90,650),0);s.finish_refill()
	check(s.phase == "enemy_attack" and s.hp == 26 and s.combat.intent_serial == serial,"third clear applies reduced attack before intent advances")
	s.finish_attack()
	check(s.phase == "ready" and s.combat.intent_serial == serial+1 and s.combat.intent == "plain" and s.combat.incoming_damage == 6,"only settled attack completion advances boss intent")
	# Explicit low-enemy-HP unit fixtures isolate carry and context replacement.
	s = fresh()
	s.combat.enemy_hp = 3
	s.begin(Vector2(90,650),0);s.release(Vector2(90,650),0);s.finish_refill()
	s.choose_relic("pigment",s.offer_serial);s.choose_route("elite")
	s.hp = 17;s.charge = 1;s.charge_required = 2;s.ash_reserved = true
	check(s.begin_next_fight(board(2,2),100) and s.combat.weak_color == 2 and s.combat.intent_serial == 2, "next elite fight replaces weakness and advances intent snapshot")
	check(s.hp == 17 and s.charge == 1 and s.charge_required == 2 and s.ash_reserved and s.gold == 4, "new elemental context leaves all carried resources intact")
	s.combat.enemy_hp = 3
	s.begin(Vector2(90,650),0);s.release(Vector2(90,650),0);s.finish_refill()
	s.choose_relic("lens",s.offer_serial);s.leave_shop()
	check(s.begin_next_fight(board(2,3),200) and s.combat.weak_color == 3 and s.combat.intent_serial == 3 and s.combat.intent == "slam", "final fight prepares fresh fair boss intent from supplied board")
	check(s.gold == 12 and s.hp == 17 and s.relics == ["pigment","lens"] and s.ash_reserved, "boss transition preserves route payout and relic state")
	var restarted = fresh()
	check(restarted.combat.intent_serial == 1 and restarted.combat.weak_color == 0 and restarted.hp == 30 and restarted.actions == 0,"new run resets intent and weakness to first encounter")
	print("ELEMENTAL_SESSION checks=",checks," failures=",failures)
	quit(1 if failures else 0)

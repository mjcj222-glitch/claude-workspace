extends SceneTree
const Run = preload("res://scripts/board_run_session.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func board(count: int = 2, kind: String = "normal", first_id: int = 1) -> Array:
	var result: Array = []
	for i in range(count):
		result.append({"id":first_id+i,"pos":Vector2(90+(i%7)*74,400+(i/7)*74),"radius":37.0,"kind":kind,"color":4 if kind == "heart" else 0})
	return result
func make_run():
	var result = Run.new()
	result.initialize_board(board(),100)
	return result
func clear_fixture(s, panels: Array) -> Dictionary:
	s.panels = panels.duplicate(true)
	var p: Vector2 = panels[0].pos
	if not s.begin(p,0): return {}
	return s.release(p,0)
func _init() -> void:
	var s = make_run()
	check(s.hp == 30 and s.max_hp == 30 and s.charge == 3 and s.charge_required == 3 and s.relics.is_empty(), "fresh run starts full and skill ready")
	check(s.phase == "ready" and s.panels.size() == 2 and s.next_id == 100 and s.combat.encounter == 0, "initialize installs first board and fight")
	var initial_hp: int = s.hp
	s.finish_refill();s.finish_attack()
	check(s.hp == initial_hp and s.phase == "ready", "completion calls outside matching phases are inert")
	check(not s.begin_next_fight(board(),200), "cannot skip living encounter")
	# Unit kill fixture: rules calculate a real connected six, even though enemy
	# HP is explicitly reduced here to isolate kill accounting from turn length.
	s.relics = ["ash"]
	s.charge = 0
	s.combat.enemy_hp = 6
	var plan: Dictionary = clear_fixture(s,board(6))
	check(not plan.is_empty() and s.actions == 1 and s.charge == 1 and s.ash_reserved, "killing clear still charges and reserves ash")
	check(s.combat.enemy_hp == 0 and s.phase == "busy", "damage is recorded on commit before refill")
	s.finish_refill()
	check(s.phase == "reward" and s.combat.attacks_total == 0 and s.hp == 30, "first-action kill grants reward without retaliation")
	var serial: int = s.offer_serial
	s.finish_refill();s.finish_attack()
	check(s.offer_serial == serial and s.rewards_taken == 0, "repeated completion cannot duplicate reward")
	check(not s.choose_relic("pigment",serial+1), "stale reward serial rejected")
	check(s.choose_relic("pigment",serial) and s.phase == "between", "chosen reward moves to between phase")
	check(not s.choose_relic("lens",serial), "reward can only be claimed once")
	var fresh: Array = board(2,"normal",201)
	s.hp = 17
	s.charge_required = 2
	check(s.begin_next_fight(fresh,203), "between advances to a newly supplied board")
	check(s.combat.encounter == 1 and s.panels[0].id == 201 and s.next_id == 203, "next fight uses new board and index")
	check(s.hp == 17 and s.charge == 1 and s.charge_required == 2 and s.ash_reserved and s.relics == ["ash","pigment"], "hp charge requirement ash and relics carry unchanged")
	fresh[0].color = 3
	check(s.panels[0].color == 0, "incoming board ownership is isolated")
	# Third clear kill has priority over a scheduled attack.
	s = make_run()
	s.combat.enemy_hp = 6
	for i in range(3):
		clear_fixture(s,board(2))
		s.finish_refill()
	check(s.actions == 3 and s.phase == "reward" and s.hp == 30 and s.combat.attacks_total == 0, "third-action kill wins before enemy attack")
	# Heart/solo-core clears are valid actions, unlike skill and cancellation.
	s = make_run()
	s.hp = 20
	clear_fixture(s,board(2,"heart"));s.finish_refill()
	check(s.hp == 24 and s.actions == 1 and s.combat.actions_in_turn == 1 and s.combat.enemy_hp == s.combat.enemy_max_hp, "heart clear heals and consumes one turn action")
	clear_fixture(s,board(1,"core"));s.finish_refill()
	check(s.actions == 2 and s.combat.actions_in_turn == 2, "solo core is one valid turn action")
	clear_fixture(s,board(2));s.finish_refill()
	check(s.phase == "enemy_attack" and s.hp == 20 and s.combat.attacks_total == 1, "third surviving clear applies enemy damage once")
	var attacked_hp: int = s.hp
	s.finish_refill()
	check(s.hp == attacked_hp and s.combat.attacks_total == 1, "repeated refill cannot repeat attack")
	s.finish_attack()
	check(s.phase == "ready" and s.combat.actions_in_turn == 0 and s.combat.turn == 1 and s.reward_options.is_empty(), "attack completion starts next turn without old three-action reward")
	s.finish_attack()
	check(s.combat.turn == 1, "attack completion is exact-once")
	# Ash changes only the next skill recharge requirement, never turn count.
	s = make_run()
	s.relics = ["ash"]
	s.ash_reserved = true
	s.skill_mode = true
	s.skill_color = 1
	plan = clear_fixture(s,board(2))
	check(plan.get("mode","") == "skill" and s.charge == 0 and s.charge_required == 2 and not s.ash_reserved, "reserved ash consumes on skill and sets two-clear recharge")
	check(s.actions == 0 and s.combat.actions_in_turn == 0 and s.phase == "ready", "skill never records clear or turn action")
	for i in range(2):
		clear_fixture(s,board(2));s.finish_refill()
	check(s.charge == 2 and s.phase == "ready", "two manual clears recharge reserved skill")
	s.skill_mode = true
	clear_fixture(s,board(2))
	check(s.charge == 0 and s.charge_required == 3, "next nonreserved skill returns to three-clear recharge")
	var before_actions: int = s.actions
	s.panels = board()
	s.begin(s.panels[0].pos,0);s.cancel()
	check(s.release(s.panels[0].pos,0).is_empty() and s.actions == before_actions and s.charge == 0, "cancelled input cannot change combat or recharge")
	s = make_run()
	s.skill_mode = true
	s.skill_color = 1
	clear_fixture(s,board(2))
	for i in range(3):
		clear_fixture(s,board(2));s.finish_refill()
		check(s.charge == i+1, "ordinary recharge advances once per manual action")
	check(s.charge == 3 and s.phase == "enemy_attack", "third ordinary clear recharges before retaliation")
	s.finish_attack()
	# The inherited 3/6/9 growth milestones never drive actual combat rewards.
	s = make_run()
	for i in range(9):
		clear_fixture(s,board(2));s.finish_refill()
		if (i+1)%3 == 0:
			check(s.phase == "enemy_attack" and s.rewards_taken == 0 and s.offer_serial == 0, "living target has attack rather than fixed-count growth reward")
			s.finish_attack()
	check(s.actions == 9 and s.phase == "ready" and not s.summary_shown and s.reward_options.is_empty(), "old nine-action summary remains unused")
	# Terminal defeat cannot be escaped through delayed completion callbacks.
	s = make_run()
	s.hp = 1
	for i in range(3):
		clear_fixture(s,board(2));s.finish_refill()
	check(s.hp == 0 and s.phase == "enemy_attack", "lethal attack clamps hp and retains attack presentation phase")
	s.finish_attack()
	check(s.phase == "defeat", "lethal attack completion is terminal defeat")
	s.finish_attack();s.finish_refill()
	check(s.phase == "defeat" and not s.begin(Vector2(90,400),0) and not s.begin_next_fight(board(),300), "terminal defeat rejects continuation and delayed callbacks")
	# Full three-win progression gives exactly two unowned relic rewards.
	s = make_run()
	for fight in range(3):
		s.combat.enemy_hp = 2
		clear_fixture(s,board(2));s.finish_refill()
		if fight < 2:
			check(s.phase == "reward" and s.reward_options.size() == 3-fight and s.reward_round == fight+1, "only first two kills offer remaining relics")
			var choice: String = s.reward_options[0] if not s.reward_options.is_empty() else ""
			check(s.choose_relic(choice,s.offer_serial), "progression accepts each earned choice")
			check(s.begin_next_fight(board(2,"normal",300+fight*10),400+fight*10), "progression begins next encounter")
		else:
			check(s.phase == "victory" and s.rewards_taken == 2 and s.reward_options.is_empty(), "third win is victory with no extra reward")
	check(s.actions == 3 and s.combat.enemies_defeated == 3, "run totals span encounters")
	s.finish_refill();s.finish_attack()
	check(s.phase == "victory" and not s.begin_next_fight(board(),900), "victory is terminal")
	var restarted = make_run()
	check(restarted.hp == 30 and restarted.actions == 0 and restarted.charge == 3 and restarted.rewards_taken == 0 and restarted.relics.is_empty() and not restarted.ash_reserved and restarted.combat.enemies_defeated == 0, "new instance restart has no carry from previous run")
	print("RUN_SESSION checks=",checks," failures=",failures)
	quit(1 if failures else 0)

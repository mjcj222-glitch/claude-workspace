extends SceneTree
## Explicit unit win fixtures isolate economy/phase contracts. These are not
## natural-play, performance or balance evidence.
const Run = preload("res://scripts/board_run_session.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func board(first_id: int = 1) -> Array:
	return [{"id":first_id,"pos":Vector2(100,700),"radius":37.0,"kind":"normal","color":0},
		{"id":first_id+1,"pos":Vector2(174,700),"radius":37.0,"kind":"normal","color":0}]
func fresh():
	var s = Run.new()
	s.initialize_board(board(),3)
	return s
func win(s) -> void:
	s.combat.enemy_hp = 1;s.combat.shield_hp=0
	for action in range(3):
		s.panels=board();s.begin(s.panels[0].pos,0);s.release(s.panels[0].pos,0)
		s.finish_refill()
		if action<2:check(s.phase=="ready" and s.combat.enemy_hp==1,"economy cannot pay banked damage early")
		else:
			check(s.phase=="player_attack","third clear reaches attack before payout")
			s.finish_player_attack()
			check(s.phase=="player_impact","payout waits for impact hold")
			s.finish_player_impact()
func first_reward(s) -> void:
	win(s)
	s.choose_relic("pigment",s.offer_serial)
func at_shop(chosen_route: String = "safe"):
	var s = fresh()
	first_reward(s)
	s.choose_route(chosen_route)
	s.begin_next_fight(board(10),12)
	win(s)
	s.choose_relic("lens",s.offer_serial)
	return s
func snapshot(s) -> Dictionary:
	return {"hp":s.hp,"gold":s.gold,"spent":s.gold_spent,"charge":s.charge,"required":s.charge_required,
		"ash":s.ash_reserved,"actions":s.actions,"relics":s.relics.duplicate(),"phase":s.phase,
		"serial":s.offer_serial,"heal_sold":s.shop_heal_sold,"relic_sold":s.shop_relic_sold,
		"closed":s.shop_closed,"route":s.route,"rewards":s.rewards_taken}
func _init() -> void:
	var s = fresh()
	check(s.route == "" and s.gold == 0 and s.gold_spent == 0 and not s.shop_heal_sold and not s.shop_relic_sold and not s.shop_closed,"new run economy is empty")
	check(s.SHOP_HEAL_PRICE == 4 and s.SHOP_RELIC_PRICE == 8 and s.SHOP_HEAL_AMOUNT == 8,"fixed prototype prices and healing amount")
	var before := snapshot(s)
	check(not s.choose_route("safe") and not s.buy_shop("heal") and not s.leave_shop() and snapshot(s) == before,"ready phase rejects route/shop calls without mutation")
	win(s)
	check(s.gold == 4 and s.phase == "reward" and s.reward_options.size() == 3,"first victory grants four gold and first relic offer")
	var serial: int = s.offer_serial
	s.finish_refill()
	check(s.gold == 4 and s.offer_serial == serial,"normal duplicate finish does not pay or recreate offer")
	s.phase = "busy";s.finish_refill()
	check(s.gold == 4 and s.offer_serial == serial,"per-encounter payout guard survives busy reentry")
	check(s.choose_relic("pigment",serial) and s.phase == "route","first reward enters route choice")
	before = snapshot(s)
	check(not s.choose_route("unknown") and snapshot(s) == before,"invalid route changes nothing")
	check(not s.begin_next_fight(board(10),12),"route choice cannot be bypassed")
	check(s.choose_route("elite") and s.phase == "between" and s.route == "elite","route selection is explicit")
	before = snapshot(s)
	check(not s.choose_route("safe") and snapshot(s) == before,"route cannot be chosen twice")
	check(s.begin_next_fight(board(10),12) and s.combat.encounter == 1 and s.combat.enemy_max_hp == 44,"selected elite route reaches combat configuration")
	win(s)
	check(s.gold == 12 and s.reward_options.size() == 3 and s.reward_round == 2,"elite second win pays eight in addition to first four")
	serial = s.offer_serial
	s.phase = "busy";s.finish_refill()
	check(s.gold == 12 and s.offer_serial == serial,"second encounter payout and offer are exact-once")
	check(s.choose_relic("lens",serial) and s.phase == "shop" and s.rewards_taken == 2,"second reward enters one-time shop")
	check(s.shop_remaining_relic() == "ash","shop offers exactly the remaining third relic")
	before = snapshot(s)
	check(not s.buy_shop("invalid") and snapshot(s) == before,"invalid shop item is atomic no-op")
	check(not s.buy_shop("heal") and snapshot(s) == before and s.shop_heal_gain() == 0,"full health cannot charge or consume heal stock")
	s.hp = 27
	check(s.shop_heal_gain() == 3,"heal preview caps partial health gap")
	serial = s.offer_serial
	check(s.buy_shop("heal") and s.hp == 30 and s.gold == 8 and s.gold_spent == 4 and s.shop_heal_sold,"partial healing buys exactly once at full price")
	check(s.offer_serial == serial+1,"successful purchase invalidates old UI serial")
	before = snapshot(s)
	check(not s.buy_shop("heal") and snapshot(s) == before,"sold healing cannot be purchased again")
	s.charge = 1;s.charge_required = 2;s.ash_reserved = true
	check(s.buy_shop("relic") and s.gold == 0 and s.gold_spent == 12 and s.relics == ["pigment","lens","ash"] and s.shop_relic_sold,"exact remaining eight gold buys third relic")
	check(s.rewards_taken == 2 and s.charge == 1 and s.charge_required == 2 and s.ash_reserved and s.actions == 6,"shop acquisition is not reward or retroactive resource change")
	check(s.shop_remaining_relic() == "","sold third relic leaves no remaining offer")
	before = snapshot(s)
	check(not s.buy_shop("relic") and snapshot(s) == before,"duplicate relic purchase is no-op")
	check(s.leave_shop() and s.shop_closed and s.phase == "between","shop exits at zero funds")
	before = snapshot(s)
	check(not s.leave_shop() and not s.buy_shop("heal") and snapshot(s) == before,"closed shop cannot be reused")
	check(s.begin_next_fight(board(20),22),"shop exit enables final fight")
	check(s.combat.encounter == 2 and s.combat.enemy_max_hp == 48 and s.gold == 0 and s.hp == 30 and s.relics.size() == 3 and s.charge == 1 and s.ash_reserved,"final fight unchanged and carries all resources")
	win(s)
	check(s.phase == "victory" and s.gold == 0 and s.gold_spent == 12 and s.rewards_taken == 2,"final victory has no payout or extra reward")
	for chosen_route in ["safe","elite"]:
		var route_run = at_shop(chosen_route)
		check(route_run.phase == "shop" and route_run.gold == (8 if chosen_route == "safe" else 12),"route determines total available gold")
		check(route_run.shop_remaining_relic() == "ash","each route preserves remaining-relic identity")
	# Reverse purchase order with elite funds still buys both, exactly 12G.
	s = at_shop("elite")
	s.hp = 12
	check(s.buy_shop("relic") and s.gold == 4 and not s.ash_reserved,"buying ash never grants retroactive reservation")
	check(s.shop_heal_gain() == 8 and s.buy_shop("heal") and s.hp == 20 and s.gold == 0 and s.gold_spent == 12,"relic-first order still permits eight-health purchase")
	check(s.leave_shop(),"both-purchase reverse order can exit")
	# Safe route affords only one of the two purchases, unless heal is skipped.
	s = at_shop("safe")
	s.hp = 18
	check(s.buy_shop("heal") and s.gold == 4 and s.hp == 26,"safe heal leaves four gold")
	before = snapshot(s)
	check(not s.buy_shop("relic") and snapshot(s) == before,"insufficient relic funds never partially purchase")
	check(s.leave_shop() and s.gold == 4,"leaving keeps unspent currency")
	s = at_shop("safe")
	check(s.buy_shop("relic") and s.gold == 0,"safe exact eight can buy relic instead")
	s.hp = 20
	before = snapshot(s)
	check(not s.buy_shop("heal") and snapshot(s) == before,"insufficient healing funds leave stock intact")
	check(s.leave_shop(),"safe relic-only exit works")
	# Explicit zero-fund unit fixture proves leaving never requires a purchase.
	s = at_shop("safe")
	s.gold = 0
	check(s.leave_shop() and s.relics.size() == 2 and not s.shop_heal_sold and not s.shop_relic_sold,"zero-fund shop may be left without buying")
	s.phase = "shop"
	check(not s.leave_shop() and not s.buy_shop("relic"),"closed latch rejects forced stale shop state")
	# Armed/stale transactions in every non-shop phase preserve resources.
	for blocked_phase in ["ready","busy","player_attack","player_impact","enemy_attack","reward","route","between","victory","defeat"]:
		s = at_shop("elite")
		s.hp = 10
		s.phase = blocked_phase
		before = snapshot(s)
		check(not s.buy_shop("heal") and not s.buy_shop("relic") and not s.leave_shop() and snapshot(s) == before, "non-shop phase blocks all purchases and exit")
	s = fresh();first_reward(s);s.choose_route("safe")
	s.phase = "route"
	before = snapshot(s)
	check(not s.choose_route("elite") and snapshot(s) == before, "route chosen latch survives stale phase reentry")
	s = at_shop("safe")
	s.leave_shop()
	serial = s.offer_serial
	s.phase = "busy";s.finish_refill()
	check(s.phase == "between" and s.gold == 8 and s.rewards_taken == 2 and s.shop_closed and s.offer_serial == serial, "resolved second win cannot reopen closed shop or grant currency")
	# Victory replay after reward acquisition must not reopen reward or repay.
	s = fresh();first_reward(s)
	serial = s.offer_serial
	s.phase = "busy";s.finish_refill()
	check(s.phase == "route" and s.gold == 4 and s.rewards_taken == 1 and s.offer_serial == serial,"resolved first win cannot offer a second earned relic")
	s = fresh()
	check(s.route == "" and s.gold == 0 and s.gold_spent == 0 and not s.shop_closed and not s.shop_heal_sold and not s.shop_relic_sold and s.relics.is_empty() and s.hp == 30 and s.charge == 3,"restart resets every economy and carry field")
	print("ROUTE_ECONOMY checks=",checks," failures=",failures)
	quit(1 if failures else 0)

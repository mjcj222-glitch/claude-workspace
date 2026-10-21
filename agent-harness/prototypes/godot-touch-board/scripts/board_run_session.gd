extends "res://scripts/board_session.gd"
## Three-fight orchestration. Clear/skill accounting remains inherited; route
## and shop transactions never mutate combat plans, charge or previous results.
const SHOP_HEAL_PRICE := 4
const SHOP_RELIC_PRICE := 8
const SHOP_HEAL_AMOUNT := 8
var combat = preload("res://scripts/board_combat.gd").new()
var route: String = ""
var gold: int = 0
var gold_spent: int = 0
var shop_heal_sold: bool = false
var shop_relic_sold: bool = false
var shop_closed: bool = false
var _paid_encounters: Dictionary = {}
var departure_choice := ""
var departure_started := false

func _init() -> void:
	hp = max_hp

func initialize_board(fresh_panels: Array, fresh_next_id: int) -> void:
	panels = fresh_panels.duplicate(true)
	next_id = fresh_next_id
	cancel()
	skill_mode = false
	combat.start_fight(0, panels)
	phase = "ready"

func open_departure() -> void:
	# Only a fresh session may enter departure. Mid-run APIs cannot change hero.
	if departure_started or actions != 0 or skill_uses != 0 or not relics.is_empty() or combat.encounter != 0:return
	cancel()
	skill_mode=false
	character_id=""
	departure_choice=""
	phase="departure"
	offer_serial+=1

func select_departure(id:String,serial:int)->bool:
	if phase!="departure" or serial!=offer_serial or id not in Characters.IDS:return false
	departure_choice=id
	cancel()
	offer_serial+=1
	return true

func start_departure(serial:int)->bool:
	if phase!="departure" or serial!=offer_serial or departure_choice not in Characters.IDS:return false
	character_id=departure_choice
	departure_started=true
	cancel()
	skill_mode=false
	offer_serial+=1
	phase="ready"
	return true

func release(point: Vector2, pointer: int) -> Dictionary:
	var result: Dictionary = super.release(point, pointer)
	if result.get("valid", false) and result.get("mode", "") == "clear":
		combat.record_clear(result)
	return result

func finish_refill() -> void:
	if phase != "busy":
		return
	cancel()
	skill_mode = false
	# Killing actions have already received normal charge/heal/ash accounting;
	# victory precedes scheduled retaliation and pays once per encounter.
	var outcome: String = combat.resolve()
	if outcome == "win":
		if combat.encounter < 2:
			if not _paid_encounters.has(combat.encounter):
				var payout := 8 if combat.encounter == 1 and route == "elite" else 4
				gold += payout
				_paid_encounters[combat.encounter] = payout
			if rewards_taken <= combat.encounter:
				reward_round = combat.encounter + 1
				if reward_options.is_empty():
					reward_options = Relics.available(relics)
					offer_serial += 1
				phase = "reward"
			elif combat.encounter == 0:
				# Even a stale externally reentered busy phase cannot repay or
				# reopen an already claimed earned reward.
				phase = "route" if route.is_empty() else "between"
			else:
				phase = "between" if shop_closed else "shop"
		else:
			reward_options = []
			phase = "victory"
	elif outcome == "attack":
		hp = maxi(0, hp - combat.take_attack())
		phase = "enemy_attack"
	else:
		phase = "ready"

func finish_attack() -> void:
	if phase != "enemy_attack":
		return
	cancel()
	skill_mode = false
	if hp <= 0:
		phase = "defeat"
	else:
		combat.next_turn(panels)
		phase = "ready"

func choose_relic(id: String, serial: int) -> bool:
	if combat.encounter >= 2 or rewards_taken != combat.encounter:
		return false
	if not super.choose_relic(id, serial):
		return false
	phase = "route" if combat.encounter == 0 else "shop"
	skill_mode = false
	offer_serial += 1
	return true

func choose_route(id: String) -> bool:
	if phase != "route" or not route.is_empty() or id not in ["safe", "elite"]:
		return false
	route = id
	cancel()
	skill_mode = false
	offer_serial += 1
	phase = "between"
	return true

func shop_heal_gain() -> int:
	return mini(SHOP_HEAL_AMOUNT, maxi(0, max_hp - hp))

func shop_remaining_relic() -> String:
	var remaining: Array = Relics.available(relics)
	return String(remaining[0]) if remaining.size() == 1 else ""

func buy_shop(item: String) -> bool:
	if phase != "shop" or shop_closed:
		return false
	if item == "heal":
		var gain := shop_heal_gain()
		if shop_heal_sold or gain <= 0 or gold < SHOP_HEAL_PRICE:
			return false
		gold -= SHOP_HEAL_PRICE
		gold_spent += SHOP_HEAL_PRICE
		hp += gain
		shop_heal_sold = true
	elif item == "relic":
		var id := shop_remaining_relic()
		if shop_relic_sold or id.is_empty() or gold < SHOP_RELIC_PRICE:
			return false
		gold -= SHOP_RELIC_PRICE
		gold_spent += SHOP_RELIC_PRICE
		relics.append(id)
		shop_relic_sold = true
	else:
		return false
	# A transaction invalidates armed UI candidates, but is not a clear or
	# an earned reward and never changes charge, ash or prior-action effects.
	cancel()
	offer_serial += 1
	return true

func leave_shop() -> bool:
	if phase != "shop" or shop_closed:
		return false
	shop_closed = true
	cancel()
	skill_mode = false
	offer_serial += 1
	phase = "between"
	return true

func begin_next_fight(fresh_panels: Array, fresh_next_id: int) -> bool:
	if phase != "between" or combat.encounter >= 2:
		return false
	if (combat.encounter == 0 and route.is_empty()) or (combat.encounter == 1 and not shop_closed):
		return false
	panels = fresh_panels.duplicate(true)
	next_id = fresh_next_id
	cancel()
	skill_mode = false
	combat.start_fight(combat.encounter + 1, panels, route)
	phase = "ready"
	return true

func plan_for(id: int) -> Dictionary:
	return Rules.plan(panels, id, hp, max_hp, relics.duplicate(), combat.damage_context())

func skill_plan_for(id: int, color: int) -> Dictionary:
	var result: Dictionary = super.skill_plan_for(id, color)
	result["combat_context"] = combat.damage_context().duplicate(true)
	return result

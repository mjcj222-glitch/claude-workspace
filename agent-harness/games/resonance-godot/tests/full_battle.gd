extends SceneTree
const Rules = preload("res://scripts/combat_rules.gd")
var battle: Node
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func wait_ready() -> bool:
    for i in range(1800):
        await physics_frame
        if battle.phase in ["READY","ENDED"]: return true
        if battle.phase=="ERROR": return false
    return false
func run() -> void:
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_reduced(true)
    if not await wait_ready(): quit(1);return
    var initial: Array = battle.snapshot.duplicate(true)
    var initial_rng: int = battle.board.rng.state
    var initial_next: int = battle.board.next_id
    for policy in ["largest","forecast"]:
        battle.state = Rules.fresh()
        battle.action_log.clear()
        battle.ending.hide()
        battle.board.restore(initial,initial_next,initial_rng)
        for n in range(180):
            if battle.phase=="ENDED": break
            # Equal skill/boost rules for both policies; the tap choice alone differs.
            for skill in range(3):
                if Rules.can_skill(battle.snapshot,battle.state,skill):
                    battle.use_skill(skill)
                    if not await wait_ready(): print("SETTLE_FAIL "+policy+JSON.stringify(battle.action_log));quit(1);return
            battle.use_boost()
            var chosen := -1
            var score := -INF
            for item in battle.snapshot:
                var p := Rules.preview(battle.snapshot,battle.edges,int(item.id),battle.state)
                var value: float
                if policy=="largest": value = p.initial.size()*10+p.damage*0.1
                else:
                    var incoming := 14 if int(battle.state.turn)%2 else 20
                    var urgency: float = 4.0 if battle.state.hp+mini(180-battle.state.hp,battle.state.pending_heal)-incoming<48 else 0.6
                    value = p.damage+mini(p.healing,maxi(0,180-battle.state.hp-battle.state.pending_heal))*urgency+(8 if p.echo_hit else 0)
                if value>score:
                    score = value
                    chosen = int(item.id)
            battle.commit(chosen)
            if not await wait_ready(): print("SETTLE_FAIL "+policy+JSON.stringify(battle.action_log));quit(1);return
        var report := {"policy":policy,"status":battle.state.status,"turns":battle.state.turn,"hp":battle.state.hp,"enemy_hp":battle.state.enemy_hp,"actions":battle.action_log}
        reports.append(report)
        print(JSON.stringify(report))
        if battle.state.status=="playing": print("BATTLE_TIMEOUT");quit(1);return
    # Defeat transition fixture: state-only setup, not presented as an organic playthrough.
    battle.state = Rules.fresh()
    battle.state.hp = 1
    battle.state.taps = 1
    battle.ending.hide()
    battle.board.restore(initial,initial_next,initial_rng)
    var victim := -1
    for item in battle.snapshot:
        if item.color!=3:
            var p := Rules.preview(battle.snapshot,battle.edges,int(item.id),battle.state)
            if p.healing==0: victim = int(item.id);break
    battle.commit(victim)
    if not await wait_ready(): quit(1);return
    var lost: bool = battle.state.status=="lost" and battle.ending.visible
    battle.start_new(41)
    if not await wait_ready(): quit(1);return
    var restarted: bool = battle.state.status=="playing" and battle.state.hp==180 and battle.board.pieces.size()==42
    print(JSON.stringify({"defeat_fixture":lost,"restart":restarted,"same_initial_snapshot":true,"same_skill_boost_policy":true,"physics_determinism_claimed":false}))
    quit(0 if lost and restarted else 1)

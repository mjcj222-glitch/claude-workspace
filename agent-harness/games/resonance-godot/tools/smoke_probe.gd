extends SceneTree
var battle: Node
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    for tick in range(2000):
        await physics_frame
        if battle.phase in ["READY","ERROR"]:
            print(JSON.stringify({"phase":battle.phase,"ticks":tick,"count":battle.board.pieces.size(),"settle_seconds":battle.board.last_settle_seconds,"snapshot":battle.board.capture()}))
            quit(0 if battle.phase=="READY" else 1)
            return
    print("TIMEOUT")
    quit(2)

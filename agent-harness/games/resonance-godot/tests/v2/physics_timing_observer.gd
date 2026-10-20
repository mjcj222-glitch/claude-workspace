extends Node
## Read-only poses and velocities after the Board physics callback.
var board: Node
var active := false
var frames: Array = []
func _physics_process(_delta: float) -> void:
    if not active: return
    var bodies: Array = []
    for p in board.pieces:
        bodies.append([p.identity,p.position.x,p.position.y,p.rotation,p.linear_velocity.x,p.linear_velocity.y,p.angular_velocity,p.freeze,p.sleeping])
    frames.append({"elapsed":board.elapsed,"quiet_ticks":board.stable_ticks,"settling":board.settling,"engine_physics_frame":Engine.get_physics_frames(),"bodies":bodies})

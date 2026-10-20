class_name ResonanceBoard
extends Node2D

signal settled(snapshot: Array)
signal settle_failed(reason: String)
const Piece = preload("res://scripts/piece.gd")
const Geometry = preload("res://scripts/piece_geometry.gd")
const WIDTH := 600.0
const HEIGHT := 580.0
var pieces: Array = []
var rng := RandomNumberGenerator.new()
var next_id := 1
var settling := false
var stable_ticks := 0
var elapsed := 0.0
var last_snapshot: Array = []
var reduce_motion := false
var selected_ids: Array = []
var last_settle_seconds := 0.0

func _ready() -> void:
    for box in [Rect2(-25,-1200,25,1805), Rect2(WIDTH,-1200,25,1805), Rect2(-25,HEIGHT,WIDTH+50,25)]:
        var wall := StaticBody2D.new()
        wall.position = box.get_center()
        var shape := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = box.size
        shape.shape = rectangle
        wall.add_child(shape)
        add_child(wall)

func new_board(seed_value: int) -> void:
    for piece in pieces:
        piece.free()
    pieces.clear()
    next_id = 1
    rng.seed = seed_value
    for i in range(42):
        spawn(rng.randi_range(0,3), Vector2(50+(i%6)*100+rng.randf_range(-3,3),-60-floori(i/6.0)*110))
    start_settling()

func spawn(color: int, location: Vector2, special: String = "normal", size_value: float = 0.0, angle: float = INF, id_value: int = 0) -> ResonancePiece:
    var piece := Piece.new()
    var assigned := id_value if id_value else next_id
    next_id = maxi(next_id, assigned+1)
    piece.configure(assigned, color, size_value if size_value else rng.randf_range(0.96,1.04), special)
    piece.reduced = reduce_motion
    piece.position = location
    piece.rotation = angle if is_finite(angle) else rng.randf_range(-PI,PI)
    add_child(piece)
    pieces.append(piece)
    return piece

func start_settling() -> void:
    settling = true
    stable_ticks = 0
    elapsed = 0.0
    select([])
    for piece in pieces:
        piece.freeze = false
        piece.sleeping = false
        piece.visible = not reduce_motion

func _physics_process(delta: float) -> void:
    if not settling:
        return
    elapsed += delta
    var quiet := true
    for piece in pieces:
        if piece.linear_velocity.length() > 2.0 or absf(piece.angular_velocity) > 0.045:
            quiet = false
            break
    stable_ticks = stable_ticks+1 if quiet else 0
    if stable_ticks >= 28:
        var snapshot := capture()
        if supported(snapshot):
            settling = false
            last_settle_seconds = elapsed
            for piece in pieces:
                piece.freeze = true
                piece.visible = true
            last_snapshot = snapshot
            settled.emit(snapshot)
    if settling and elapsed > 12.0:
        settling = false
        for piece in pieces:
            piece.freeze = true
            piece.visible = true
        print(JSON.stringify({"event":"settle_timeout","stable_ticks":stable_ticks,"elapsed":elapsed,"snapshot":capture(),"motion":pieces.map(func(p):return {"id":p.identity,"speed":p.linear_velocity.length(),"angular":p.angular_velocity})}))
        settle_failed.emit("기물이 아직 안정되지 않았어요. 다시 시작해 주세요.")

func capture() -> Array:
    var snapshot: Array = []
    for piece in pieces:
        snapshot.append(piece.snapshot())
    snapshot.sort_custom(func(a,b): return a.id < b.id)
    return snapshot

func supported(snapshot: Array) -> bool:
    var edges := Geometry.graph(snapshot)
    var reachable: Array = []
    for item in snapshot:
        var poly := Geometry.transformed(Geometry.polygon(item.color,item.size),Vector2(item.x,item.y),item.angle)
        for point in poly:
            if point.x < -0.8 or point.x > WIDTH+0.8 or point.y > HEIGHT+0.8 or point.y < 0:
                return false
            if point.y >= HEIGHT-Geometry.CONTACT_EPS and not reachable.has(int(item.id)):
                reachable.append(int(item.id))
    var i := 0
    while i < reachable.size():
        for other in edges[reachable[i]]:
            if not reachable.has(other): reachable.append(other)
        i += 1
    return reachable.size() == snapshot.size()

func piece_at(global_point: Vector2) -> int:
    if settling:
        return -1
    for piece in pieces:
        if piece.contains(global_point): return piece.identity
    return -1

func by_id(id_value: int) -> ResonancePiece:
    for piece in pieces:
        if piece.identity == id_value: return piece
    return null

func select(ids: Array) -> void:
    selected_ids = ids.duplicate()
    for piece in pieces:
        piece.selected = ids.has(piece.identity)
        piece.queue_redraw()
    queue_redraw()

func marks(ids: Array) -> void:
    for piece in pieces:
        piece.marked = ids.has(piece.identity)
        piece.queue_redraw()

func remove_and_refill(ids: Array, special: Dictionary) -> void:
    for id_value in ids:
        var piece := by_id(id_value)
        if piece:
            pieces.erase(piece)
            piece.free()
    if not special.is_empty():
        spawn(special.color,Vector2(special.x,special.y),special.kind,special.size,special.angle)
    var count := 42-pieces.size()
    var inlet_top: Array = [HEIGHT,HEIGHT,HEIGHT,HEIGHT,HEIGHT,HEIGHT]
    for piece in pieces:
        var poly := Geometry.transformed(piece.polygon,piece.position,piece.rotation)
        var left := INF
        var right := -INF
        var top := INF
        for point in poly:
            left = minf(left,point.x)
            right = maxf(right,point.x)
            top = minf(top,point.y)
        for lane in range(6):
            var inlet_x := 50+lane*100
            if right >= inlet_x-48 and left <= inlet_x+48:
                inlet_top[lane] = minf(inlet_top[lane],top)
    for i in range(count):
        # Feed the lowest available inlet, reserving space for this batch.
        # This chooses only the spawn lane; physics still determines every pose.
        var lane := (next_id-1)%6
        for candidate in range(6):
            if inlet_top[candidate] > inlet_top[lane]+0.01: lane = candidate
        inlet_top[lane] -= 100
        spawn(rng.randi_range(0,3),Vector2(50+lane*100+rng.randf_range(-3,3),-60-floori(i/6.0)*110))
    start_settling()

func restore(snapshot: Array, saved_next: int, saved_rng: int) -> void:
    for piece in pieces: piece.free()
    pieces.clear()
    for item in snapshot:
        var piece := spawn(item.color,Vector2(item.x,item.y),item.kind,item.size,item.angle,item.id)
        piece.freeze = true
    next_id = saved_next
    rng.state = saved_rng
    settling = false
    last_snapshot = capture()
    settled.emit(last_snapshot)

func _draw() -> void:
    if settling or last_snapshot.is_empty(): return
    var edges := Geometry.graph(last_snapshot)
    for id_value in selected_ids:
        var piece := by_id(id_value)
        if not piece: continue
        for other in edges.get(id_value,[]):
            if other > id_value and selected_ids.has(other):
                draw_line(piece.position,by_id(other).position,Color("fff0c2"),3,true)

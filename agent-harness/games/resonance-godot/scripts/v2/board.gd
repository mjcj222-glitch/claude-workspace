extends Node2D
## The board owns physical bodies and RNG; plans consume only capture() snapshots.

signal settled(snapshot: Dictionary)
signal settle_failed(reason: String)
const Config = preload("res://scripts/v2/config.gd")
const Piece = preload("res://scripts/v2/piece.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const WIDTH := Config.BOARD_WIDTH
const HEIGHT := Config.BOARD_HEIGHT
var pieces: Array = []
var rng := RandomNumberGenerator.new()
var next_id := 1
var version := 0
var settling := false
var stable_ticks := 0
var elapsed := 0.0
var last_settle_seconds := 0.0
var refill_phase := "idle"
var _pending_batch: Array = []
var _pending_openings: Array = []
var last_snapshot: Dictionary = {"version": 0, "pieces": []}

func _ready() -> void:
    # The mask clips every board child to the logical 600 x 600 play area.
    clip_children = CanvasItem.CLIP_CHILDREN_ONLY
    var wall_size := Config.WALL_THICKNESS
    var wall_top := Config.WALL_TOP
    for box in [Rect2(-wall_size, wall_top, wall_size, HEIGHT - wall_top + wall_size),
            Rect2(WIDTH, wall_top, wall_size, HEIGHT - wall_top + wall_size),
            Rect2(-wall_size, HEIGHT, WIDTH + wall_size * 2, wall_size)]:
        var wall := StaticBody2D.new()
        wall.position = box.get_center()
        var shape := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = box.size
        shape.shape = rectangle
        wall.add_child(shape)
        add_child(wall)
    queue_redraw()

func new_board(seed: int) -> void:
    _clear_bodies()
    next_id = 1
    rng.seed = seed
    for item in make_refill(Config.PIECE_COUNT):
        _spawn(item)
    refill_phase = "initial"
    _start_settling()

func capture() -> Dictionary:
    var ordered: Array = []
    for piece in pieces:
        ordered.append(piece.snapshot())
    ordered.sort_custom(func(a, b): return a.id < b.id)
    return {"version": version, "pieces": ordered}

func make_refill(count: int) -> Array:
    # This method consumes RNG and IDs, so callers invoke it only after commit.
    # The returned batch can be decorated by combat rules before apply_clear().
    var batch: Array = []
    for i in range(count):
        var roll := rng.randi_range(0, Config.TYPE_WEIGHT_TOTAL - 1)
        var type := "heart"
        var threshold := 0
        for candidate in Config.TYPES:
            threshold += int(Config.TYPE_WEIGHTS[candidate])
            if roll < threshold:
                type = candidate
                break
        var id := next_id
        next_id += 1
        var lane := (id - 1) % Config.SPAWN_LANES
        batch.append({"id": id, "hull_id": int(Config.TYPE_HULLS[type]), "match_type": type,
            "size": rng.randf_range(Config.SIZE_MIN, Config.SIZE_MAX),
            "x": Config.SPAWN_X + lane * Config.SPAWN_SPACING + rng.randf_range(-Config.SPAWN_JITTER, Config.SPAWN_JITTER),
            "y": Config.SPAWN_Y - floori(float(i) / Config.SPAWN_LANES) * Config.SPAWN_ROW_SPACING,
            "angle": rng.randf_range(-PI, PI), "bomb_tier": 0})
    return batch

func apply_clear(ids: Array, batch: Array) -> void:
    _pending_batch.clear()
    _pending_openings.clear()
    var openings: Array = []
    for id in ids:
        var removed = by_id(int(id))
        if removed != null:
            openings.append(removed.position.x)
    for id in ids:
        var piece = by_id(int(id))
        if piece != null:
            pieces.erase(piece)
            piece.free()
    # IDs/RNG were allocated by the caller exactly once. Keep the copied batch
    # out of the world while genuine survivors collapse into the removed space.
    _pending_batch = batch.duplicate(true)
    _pending_openings = openings.duplicate()
    refill_phase = "collapse" if not pieces.is_empty() and not batch.is_empty() else "incoming"
    _start_settling()
    if refill_phase == "incoming": _activate_pending_batch()

func _activate_pending_batch() -> void:
    var batch := _pending_batch
    var openings := _pending_openings
    _pending_batch = []
    _pending_openings = []
    refill_phase = "incoming"
    stable_ticks = 0
    var entry_roof: Array = []
    for piece in pieces:
        entry_roof.append(Geometry.transformed(piece.polygon,piece.position,piece.rotation))
    for i in range(batch.size()):
        var item: Dictionary = batch[i].duplicate(true)
        if not openings.is_empty():
            # Refill enters above the real cleared footprint; all descent and
            # neighbor displacement still comes from rigid-body collisions.
            var radius := 0.0
            for point in Geometry.polygon(int(item.hull_id), float(item.size)):
                radius = maxf(radius, point.length())
            item.x = clampf(float(openings[i % openings.size()]), radius + 1, WIDTH - radius - 1)
            var left := INF
            var right := -INF
            for point in Geometry.transformed(Geometry.polygon(int(item.hull_id),float(item.size)),Vector2.ZERO,float(item.angle)):
                left = minf(left,point.x)
                right = maxf(right,point.x)
            var sampled_x := clampf(float(batch[i].x),1.0-left,WIDTH-right-1.0)
            var local_hull := Geometry.transformed(Geometry.polygon(int(item.hull_id),float(item.size)),Vector2.ZERO,float(item.angle))
            # Compare only the existing footprint and already-sampled entry.
            # A lower first contact offers more real descent before the roof.
            if _entry_depth(local_hull,sampled_x,entry_roof) > _entry_depth(local_hull,float(item.x),entry_roof):
                item.x = sampled_x
            item.y = Config.SPAWN_Y - i * Config.SPAWN_ROW_SPACING
        var incoming = _spawn(item)
        entry_roof.append(Geometry.transformed(incoming.polygon,incoming.position,incoming.rotation))

func _vertical_span(poly: PackedVector2Array, x: float) -> Vector2:
    var span := Vector2(INF,-INF)
    for i in range(poly.size()):
        var a := poly[i]
        var b := poly[(i+1)%poly.size()]
        if x < minf(a.x,b.x) or x > maxf(a.x,b.x): continue
        if a.x == b.x:
            span.x = minf(span.x,minf(a.y,b.y))
            span.y = maxf(span.y,maxf(a.y,b.y))
        else:
            var y := lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
            span.x = minf(span.x,y)
            span.y = maxf(span.y,y)
    return span

func _entry_depth(local_hull: PackedVector2Array, x: float, roof: Array) -> float:
    var incoming := Geometry.transformed(local_hull,Vector2(x,0),0)
    var left := INF
    var right := -INF
    for point in incoming:
        left = minf(left,point.x)
        right = maxf(right,point.x)
    var depth := INF
    for other in roof:
        var other_left := INF
        var other_right := -INF
        for point in other:
            other_left = minf(other_left,point.x)
            other_right = maxf(other_right,point.x)
        var lo := maxf(left,other_left)
        var hi := minf(right,other_right)
        if lo > hi: continue
        # Between polygon vertex x coordinates both envelopes are linear, so
        # their first-contact minimum occurs at one of these exact endpoints.
        var xs: Array = [lo,hi]
        for poly in [incoming,other]:
            for point in poly:
                if point.x >= lo and point.x <= hi: xs.append(point.x)
        for at_x in xs:
            var a := _vertical_span(incoming,at_x)
            var b := _vertical_span(other,at_x)
            if a.y != -INF and b.x != INF: depth = minf(depth,b.x-a.y)
    return depth

func apply_types(changes: Dictionary) -> Dictionary:
    if settling:
        return capture()
    var changed := false
    for id in changes:
        var piece = by_id(int(id))
        var type := str(changes[id])
        if piece != null and Config.TYPES.has(type) and piece.match_type != type:
            piece.apply_type(type)
            changed = true
    if changed:
        version += 1
        last_snapshot = capture()
    return capture()

func checkpoint() -> Dictionary:
    return {"snapshot": capture(), "next_id": next_id,
        "rng_seed": str(rng.seed), "rng_state": str(rng.state)}

func restore(saved: Dictionary) -> void:
    _clear_bodies()
    var snapshot: Dictionary = saved.snapshot
    version = maxi(version, int(snapshot.version)) + 1
    for item in snapshot.pieces:
        _spawn(item,true)
    next_id = int(saved.next_id)
    rng.seed = int(saved.rng_seed)
    rng.state = int(saved.rng_state)
    settling = false
    stable_ticks = 0
    elapsed = 0.0
    refill_phase = "settled"
    last_snapshot = capture()
    settled.emit(last_snapshot.duplicate(true))

func supported(snapshot: Dictionary) -> bool:
    var tiles: Array = snapshot.pieces
    if tiles.is_empty():
        return false
    var edges := Geometry.graph(snapshot)
    var reachable: Array = []
    for item in tiles:
        var poly := Geometry.transformed(Geometry.polygon(int(item.hull_id), float(item.size)), Vector2(item.x, item.y), float(item.angle))
        for point in poly:
            if point.x < -Config.BOUNDARY_SLOP or point.x > WIDTH + Config.BOUNDARY_SLOP or point.y > HEIGHT + Config.BOUNDARY_SLOP or point.y < 0:
                return false
            if point.y >= HEIGHT - Config.CONTACT_EPS and not reachable.has(int(item.id)):
                reachable.append(int(item.id))
    var cursor := 0
    while cursor < reachable.size():
        for other in edges[reachable[cursor]]:
            if not reachable.has(other):
                reachable.append(other)
        cursor += 1
    return reachable.size() == tiles.size()

func by_id(id: int):
    for piece in pieces:
        if piece.identity == id:
            return piece
    return null

func piece_at(global_point: Vector2) -> int:
    if settling:
        return -1
    var local_point := to_local(global_point)
    if not Rect2(0, 0, WIDTH, HEIGHT).has_point(local_point):
        return -1
    for piece in pieces:
        if piece.contains(global_point):
            return piece.identity
    return -1

func _spawn(item: Dictionary, restored: bool = false):
    var piece = Piece.new()
    piece.configure(int(item.id), int(item.hull_id), str(item.match_type), float(item.size), int(item.bomb_tier))
    piece.position = Vector2(item.x, item.y)
    piece.rotation = float(item.angle)
    if restored:
        # Register checkpoint bodies in the kinematic frozen lifecycle before
        # entering the world; retain their original shape CCD on normal thaw.
        piece.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
        piece.freeze = true
    add_child(piece)
    pieces.append(piece)
    next_id = maxi(next_id, int(item.id) + 1)
    return piece

func _clear_bodies() -> void:
    _pending_batch.clear()
    _pending_openings.clear()
    refill_phase = "idle"
    for piece in pieces:
        piece.free()
    pieces.clear()

func _start_settling() -> void:
    version += 1
    settling = true
    stable_ticks = 0
    elapsed = 0.0
    for piece in pieces:
        piece.freeze = false
        piece.sleeping = false

func _physics_process(delta: float) -> void:
    if not settling:
        return
    elapsed += delta
    if elapsed > Config.SETTLE_TIMEOUT:
        _pending_batch.clear()
        _pending_openings.clear()
        refill_phase = "error"
        settling = false
        for piece in pieces:
            piece.freeze = true
        settle_failed.emit("기물이 아직 안정되지 않았어요. 다시 시작해 주세요.")
        return
    var quiet := true
    for piece in pieces:
        if piece.linear_velocity.length() > Config.SETTLE_SPEED or absf(piece.angular_velocity) > Config.SETTLE_ANGULAR_SPEED:
            quiet = false
            break
    stable_ticks = stable_ticks + 1 if quiet else 0
    if stable_ticks >= Config.SETTLE_QUIET_TICKS and supported(capture()):
        if refill_phase == "collapse":
            _activate_pending_batch()
            return
        refill_phase = "settled"
        settling = false
        last_settle_seconds = elapsed
        for piece in pieces:
            piece.freeze = true
        last_snapshot = capture()
        settled.emit(last_snapshot.duplicate(true))

func _draw() -> void:
    draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color.WHITE)

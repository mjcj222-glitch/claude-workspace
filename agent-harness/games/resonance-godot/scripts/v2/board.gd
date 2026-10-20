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
    var openings: Array = []
    for id in ids:
        var removed = by_id(int(id))
        if removed != null:
            openings.append(removed.position.x)
    openings.sort()
    for id in ids:
        var piece = by_id(int(id))
        if piece != null:
            pieces.erase(piece)
            piece.free()
    for i in range(batch.size()):
        var item: Dictionary = batch[i].duplicate(true)
        if not openings.is_empty():
            # Refill enters above the real cleared footprint; all descent and
            # neighbor displacement still comes from rigid-body collisions.
            var radius := 0.0
            for point in Geometry.polygon(int(item.hull_id), float(item.size)):
                radius = maxf(radius, point.length())
            item.x = clampf(float(openings[i % openings.size()]), radius + 1, WIDTH - radius - 1)
            item.y = Config.SPAWN_Y - i * Config.SPAWN_ROW_SPACING
        _spawn(item)
    _start_settling()

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
        var piece = _spawn(item)
        piece.freeze = true
    next_id = int(saved.next_id)
    rng.seed = int(saved.rng_seed)
    rng.state = int(saved.rng_state)
    settling = false
    stable_ticks = 0
    elapsed = 0.0
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

func _spawn(item: Dictionary):
    var piece = Piece.new()
    piece.configure(int(item.id), int(item.hull_id), str(item.match_type), float(item.size), int(item.bomb_tier))
    piece.position = Vector2(item.x, item.y)
    piece.rotation = float(item.angle)
    add_child(piece)
    pieces.append(piece)
    next_id = maxi(next_id, int(item.id) + 1)
    return piece

func _clear_bodies() -> void:
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
        settling = false
        last_settle_seconds = elapsed
        for piece in pieces:
            piece.freeze = true
        last_snapshot = capture()
        settled.emit(last_snapshot.duplicate(true))

func _draw() -> void:
    draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color.WHITE)

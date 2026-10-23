extends Node2D
## The board owns physical bodies and RNG; plans consume only capture() snapshots.

signal settled(snapshot: Dictionary)
signal settle_failed(reason: String)
signal recovery_settlement_finished
const Config = preload("res://scripts/v2/config.gd")
const Piece = preload("res://scripts/v2/piece.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Inlet = preload("res://scripts/v2/inlet_geometry.gd")
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
var _recovery_epoch := 0
var _recovering := false
var _pending_batch: Array = []
var _pending_openings: Array = []
var _admitted_count := 0
var _attempt_frame := -1
var _in_physics_boundary := false
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

func _exit_tree() -> void:
    _attempt_frame = -1
    _in_physics_boundary = false
    Inlet.clear_operation()
    # Resolve the coroutine before a retiring owner frees this board. Awaiting
    # a global physics-frame signal would retain a dead function state.
    if _recovering:
        _recovery_epoch += 1
        _recovering = false
        recovery_settlement_finished.emit()

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
    _attempt_frame = -1
    Inlet.clear_operation()
    _admitted_count = 0
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
    refill_phase = "incoming"
    stable_ticks = 0
    _admit_available()

func _admit_available() -> void:
    if _pending_batch.is_empty() or not _in_physics_boundary:return
    var process_frame_id:=Engine.get_process_frames()
    if _attempt_frame==process_frame_id:return
    _attempt_frame=process_frame_id # Spend before choose, including blocked heads.
    var obstacles: Array=[]
    for body in pieces:obstacles.append(Geometry.transformed(body.polygon,body.position,body.rotation))
    var item: Dictionary=_pending_batch[0].duplicate(true)
    var local:=Geometry.transformed(Geometry.polygon(int(item.hull_id),float(item.size)),Vector2.ZERO,float(item.angle))
    var result:=Inlet.choose(local,obstacles,float(item.x),WIDTH,HEIGHT,Config.SPAWN_Y,Config.CONTACT_EPS)
    if result.is_empty():return
    item.x=result.x
    item.y=result.y
    _spawn(item)
    _admitted_count+=1
    _pending_batch.pop_front()
    if not _pending_openings.is_empty():_pending_openings.pop_front()
    stable_ticks=0

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

func _has_selection(value: Dictionary) -> bool:
    return Selection.has_selection(value)

func recover_if_blocked() -> Dictionary:
    # The caller owns the input lock for the whole coroutine. Ordinary refill
    # signals during the single redrop must never finish combat a second time.
    if settling or _recovering or refill_phase == "error":
        return {"status":"error","snapshot":capture()}
    var original := capture()
    if _has_selection(original): return {"status":"unchanged","snapshot":original}
    _recovering = true
    _recovery_epoch += 1
    var epoch := _recovery_epoch
    var edges := Geometry.graph(original)
    var attempts := 0
    var type_counts := {}
    for item in original.pieces:
        type_counts[item.match_type] = int(type_counts.get(item.match_type,0))+1
    # A connected triple is a center and two neighbors, or a three-node path.
    # Enumerate in snapshot/graph ID order; move existing surfaces by swaps.
    for center in original.pieces:
        var neighbors: Array = edges[int(center.id)]
        for i in range(neighbors.size()):
            for j in range(i+1,neighbors.size()):
                for type in ["red","yellow","blue"]:
                    if int(type_counts.get(type,0)) < Config.MIN_GROUP: continue
                    if attempts >= Config.RECOVERY_ATTEMPTS: break
                    attempts += 1
                    var targets: Array = [int(center.id),neighbors[i],neighbors[j]]
                    var changes := {}
                    for item in original.pieces: changes[int(item.id)] = str(item.match_type)
                    for target in targets:
                        if changes[target] == type: continue
                        for donor in original.pieces:
                            if not targets.has(int(donor.id)) and changes[int(donor.id)] == type:
                                changes[int(donor.id)] = changes[target]
                                changes[target] = type
                                break
                    var value := apply_types(changes)
                    if _has_selection(value):
                        _recovering = false
                        return {"status":"recovered","snapshot":value}
                if attempts >= Config.RECOVERY_ATTEMPTS: break
            if attempts >= Config.RECOVERY_ATTEMPTS: break
        if attempts >= Config.RECOVERY_ATTEMPTS: break
    # No new bodies, IDs, random draws, or bomb decoration. Drop these exact
    # pieces once from the normal entry lanes, retaining hull/size/type/angle.
    for i in range(pieces.size()):
        var piece = pieces[i]
        var lane := i % Config.SPAWN_LANES
        piece.position = Vector2(Config.SPAWN_X+lane*Config.SPAWN_SPACING,
            Config.SPAWN_Y-floori(float(i)/Config.SPAWN_LANES)*Config.SPAWN_ROW_SPACING)
        piece.linear_velocity = Vector2.ZERO
        piece.angular_velocity = 0.0
    refill_phase = "recovery"
    _start_settling()
    await recovery_settlement_finished
    if epoch != _recovery_epoch:
        return {"status":"error","snapshot":capture()}
    _recovering = false
    var value := capture()
    if refill_phase != "error" and _has_selection(value):
        return {"status":"recovered","snapshot":value}
    refill_phase = "error"
    return {"status":"error","snapshot":value}

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
    _attempt_frame = -1
    Inlet.clear_operation()
    _recovery_epoch += 1
    var was_recovering := _recovering
    _recovering = false
    if was_recovering: recovery_settlement_finished.emit()
    _pending_batch.clear()
    _pending_openings.clear()
    _admitted_count = 0
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
    # One actual process-frame credit spans all catch-up physics callbacks.
    # Keep the wrapper small so every early return clears boundary ownership.
    _in_physics_boundary = true
    _step_settling(delta)
    _in_physics_boundary = false
    if refill_phase == "error":
        _attempt_frame = -1
        Inlet.clear_operation()

func _step_settling(delta: float) -> void:
    if not settling:
        return
    if refill_phase == "incoming" and not _pending_batch.is_empty(): _admit_available()
    elapsed += delta
    if elapsed > Config.SETTLE_TIMEOUT:
        _pending_batch.clear()
        _pending_openings.clear()
        _admitted_count = 0
        refill_phase = "error"
        settling = false
        for piece in pieces:
            piece.freeze = true
        settle_failed.emit("기물이 아직 안정되지 않았어요. 다시 시작해 주세요.")
        if _recovering: recovery_settlement_finished.emit()
        return
    var quiet := true
    for piece in pieces:
        if piece.linear_velocity.length() > Config.SETTLE_SPEED or absf(piece.angular_velocity) > Config.SETTLE_ANGULAR_SPEED:
            quiet = false
            break
    stable_ticks = stable_ticks + 1 if quiet else 0
    if stable_ticks >= Config.SETTLE_QUIET_TICKS and (refill_phase == "collapse" or _pending_batch.is_empty()) and supported(capture()):
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
        if _recovering: recovery_settlement_finished.emit()

func _draw() -> void:
    draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color.WHITE)

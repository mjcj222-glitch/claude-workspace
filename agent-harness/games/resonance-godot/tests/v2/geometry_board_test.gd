extends SceneTree

const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Piece = preload("res://scripts/v2/piece.gd")
const Board = preload("res://scripts/v2/board.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var checks := 0
var failures := 0
var max_overlap := 0.0
var max_settle := 0.0
var settled_count := 0
var failed_count := 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func inspect_shapes() -> void:
    var hulls: Array = []
    var diameter_sum := 0.0
    for hull in range(4):
        var poly := Geometry.polygon(hull, 1.0)
        hulls.append(poly)
        check(Geometry.area(poly) > 3000, "every fixed hull has meaningful area")
        check(Geometry2D.is_point_in_polygon(Vector2.ZERO, poly), "hull center is filled")
        check(not Geometry2D.is_point_in_polygon(Vector2(58, 58), poly), "empty corner is not filled")
        var diameter := 0.0
        for a in poly:
            for b in poly:
                diameter = maxf(diameter, a.distance_to(b))
        diameter_sum += diameter
        for type in ["red", "yellow", "blue", "heart"]:
            var piece = Piece.new()
            piece.configure(17, hull, type, 1.0, 2 if type == "blue" else 0)
            piece.position = Vector2(123, 234)
            piece.rotation = 0.71
            var before: Dictionary = piece.snapshot()
            check(piece.polygon == poly, "display silhouette depends on hull, never match type")
            check(piece.collider != null and piece.collider.polygon == piece.polygon, "visible and collision polygon agree")
            check(piece.contains(piece.position), "physical hull center is touchable")
            check(before.match_type == type and before.hull_id == hull, "snapshot separates hull and type")
            for converted in ["heart", "red", "blue", "yellow"]:
                piece.apply_type(converted)
                var after: Dictionary = piece.snapshot()
                check(after.match_type == converted, "conversion applies new surface type")
                check(after.id == before.id and after.hull_id == before.hull_id and after.size == before.size,
                    "conversion preserves identity, hull and size")
                check(piece.position == Vector2(123, 234) and is_equal_approx(piece.rotation, 0.71), "conversion preserves position and rotation")
                check(piece.polygon == poly and piece.collider.polygon == poly, "conversion preserves visible and collision boundary")
                check(after.match_type == "blue" or after.bomb_tier == 0, "bombs exist only on blue")
            piece.free()
    for i in range(4):
        for j in range(i):
            check(hulls[i] != hulls[j], "four hulls remain distinct")
    check(is_equal_approx(Geometry.diameter_unit(), diameter_sum / 4.0), "D is mean of fixed hull diameters")

func inspect_graph() -> void:
    for hull in range(4):
        var poly := Geometry.polygon(hull, 1.0)
        var max_x := 0.0
        for point in poly: max_x = maxf(max_x, point.x)
        for angle in [0.0, 0.38, -0.9]:
            for gap in [0.5, 2.0]:
                var first := Fixtures.tile(1, "red", hull, Vector2.ZERO)
                var second := Fixtures.tile(2, "blue", hull, Vector2(2 * max_x + gap, 0).rotated(angle))
                first.angle = angle
                second.angle = angle
                check(Geometry.graph(Fixtures.snapshot([first, second])).get(1, []).has(2) == (gap == 0.5),
                    "every hull uses actual boundary contact at rotated 0.5 and 2.0 gaps")
    for angle in [0.0, 0.38, -0.9]:
        for gap in [0.5, 2.0]:
            var a := Fixtures.tile(2, "red", 0, Vector2.ZERO)
            var b := Fixtures.tile(1, "heart", 0, Vector2(76 + gap, 0).rotated(angle))
            a.angle = angle
            b.angle = angle
            var snap := Fixtures.snapshot([a, b])
            var original := snap.duplicate(true)
            var edges := Geometry.graph(snap)
            check(edges.get(1, []).has(2) == (gap == 0.5), "0.5 gap joins; 2.0 gap does not, including rotation")
            check(edges.get(2, []).has(1) == (gap == 0.5), "contact graph is symmetric and independent of type")
            check(snap == original, "graph does not mutate input")
    var a := Fixtures.tile(1, "red", 2, Vector2(100, 100))
    a.angle = 0.63
    var b := Fixtures.tile(2, "red", 0, Vector2(140, 60).rotated(0.63) + Vector2(100, 100) - Vector2(100, 100).rotated(0.63))
    b.size = 0.08
    check(not Geometry.graph(Fixtures.snapshot([a, b])).get(1, []).has(2), "tilted star empty corner does not create hidden contact")
    b.x = a.x
    b.y = a.y
    check(Geometry.graph(Fixtures.snapshot([a, b])).get(1, []).has(2), "different hulls of same type share physical contact graph")
    check(Geometry.graph(Fixtures.chain(3)).get(2, []) == [1, 3], "fixture chain uses circular hulls at 0.5 gap with sorted IDs")

func wait_board(board) -> bool:
    for tick in range(1800):
        if not board.settling:
            return failed_count == 0
        await physics_frame
    check(false, "board must settle or report failure within bounded wait")
    return false

func inspect_board(board) -> void:
    var snap: Dictionary = board.capture()
    check(snap.pieces.size() == 42, "physical board has 42 pieces")
    check(board.supported(snap), "all hulls are inside boundary and supported from floor")
    check(board.scale == Vector2.ONE, "logical physical parent scale is one")
    var ids: Array = []
    var polygons: Array = []
    for item in snap.pieces:
        ids.append(item.id)
        polygons.append(Geometry.transformed(Geometry.polygon(item.hull_id, item.size), Vector2(item.x, item.y), item.angle))
    var unique := {}
    for id in ids: unique[id] = true
    check(unique.size() == 42, "piece IDs are unique")
    var sorted_ids := ids.duplicate()
    sorted_ids.sort()
    check(ids == sorted_ids, "capture sorted by ID")
    for i in range(polygons.size()):
        for j in range(i):
            for overlap in Geometry2D.intersect_polygons(polygons[i], polygons[j]):
                max_overlap = maxf(max_overlap, Geometry.area(overlap))
    check(max_overlap < 32.0, "no deep hull overlaps beyond physics contact slop")
    max_settle = maxf(max_settle, board.last_settle_seconds)
    check(board.last_settle_seconds <= 12.0, "settlement has a 12 second error bound")

func run() -> void:
    var defaults := Fixtures.combat()
    check(defaults.hp == 72 and defaults.enemy_hp == 72 and defaults.energy == 4 and defaults.actions_left == 3,
        "combat fixture provides starting common state")
    var gate := Fixtures.combat("gate", 4, 12, 0)
    check(gate.enemy_hp == 168 and gate.hp == 12 and gate.energy == 0 and gate.intent.kind == "strong"
        and gate.intent.pressure == 4 and gate.intent.total_damage == 32,
        "combat fixture honors enemy, turn, HP and energy overrides")
    inspect_shapes()
    inspect_graph()
    var board = Board.new()
    root.add_child(board)
    board.settled.connect(func(_snap): settled_count += 1)
    board.settle_failed.connect(func(_reason): failed_count += 1)
    for seed_value in [41, 73, 991, 20261020]:
        var prior_version: int = board.capture().version
        board.new_board(seed_value)
        if await wait_board(board):
            inspect_board(board)
        else:
            check(false, "seed %d settles successfully" % seed_value)
        check(board.capture().version > prior_version, "new board advances version")
    if board.capture().pieces.size() == 42:
        var before: Dictionary = board.capture()
        var events_before := settled_count
        var first: Dictionary = before.pieces[0]
        var rng_before: Dictionary = board.checkpoint()
        var converted: Dictionary = board.apply_types({first.id: "heart"})
        check(board.checkpoint().rng_state == rng_before.rng_state and board.checkpoint().next_id == rng_before.next_id, "type conversion consumes no RNG or IDs")
        check(converted.version > before.version and converted.pieces[0].match_type == "heart", "apply_types returns new version and type")
        var expected: Array = before.pieces.duplicate(true)
        expected[0].match_type = "heart"
        expected[0].bomb_tier = 0
        check(converted.pieces == expected, "type conversion changes no pose, hull, size or ID")
        check(events_before == settled_count and not board.settling, "type conversion emits no refill completion")
        var checkpoint: Dictionary = board.checkpoint()
        var batch: Array = board.make_refill(3)
        check(batch.size() == 3, "refill creates requested batch")
        check(board.capture() == converted, "make_refill alone changes no visible bodies or board version")
        board.restore(checkpoint)
        check(board.capture().pieces == converted.pieces and board.capture().version > converted.version, "restore preserves pieces and advances version")
        check(board.make_refill(3) == batch, "checkpoint restores random generator and next ID")
        board.restore(checkpoint)
        var before_clear: int = board.capture().version
        board.apply_clear([first.id, before.pieces[1].id, before.pieces[2].id], board.make_refill(3))
        check(board.capture().version > before_clear, "clear advances version before settlement")
        if await wait_board(board): inspect_board(board)
        check(failed_count == 0, "valid refill does not time out")
        var frozen: Dictionary = board.capture()
        for tick in range(30): await physics_frame
        check(board.capture() == frozen, "settled bodies remain frozen while selecting")
        var before_rng: Dictionary = board.checkpoint()
        var many: Array = board.make_refill(10000)
        var counts := {"red": 0, "yellow": 0, "blue": 0, "heart": 0}
        for item in many:
            counts[item.match_type] += 1
            check(item.bomb_tier == 0, "normal refill never invents bombs")
        for type in ["red", "yellow", "blue", "heart"]:
            check(absf(counts[type] / 10000.0 - (0.1 if type == "heart" else 0.3)) < 0.02, "normal refill follows integer 30/30/30/10 weights")
        board.restore(before_rng)
        # A quiet unsupported board must fail after 12s, never emit settled.
        board.apply_clear([], [])
        for piece in board.pieces:
            piece.freeze = true
            piece.position.y -= 200
        var signals_before := settled_count
        board.elapsed = 12.01
        board._physics_process(1.0 / 120.0)
        check(failed_count == 1 and settled_count == signals_before and not board.settling, "timeout reports error rather than normal settlement")
        board.restore(before_rng)
        board.apply_clear([], [])
        for piece in board.pieces:
            piece.freeze = true
            piece.linear_velocity = Vector2.ZERO
            piece.angular_velocity = 0.0
        board.elapsed = 12.01
        board.stable_ticks = 27
        signals_before = settled_count
        board._physics_process(1.0 / 120.0)
        check(failed_count == 2 and settled_count == signals_before and not board.settling,
            "first quiet tick after deadline still reports timeout instead of success")
    board.free()
    print(JSON.stringify({"suite": "v2 hull and physics foundation", "checks": checks, "failures": failures,
        "max_overlap_area": max_overlap, "max_settle_seconds": max_settle, "settled_boards": settled_count}))
    quit(0 if failures == 0 else 1)

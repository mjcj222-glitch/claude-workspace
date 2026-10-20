extends SceneTree
## Real Board/Selection measurement. Not full expedition gameplay.
const Board = preload("res://scripts/v2/board.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Config = preload("res://scripts/v2/config.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
class BirthAuditBoard:
    extends "res://scripts/v2/board.gd"
    var births: Array = []
    func _spawn(item: Dictionary, restored: bool = false):
        var body = super._spawn(item,restored)
        var poly := Geometry.transformed(body.polygon,body.position,body.rotation)
        var overlap := 0.0
        for prior in births:
            var previous = by_id(int(prior.actual.id))
            if previous == null: continue
            var other := Geometry.transformed(previous.polygon,previous.position,previous.rotation)
            for intersection in Geometry2D.intersect_polygons(poly,other): overlap = maxf(overlap,Geometry.area(intersection))
        births.append({"actual":body.snapshot(),"polygon":poly,"overlap_with_incoming":overlap})
        return body
var failures := 0
var timed_out := false
var enforce := false
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void: call_deferred("run")
func wait_board(board) -> void:
    for tick in range(1800):
        if not board.settling: return
        await physics_frame
    check(false, "bounded physical wait")
func polygons(snapshot: Dictionary) -> Array:
    var out: Array = []
    for p in snapshot.pieces:
        out.append(Geometry.transformed(Geometry.polygon(p.hull_id,p.size),Vector2(p.x,p.y),p.angle))
    return out
func measure(board, seed_value: int, phase: String, motion: Dictionary = {}) -> void:
    var snapshot: Dictionary = board.capture()
    var polys := polygons(snapshot)
    var area := 0.0
    var top := 600.0
    var overlap := 0.0
    for i in range(polys.size()):
        area += Geometry.area(polys[i])
        for p in polys[i]: top = minf(top,p.y)
        for j in range(i):
            for intersection in Geometry2D.intersect_polygons(polys[i],polys[j]):
                overlap = maxf(overlap,Geometry.area(intersection))
    # Pixel-center samples in the occupied band count actual polygon voids.
    var empty := 0
    var samples := 0
    for y in range(ceili(top),600,4):
        for x in range(2,600,4):
            samples += 1
            var filled := false
            for poly in polys:
                if Geometry2D.is_point_in_polygon(Vector2(x,y),poly):
                    filled = true
                    break
            if not filled: empty += 1
    var metric := {"seed":seed_value,"phase":phase,"count":snapshot.pieces.size(),"area_ratio":area/360000.0,"top_empty":top,"occupied_height":600-top,"band_void_ratio":float(empty)/maxi(1,samples),"max_overlap":overlap,"supported":board.supported(snapshot),"settle_seconds":board.last_settle_seconds,"timed_out":timed_out,"elapsed_seconds":board.elapsed,"motion":motion}
    print(JSON.stringify(metric))
    check(snapshot.pieces.size()==42,"42 bodies after "+phase)
    check(not timed_out and board.last_settle_seconds<=12,"12 second successful settlement")
    check(board.supported(snapshot),"supported and bounded hulls")
    check(overlap<32,"maximum overlap remains below 32")
    if enforce:
        check(area/360000.0 >= 0.60 and area/360000.0 <= 0.71,"bounded area occupancy 60–71%")
        # Controller visual ruling keeps initial 15%; compact refill may use 16%.
        var top_limit := 90.0 if phase == "initial" else 96.0
        check(top >= 0 and top <= top_limit,"settled %s top band at most %d pixels" % [phase,int(top_limit)])
func run() -> void:
    enforce = not OS.get_cmdline_user_args().has("--measure-only")
    var board = BirthAuditBoard.new()
    root.add_child(board)
    board.settle_failed.connect(func(_reason): timed_out = true)
    for seed_value in [41,73,991,20261020]:
        timed_out = false
        board.new_board(seed_value)
        await wait_board(board)
        measure(board,seed_value,"initial")
        var before: Dictionary = board.capture()
        var plan := {}
        for piece in before.pieces:
            var candidate := Selection.preview(before,int(piece.id),1)
            if not candidate.is_empty() and (plan.is_empty() or candidate.direct_ids.size()>plan.direct_ids.size()): plan=candidate
        check(not plan.is_empty(),"seed has legal physical selection")
        if plan.is_empty(): continue
        var neighbors := {}
        var graph := Geometry.graph(before)
        for id in plan.removed_ids:
            for other in graph[id]:
                if not plan.removed_ids.has(other): neighbors[other]=true
        var poses := {}
        for p in before.pieces: poses[p.id]=p
        var max_translation := 0.0
        var max_rotation := 0.0
        var moved := {}
        var batch: Array = board.make_refill(plan.removed_ids.size())
        var batch_before := batch.duplicate(true)
        board.births.clear()
        board.apply_clear(plan.removed_ids,batch)
        check(batch == batch_before,"physical inlet leaves supplied refill batch unchanged")
        # Capture every real birth inside a test-only _spawn override, before
        # physics advances its rotation; admission can span multiple frames.
        for tick in range(1800):
            if not board.settling: break
            await physics_frame
            for id in neighbors:
                var body = board.by_id(id)
                var distance: float = body.position.distance_to(Vector2(poses[id].x,poses[id].y))
                var angle := absf(angle_difference(poses[id].angle,body.rotation))
                max_translation = maxf(max_translation,distance)
                max_rotation = maxf(max_rotation,angle)
                if distance>3 and angle>0.04: moved[id]=true
        check(board.births.size() == batch.size(),"every pending batch member has exactly one actual birth")
        for index in range(board.births.size()):
            var birth: Dictionary = board.births[index]
            var actual: Dictionary = birth.actual
            var item: Dictionary = batch[index]
            check(actual.id == item.id and actual.hull_id == item.hull_id and actual.match_type == item.match_type and actual.size == item.size and actual.angle == item.angle and actual.bomb_tier == item.bomb_tier,"inlet preserves sampled identity hull type size angle bomb at exact birth")
            check(Array(birth.polygon).all(func(point):return point.x>=Config.CONTACT_EPS and point.x<=Config.BOARD_WIDTH-Config.CONTACT_EPS and point.y<=-Config.CONTACT_EPS),"finite aperture keeps entire actual birth hull above board inside width")
            for point in birth.polygon: check(point.y < 0,"refill begins above visible board")
            check(birth.overlap_with_incoming < 0.01,"incoming hulls begin without overlap with actual prior births")
        var motion := {"removed_ids":plan.removed_ids,"neighbor_ids":neighbors.keys(),"max_translation":max_translation,"max_rotation_radians":max_rotation,"translated_and_rolled_ids":moved.keys(),"refill_count":batch.size()}
        measure(board,seed_value,"refill",motion)
        check(max_translation>3 and max_rotation>0.04 and not moved.is_empty(),"actual removal neighbors translate and roll")
        var frozen: Dictionary = board.capture()
        for tick in range(30): await physics_frame
        check(board.capture()==frozen,"stable snapshot has no cosmetic motion")
    board.free()
    print(JSON.stringify({"suite":"physical density and organic removal motion","failures":failures}))
    quit(0 if failures==0 else 1)

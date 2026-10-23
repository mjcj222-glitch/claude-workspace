extends SceneTree
## Historical1.0 matching, CURRENT product Board physics. No normal-win claims.
const Geometry = preload("res://scripts/v2/geometry.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
class AuditBoard:
    extends "res://scripts/v2/board.gd"
    var births: Array = []
    func _spawn(item: Dictionary, restored: bool = false):
        var body = super._spawn(item,restored)
        births.append(body.snapshot())
        return body
var failures := 0
var checks := 0
var rows: Array = []
var derived_witness: Dictionary
var current_audit: Script
var target_switched := false
var current_only := false
var standalone := false
var density_only := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; print("FAIL: ",message)
func wait_board(board: Node) -> void:
    for tick in range(1800):
        if not board.settling: return
        await physics_frame
    check(false,"historical physical wait bounded")
func equal_json(actual: Variant, expected: Variant) -> bool:
    # Normalize native int arrays versus parsed JSON numbers symmetrically;
    # compare the complete canonical serialized structures without tolerances.
    return JSON.stringify(JSON.parse_string(JSON.stringify(actual))) == JSON.stringify(JSON.parse_string(JSON.stringify(expected)))
func metrics(board: Node) -> Dictionary:
    var polygons: Array = []
    var top := INF
    var area := 0.0
    var overlap := 0.0
    for item in board.capture().pieces:
        var poly := Geometry.transformed(Geometry.polygon(item.hull_id,item.size),Vector2(item.x,item.y),item.angle)
        area += Geometry.area(poly)
        for point in poly: top = minf(top,point.y)
        for previous in polygons:
            var intersection_area := 0.0
            for intersection in Geometry2D.intersect_polygons(poly,previous): intersection_area += Geometry.area(intersection)
            overlap = maxf(overlap,intersection_area)
        polygons.append(poly)
    return {"count":board.pieces.size(),"top":top,"area_ratio":area/360000.0,"max_overlap":overlap,"supported":board.supported(board.capture()),"elapsed":board.elapsed,"phase":board.refill_phase}
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args(): quit(1); return
    derived_witness = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v2/fixtures/inlet_history/derived42_witness.json"))
    current_only = "--current-only" in OS.get_cmdline_user_args()
    standalone = "--standalone" in OS.get_cmdline_user_args()
    density_only = "--density-only" in OS.get_cmdline_user_args()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--product-audit="): current_audit = load(arg.trim_prefix("--product-audit="))
    var mandatory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v2/fixtures/inlet_history/mandatory_20261020.json"))
    for tail in ([] if standalone else [30,60]):
        var board = AuditBoard.new()
        root.add_child(board)
        for seed_value in [41,73,991,20261020]:
            board.new_board(seed_value)
            await wait_board(board)
            var before: Dictionary = board.capture()
            var plan := {}
            for piece in before.pieces:
                var candidate := Selection.preview(before,int(piece.id),1)
                if not candidate.is_empty() and (plan.is_empty() or candidate.direct_ids.size() > plan.direct_ids.size()): plan = candidate
            var batch: Array = board.make_refill(plan.removed_ids.size())
            if seed_value == 20261020:
                check(plan.removed_ids == [28,30,33,34,35,36,41],"mandatory historical7 IDs retained in both genuine tails")
                check(equal_json(batch,mandatory.batch),"mandatory original sampled batch retained")
                if tail == 30:
                    if not current_only:
                        check(equal_json(before,mandatory.before),"mandatory ORIGINAL tail30 full snapshot/version/poses exactly retained")
                    else:
                        var metadata:Array=[]
                        var original_metadata:Array=[]
                        for piece in before.pieces:
                            metadata.append([piece.id,piece.hull_id,piece.match_type,piece.size,piece.bomb_tier])
                        for piece in mandatory.before.pieces:
                            original_metadata.append([piece.id,piece.hull_id,piece.match_type,piece.size,piece.bomb_tier])
                        check(equal_json(metadata,original_metadata) and before.version==int(mandatory.before.version),"CURRENT-throughout prefix preserves complete id/hull/type/size/bomb projection and version; physical x/y/angle may change")
            var initial := board.checkpoint()
            var immutable := batch.duplicate(true)
            var graph := Geometry.graph(before)
            var neighbors := {}
            var poses := {}
            for piece in before.pieces: poses[int(piece.id)] = piece
            for id in plan.removed_ids:
                for other in graph[id]:
                    if not plan.removed_ids.has(other): neighbors[other] = true
            var moved := {}
            board.births.clear()
            board.apply_clear(plan.removed_ids,batch)
            while board.settling:
                await physics_frame
                for id in neighbors:
                    var body = board.by_id(id)
                    if body.position.distance_to(Vector2(poses[id].x,poses[id].y)) > 3 and absf(angle_difference(poses[id].angle,body.rotation)) > 0.04: moved[id] = true
            var result := metrics(board)
            check(result.count == 42 and result.phase == "settled" and result.supported and result.elapsed <= 12 and result.max_overlap < 32,"historical density final42 support/bounds/overlap/deadline")
            check(result.top >= 0 and result.top <= 96 and result.area_ratio >= 0.60 and result.area_ratio <= 0.71,"historical ordinary density/top gates preserved")
            check(not moved.is_empty(),"historical removal neighbors translate and roll physically")
            check(batch == immutable and board.checkpoint().rng_state == initial.rng_state and board.next_id == initial.next_id,"historical batch/RNG/nextID immutable")
            check(board.births.size() == batch.size(),"all historical batch births observed")
            for index in range(board.births.size()):
                for key in ["id","hull_id","match_type","size","angle","bomb_tier"]: check(board.births[index][key] == batch[index][key],"historical birth preserves sampled "+key)
                if current_only:
                    var born:Dictionary=board.births[index]
                    var poly:=Geometry.transformed(Geometry.polygon(born.hull_id,born.size),Vector2(born.x,born.y),born.angle)
                    check(Array(poly).all(func(point):return point.x>=1 and point.x<=599 and point.y<=-1),"current finite aperture entire birth hull above board within width")
                else:
                    check(board.births[index].y == -60-index*110,"frozen historical original global-index birth height")
            var row := {"kind":"genuine historical ordinary reuse","tail":tail,"seed":seed_value,"removed_ids":plan.removed_ids,"metrics":result,"before":initial.duplicate(true),"batch":immutable.duplicate(true),"after":board.checkpoint().duplicate(true)}
            row["profile"]="CURRENT Board throughout / historical1.0 matching; metadata projection, changed physical poses" if current_only else "frozen historical prefix, exact original poses"
            rows.append(row)
            print(JSON.stringify(row))
            for tick in range(tail): await physics_frame
        board.free()
        await physics_frame
    var large = AuditBoard.new()
    root.add_child(large)
    for seed_value in ([] if density_only else [41,73,991,20261020]):
        for tier in ([1,2,3,42] if seed_value in [41,20261020] else [42]):
            large.new_board(seed_value)
            await wait_board(large)
            var seed_id := -1
            var closest := INF
            for item in large.capture().pieces:
                var distance := Vector2(item.x,item.y).distance_to(Vector2(300,330))
                if distance < closest: closest = distance; seed_id = int(item.id)
            var changes := {}
            if tier == 42:
                for item in large.capture().pieces: changes[item.id] = "blue"
            else: changes[seed_id] = "blue"
            large.apply_types(changes)
            for id in changes: large.by_id(int(id)).bomb_tier = 3 if tier == 42 else tier
            var plan := Selection.preview(large.capture(),seed_id,1)
            if standalone:
                var expected_counts := {41:[8,13,20,42],73:[42],991:[42],20261020:[5,11,20,42]}
                var tier_index: int = [1,2,3,42].find(tier) if seed_value in [41,20261020] else 0
                check(plan.removed_ids.size() == expected_counts[seed_value][tier_index],"original standalone construction removal count retained")
            var batch: Array = large.make_refill(plan.removed_ids.size())
            for item in batch:
                if item.match_type == "blue": item.bomb_tier = 2
            var initial := large.checkpoint()
            var immutable := batch.duplicate(true)
            if not current_only and seed_value == 41 and tier == 42:
                check(rows.size() == 11,"derived target follows exact8reuse+3large historical prefix")
                for index in range(derived_witness.expected_prefix_cases.size()):
                    for key in ["seed","removed_ids","before","batch","after","metrics"]:
                        check(equal_json(rows[index][key],derived_witness.expected_prefix_cases[index][key]),"derived prefix full checkpoint/batch/metric preserved: %d/%s" % [index,key])
                check(equal_json(initial,derived_witness.expected_before) and equal_json(batch,derived_witness.expected_batch),"derived target exact immutable before checkpoint and sampled42batch")
                var properties := ["pieces","rng","next_id","version","settling","stable_ticks","elapsed","last_settle_seconds","refill_phase","_recovery_epoch","_recovering","_pending_batch","_pending_openings","last_snapshot","_admitted_count","births"]
                var saved := {}
                for key in properties: saved[key] = large.get(key)
                var bodies: Array = large.pieces.map(func(body): return body.get_instance_id())
                large.set_script(current_audit)
                for key in properties: large.set(key,saved[key])
                check(large.checkpoint() == initial and bodies == large.pieces.map(func(body): return body.get_instance_id()),"derived target current-product swap preserves exact same live bodies/complete state")
                target_switched = true
            large.births.clear()
            large.apply_clear(plan.removed_ids,batch)
            await wait_board(large)
            var result := metrics(large)
            check(result.count == 42 and result.phase == "settled" and result.supported and result.elapsed <= 12 and result.max_overlap < 32,"derived large construction final42 original physical gates")
            check(batch == immutable and large.checkpoint().rng_state == initial.rng_state and large.next_id == initial.next_id,"large union batch/RNG allocated once")
            check(large.births.size() == batch.size(),"large union all actual births once")
            var row := {"kind":"original standalone large construction" if standalone else "derived combined-history large construction","seed":seed_value,"tier":tier,"removed_ids":plan.removed_ids,"removed_count":plan.removed_ids.size(),"metrics":result}
            row["before"] = initial.duplicate(true)
            row["batch"] = immutable.duplicate(true)
            row["after"] = large.checkpoint().duplicate(true)
            row["bodies"] = large.pieces.map(func(p): return {"piece":p.snapshot(),"linear_velocity":[p.linear_velocity.x,p.linear_velocity.y],"angular_velocity":p.angular_velocity,"ccd":p.continuous_cd,"freeze":p.freeze,"sleeping":p.sleeping})
            rows.append(row)
            print(JSON.stringify({"kind":row.kind,"seed":seed_value,"tier":tier,"removed_count":plan.removed_ids.size(),"metrics":result}))
    if not current_only: check(target_switched,"derived target actual product Board applied without restore")
    large.free()
    var evidence := FileAccess.open("res://historical-physical-results.json",FileAccess.WRITE)
    evidence.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":rows},"  ")+"\n")
    print(JSON.stringify({"suite":"v2 current Board historical1.0 standalone large" if standalone else ("v2 current Board historical1.0 mandatory tails" if density_only else "v2 historical mandatory tails and derived all42 target"),"checks":checks,"failures":failures,"cases":rows}))
    quit(0 if failures == 0 else 1)

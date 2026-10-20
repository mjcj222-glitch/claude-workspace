extends SceneTree

const SelectionV2 = preload("res://scripts/v2/selection_rules.gd")
const PreviewSessionV2 = preload("res://scripts/v2/preview_session.gd")
const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Board = preload("res://scripts/v2/board.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func inspect_groups() -> void:
    check(SelectionV2.preview(Fixtures.chain(2), 1, 1).is_empty(), "two ordinary colors are invalid")
    check(SelectionV2.preview(Fixtures.chain(2, "heart"), 1, 1).is_empty(), "two hearts are invalid")
    check(SelectionV2.preview(Fixtures.chain(3), 99, 1).is_empty(), "missing seed is invalid")
    check(SelectionV2.preview(Fixtures.snapshot([]), 1, 1).is_empty(), "empty board is invalid")
    for type in Config.TYPES:
        var snap := Fixtures.chain(4, type)
        snap.version = 17
        snap.pieces.append(Fixtures.tile(19, type, 0, Vector2(2000, 100)))
        var before := snap.duplicate(true)
        var plan := SelectionV2.preview(snap, 2, 23)
        check(plan.get("board_version") == 17 and plan.get("combat_version") == 23 and plan.get("seed_id") == 2,
            "%s preview records both versions and pressed seed" % type)
        check(plan.get("direct_ids") == [1, 2, 3, 4], "%s selects complete connected component without remote same type" % type)
        check(plan.get("removed_ids") == [1, 2, 3, 4] and plan.get("extra_ids") == [], "plain component has no explosion extras")
        check(plan.get("mode") == ("heart" if type == "heart" else "color"), "heart has separate selection mode")
        check(plan.get("direct_color_count") == (0 if type == "heart" else 4), "only direct colors count toward group rewards")
        check(plan.get("fired_bomb_ids") == [] and plan.get("blast_circles") == [], "ordinary pieces create no blasts")
        check(snap == before, "preview preserves original snapshot")
    var branched := Fixtures.snapshot([
        Fixtures.tile(8, "red", 0, Vector2.ZERO),
        Fixtures.tile(2, "red", 0, Vector2(76.5, 0)),
        Fixtures.tile(5, "red", 0, Vector2(-76.5, 0)),
        Fixtures.tile(1, "red", 0, Vector2(0, 76.5)),
        Fixtures.tile(3, "heart", 0, Vector2(0, -76.5)),
        Fixtures.tile(4, "red", 0, Vector2(0, -153))])
    check(SelectionV2.preview(branched, 8, 1).get("direct_ids") == [1, 2, 5, 8], "all contact branches are traversed without crossing a heart bridge")
    var mixed := Fixtures.snapshot([
        Fixtures.tile(3, "yellow", 3, Vector2.ZERO),
        Fixtures.tile(1, "yellow", 1, Vector2.ZERO),
        Fixtures.tile(2, "yellow", 2, Vector2.ZERO)])
    mixed.pieces[0].angle = 0.73
    mixed.pieces[1].size = 0.97
    check(SelectionV2.preview(mixed, 1, 1).get("direct_ids") == [1, 2, 3], "same type matches across distinct rotated and scaled hulls")
    var contact := Fixtures.chain(3)
    contact.pieces[2].x = 153.5
    check(SelectionV2.preview(contact, 1, 1).get("direct_ids") == [1, 2, 3], "one-unit hull gap is included")
    contact.pieces[2].x = 153.51
    check(SelectionV2.preview(contact, 1, 1).is_empty(), "gap beyond one is not remotely joined")

func inspect_bombs() -> void:
    var d := Geometry.diameter_unit()
    for tier in [1, 2, 3]:
        var radius: float = d * Config.BOMB_RADIUS_MULTIPLIERS[tier]
        var snap := Fixtures.snapshot([
            Fixtures.tile(9, "blue", 0, Vector2.ZERO, tier),
            Fixtures.tile(1, "heart", 0, Vector2(radius - 0.01, 0)),
            Fixtures.tile(2, "yellow", 0, Vector2(0, radius)),
            Fixtures.tile(3, "red", 0, Vector2(-radius - 0.01, 0))])
        # Preserve the exact scalar boundary; Vector2 stores float32 coordinates.
        snap.pieces[1].y = radius
        snap.pieces[1].size = 0.97
        snap.pieces[1].angle = 0.6
        var before := snap.duplicate(true)
        var plan := SelectionV2.preview(snap, 9, 4)
        check(plan.get("mode") == "solo_bomb" and plan.get("direct_ids") == [9] and plan.get("direct_color_count") == 0,
            "tier %d isolated bomb is a rewardless solo seed" % tier)
        check(plan.get("extra_ids") == [1, 2] and plan.get("removed_ids") == [1, 2, 9], "tier %d blast includes center inside/on radius and excludes outside center" % tier)
        check(plan.get("fired_bomb_ids") == [9], "each isolated bomb fires once")
        var circles: Array = plan.get("blast_circles", [])
        check(circles.size() == 1, "one bomb produces one preview circle")
        if circles.size() == 1:
            check(circles[0].get("id") == 9 and circles[0].get("x") == 0.0 and circles[0].get("y") == 0.0
                and circles[0].get("radius") == radius, "preview circle exposes exact bomb ID, center and fixed-D radius")
        check(snap == before, "blast calculation leaves original bombs and poses unchanged")
    var pair := Fixtures.chain(2, "blue", {1: 1})
    var solo := SelectionV2.preview(pair, 1, 1)
    check(solo.get("direct_ids") == [1] and solo.get("extra_ids") == [2] and solo.get("direct_color_count") == 0,
        "two blue pieces do not become a direct group when a bomb is pressed")
    check(SelectionV2.preview(pair, 2, 1).is_empty(), "ordinary blue cannot borrow a neighbor bomb's solo exception")
    var blue := SelectionV2.preview(Fixtures.chain(3, "blue", {2: 3}), 2, 1)
    check(blue.get("mode") == "color" and blue.get("direct_ids") == [1, 2, 3] and blue.get("direct_color_count") == 3,
        "bomb in a valid blue group keeps full direct group and color reward count")
    check(blue.get("extra_ids") == [] and blue.get("fired_bomb_ids") == [2], "direct pieces hit by a blast remain direct and never duplicate as extras")
    var chain := Fixtures.snapshot([
        Fixtures.tile(8, "blue", 0, Vector2.ZERO, 2),
        Fixtures.tile(2, "blue", 1, Vector2(1.2 * d, 0), 2),
        Fixtures.tile(5, "blue", 3, Vector2(2.4 * d, 0), 2),
        Fixtures.tile(1, "heart", 2, Vector2(0.6 * d, 0)),
        Fixtures.tile(4, "red", 0, Vector2(2.6 * d, 0)),
        Fixtures.tile(20, "blue", 0, Vector2(6 * d, 0), 3)])
    var plan := SelectionV2.preview(chain, 8, 1)
    check(plan.get("direct_ids") == [8] and plan.get("extra_ids") == [1, 2, 4, 5], "overlapping chain unions targets without recruiting remote bomb")
    check(plan.get("removed_ids") == [1, 2, 4, 5, 8], "overlapping explosions remove every ID exactly once")
    check(plan.get("fired_bomb_ids") == [2, 5, 8], "each existing chained bomb fires once in sorted ID result")
    var circles: Array = plan.get("blast_circles", [])
    var circle_ids: Array = []
    for circle in circles: circle_ids.append(circle.id)
    check(circle_ids == [2, 5, 8], "circles are deterministic and unique by bomb ID")

func inspect_sessions() -> void:
    var shown := {"board_version": 1, "combat_version": 7, "seed_id": 1,
        "mode": "color", "direct_ids": [1, 2, 3], "extra_ids": [], "removed_ids": [1, 2, 3],
        "direct_color_count": 3, "fired_bomb_ids": [], "blast_circles": []}
    var session = PreviewSessionV2.new()
    check(not session.begin({}, 1), "empty preview cannot start a session")
    check(session.release(1, true, 1, 7).is_empty(), "release without preview does nothing")
    check(session.begin(shown, 1), "valid shown preview starts session")
    session.move(1, true)
    check(not session.begin(SelectionV2.preview(Fixtures.chain(4), 2, 7), 2), "second pointer cannot replace displayed plan")
    session.move(2, false)
    check(session.release(2, false, 1, 7).is_empty(), "second pointer release is ignored")
    check(session.release(1, true, 1, 7) == shown, "inside movement and foreign pointer keep original plan authoritative")
    check(session.release(1, true, 1, 7).is_empty(), "preview can be consumed only once")
    var before := shown.duplicate(true)
    check(session.begin(shown, 3), "new press starts after prior release")
    shown.direct_ids.append(99)
    shown.blast_circles.append({"id": 99, "x": 1.0, "y": 2.0, "radius": 3.0})
    check(session.release(3, true, 1, 7) == before, "session owns a deep copy of the last displayed plan")
    shown = before
    for mismatch in [Vector2i(2, 7), Vector2i(1, 8)]:
        session.begin(shown, 1)
        check(session.release(1, true, mismatch.x, mismatch.y).is_empty(), "stale board or combat version cancels")
        check(session.release(1, true, 1, 7).is_empty(), "stale release cannot be retried")
    session.begin(shown, 1)
    session.move(1, false)
    session.move(1, true)
    check(not session.begin(shown, 2), "second pointer cannot restart an outside-cancelled held session")
    check(session.release(2, true, 1, 7).is_empty(), "foreign release cannot consume outside-cancelled session")
    check(session.release(1, true, 1, 7).is_empty(), "outside movement remains cancelled after reentry")
    session.begin(shown, 1)
    check(session.release(1, false, 1, 7).is_empty(), "outside release cancels even without earlier move")
    for reason in ["focus loss", "OS cancellation", "window resize"]:
        session.begin(shown, 1)
        session.cancel()
        session.move(1, true)
        check(session.release(1, true, 1, 7).is_empty(), "%s cancels held plan" % reason)
    session.cancel()
    check(session.begin(shown, 1) and session.release(1, true, 1, 7) == shown, "cancellation permits a fresh press")

func inspect_purity() -> void:
    var board = Board.new()
    board.rng.seed = 20261020
    board.make_refill(3)
    var before: Dictionary = board.checkpoint()
    var snapshot := Fixtures.chain(3)
    var original := snapshot.duplicate(true)
    var plan := SelectionV2.preview(snapshot, 1, 1)
    var session = PreviewSessionV2.new()
    for i in range(20):
        check(SelectionV2.preview(Fixtures.chain(2), 1, 1).is_empty(), "invalid selection stays invalid on repeat")
        check(SelectionV2.preview(snapshot, 1, 1) == plan, "preview is deterministic")
        session.begin(plan, 1)
        session.cancel()
        check(session.release(1, true, 1, 1).is_empty(), "cancelled preview has no action")
    check(snapshot == original and board.checkpoint() == before, "preview and invalid/cancelled input consume no board RNG, IDs or state")
    seed(98123)
    var expected := randi()
    seed(98123)
    SelectionV2.preview(snapshot, 1, 1)
    SelectionV2.preview(Fixtures.chain(2), 1, 1)
    session.begin(plan, 1)
    session.cancel()
    check(randi() == expected, "preview and cancel consume no global RNG")
    board.free()

func run() -> void:
    inspect_groups()
    inspect_bombs()
    inspect_sessions()
    inspect_purity()
    print(JSON.stringify({"suite": "v2 authoritative selection", "checks": checks, "failures": failures}))
    quit(0 if failures == 0 else 1)

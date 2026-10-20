extends SceneTree
## Measured natural contacts and pure threshold fixtures. Frozen replays are NOT normal wins.
const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Selection = preload("res://scripts/v2/selection_rules.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const Effects = preload("res://scripts/v2/board_effects.gd")
const NativeInput = preload("res://tools/native_input.gd")
const Fixtures = preload("res://tests/v2/fixtures.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ",message)
func gap(snapshot: Dictionary, a: int, b: int) -> float:
    var polygons := {}
    for piece in snapshot.pieces:
        if int(piece.id) in [a,b]: polygons[int(piece.id)] = Geometry.transformed(Geometry.polygon(int(piece.hull_id),float(piece.size)),Vector2(piece.x,piece.y),float(piece.angle))
    return Geometry.distance(polygons[a],polygons[b])
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args():
        check(false,"test requires explicit --no-save")
        quit(1)
        return
    var config_script: Script = load("res://scripts/v2/config.gd")
    var constants: Dictionary = config_script.get_script_constant_map()
    check(constants.get("MATCH_CONTACT_EPS",-1.0) == 1.75,"measured match-only margin is1.75 logical pixels")
    check(Config.CONTACT_EPS == 1.0 and Config.BOUNDARY_SLOP == 0.8 and Config.SETTLE_TIMEOUT == 12.0,"physical support/bounds/deadline constants are unchanged")
    var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v2/visible_contact_snapshots.json"))
    if "--pixels-only" in OS.get_cmdline_user_args():
        await pixel_checks(recorded)
        print(JSON.stringify({"suite":"v2 actual contact pixels","checks":checks,"failures":failures}))
        quit(0 if failures == 0 else 1)
        return
    for name in ["controller_commit","actual_release"]:
        var snapshot: Dictionary = recorded[name]
        var before := snapshot.duplicate(true)
        var d := gap(snapshot,9,14)
        check(d > 1.0 and d < 1.75,"measured natural red9/14 gap lies between physical and matching thresholds")
        for id in [8,9,14]:
            var plan := Selection.preview(snapshot,id,1)
            check(plan.get("direct_ids",[]) == [8,9,14] and plan.get("removed_ids",[]) == [8,9,14],"visibly continuous natural red component is the same full3 from every seed: "+name+"/"+str(id))
            check(not plan.get("removed_ids",[]).has(19),"truly separated same-red19 stays excluded")
        check(Selection.preview(snapshot,19,1).is_empty(),"remote red19 remains invalid instead of remote linking")
        check(Selection.preview(snapshot,5,1).is_empty() and Selection.preview(snapshot,6,1).is_empty(),"joined blue pair still fails MIN_GROUP3")
        var state := Combat.fresh({"enemy_id":"gate","party":["hero"],"hero_limit":3})
        var hero := Skills.preview(snapshot,state,"hero",9,"yellow")
        var changed: Array = hero.get("changes",{}).keys()
        changed.sort()
        check(changed == [8,9,14],"hero source BFS shares visible match adjacency")
        check(snapshot == before,"all current-board previews preserve complete natural snapshot")
        var physical := Geometry.graph(snapshot)
        check(not physical[9].has(14),"default graph retains physical1.0 and excludes red gap")
        print(JSON.stringify({"natural_fixture":name,"red9_14_gap":d,"blue5_6_gap":gap(snapshot,5,6),"red19_8_gap":gap(snapshot,19,8),"red8_9_gap":gap(snapshot,8,9)}))
    var initial: Dictionary = recorded.initial
    var initial_gap := gap(initial,35,34)
    check(absf(initial_gap-2.09780525232407) < 0.0001 and initial_gap > 1.75,"original first35/34 case stays beyond total1.75 edge-gap threshold")
    var initial_plan := Selection.preview(initial,35,1)
    check(initial_plan.get("direct_ids",[]) == [17,18,24,30,35,36] and not initial_plan.get("removed_ids",[]).has(34),"original first selected35 excludes separate34; selected outline never adds adjacency")
    check(Selection.preview(initial,34,1).is_empty(),"original first34 remains below minimum group rather than remote-linked")
    var controller: Dictionary = recorded.controller_commit
    check(gap(controller,5,6) > 1.0 and gap(controller,5,6) < 1.75,"measured blue5/6 case exercises added adjacency margin")
    check(gap(controller,42,29) > 1.75,"nearby yellow42/29 remains a separated negative control")
    threshold_fixtures()
    irregular_threshold_fixtures()
    contained_outline_fixture()
    await live_fixture(recorded.actual_release)
    print(JSON.stringify({"suite":"v2 measured visible contacts","checks":checks,"failures":failures}))
    quit(0 if failures == 0 else 1)
func threshold_fixtures() -> void:
    var diameter := Fixtures.circle_diameter()
    for example in [{"gap":1.749,"valid":true},{"gap":1.751,"valid":false},{"gap":3.0,"valid":false}]:
        var x := 100.0+diameter+float(example.gap)
        var snapshot := Fixtures.snapshot([Fixtures.tile(1,"red",0,Vector2(100,100)),Fixtures.tile(2,"red",0,Vector2(x,100)),Fixtures.tile(3,"red",0,Vector2(x+diameter+0.5,100))])
        var measured := gap(snapshot,1,2)
        check(absf(measured-float(example.gap)) < 0.0001,"boundary fixture measures intended margin±0.001")
        var plan := Selection.preview(snapshot,1,1)
        check((not plan.is_empty()) == bool(example.valid),"TOTAL polygon-edge threshold±epsilon (not per-piece3.5) has correct side: "+str(example.gap))
        check(not Geometry.graph(snapshot)[1].has(2),"match-only threshold never changes default physical graph")
    var ordinary := Fixtures.snapshot([
        Fixtures.tile(1,"red",0,Vector2(100,200)),
        Fixtures.tile(2,"yellow",0,Vector2(100+diameter+1.5,200)),
        Fixtures.tile(3,"blue",0,Vector2(100+2*diameter+2.0,200)),
        Fixtures.tile(4,"red",0,Vector2(100+3*diameter+2.5,200))])
    var gardener_state := Combat.fresh({"enemy_id":"gate","party":["hero","gardener"],"energy":4,"hero_limit":3})
    var gardener := Skills.preview(ordinary,gardener_state,"gardener",1)
    var gardener_ids: Array = gardener.get("changes",{}).keys()
    gardener_ids.sort()
    check(gardener_ids == [1,2,3] and not gardener_ids.has(4),"gardener crosses same bounded1.75 margin but keeps selected+2 cap, excluding fourth")
    # Bomb blast circle membership remains an independent fixed-D rule.
    var radius := Geometry.diameter_unit()
    var blast := Fixtures.snapshot([Fixtures.tile(1,"blue",0,Vector2(100,100),1),Fixtures.tile(2,"heart",0,Vector2(100+radius+0.25,100))])
    check(Selection.preview(blast,1,1).removed_ids == [1],"match margin is not added to bomb blast radius")
func ready(owner: Node) -> bool:
    for frame in range(3000):
        if owner.phase == "READY": return true
        if owner.phase == "ERROR": return false
        await process_frame
    return false
func point(owner: Node, id: int) -> Vector2:
    return owner.view.get_node("BoardViewport").board_to_logical(owner.board.by_id(id).position)
func fingerprint(owner: Node) -> Dictionary:
    return {"state":owner.state.duplicate(true),"board":owner.board.checkpoint(),"actions":owner.action_count,"refills":owner.refill_batch_count}
func live_fixture(snapshot: Dictionary) -> void:
    var owner = load("res://scenes/v2/battle.tscn").instantiate()
    root.add_child(owner)
    owner.start_battle({"enemy_id":"gate","seed":121,"party":["hero"],"hero_limit":3})
    check(await ready(owner),"live fixture initial physical board ready")
    var checkpoint: Dictionary = owner.export_checkpoint()
    checkpoint.board.snapshot = snapshot.duplicate(true)
    checkpoint.board.next_id = 49
    owner.restore_checkpoint(checkpoint)
    check(await ready(owner),"recorded natural42 frozen fixture restores without physical changes")
    var initial := fingerprint(owner)
    owner._press(point(owner,9),37)
    var displayed: Dictionary = owner.displayed_plan.duplicate(true)
    check(displayed.get("direct_ids",[]) == [8,9,14],"actual controller press shows entire visible3 and excludes remote19")
    owner._move(Vector2(360,500),37)
    owner._move(point(owner,9),37)
    owner._release(point(owner,9),37)
    check(fingerprint(owner) == initial,"outside/reentry cancels new match without cost/RNG/pose changes")
    owner._press(point(owner,9),37)
    owner.state.revision += 1 # Explicit stale-combat fixture, never a normal win.
    var stale := fingerprint(owner)
    owner._release(point(owner,9),37)
    check(fingerprint(owner) == stale,"stale combat version cancels new match without charge")
    owner._press(point(owner,9),37)
    owner.board.version += 1 # Explicit stale-board fixture.
    stale = fingerprint(owner)
    owner._release(point(owner,9),37)
    check(fingerprint(owner) == stale,"stale board version cancels new match without RNG")
    owner.snapshot = owner.board.capture()
    var before_skill := fingerprint(owner)
    var hero: Vector2 = owner.view.get_node("Party/Hero").get_global_rect().get_center()
    owner._press(hero,37)
    owner._release(hero,37)
    await process_frame
    var destination: Vector2 = owner.view.get_node("Bars/Destinations/Yellow").get_global_rect().get_center()
    owner._press(destination,37)
    owner._release(destination,37)
    owner._press(point(owner,9),37)
    var skill_ids: Array = owner.displayed_plan.get("changes",{}).keys()
    skill_ids.sort()
    check(skill_ids == [8,9,14],"actual hero target uses measured visible component")
    owner._release(point(owner,9),37)
    check(await ready(owner),"actual hero cutin returns")
    var after_skill := fingerprint(owner)
    check(owner.state.energy == before_skill.state.energy-4 and owner.state.actions_left == before_skill.state.actions_left,"hero match costs4 and no action")
    check(after_skill.board.rng_state == before_skill.board.rng_state,"new matching margin does not consume owner RNG on skill")
    for piece in before_skill.board.snapshot.pieces:
        var body = owner.board.by_id(int(piece.id))
        check(body.hull_id == int(piece.hull_id) and body.size_factor == float(piece.size) and body.position == Vector2(piece.x,piece.y) and body.rotation == float(piece.angle),"matching/skill preserves actual hull size pose")
    check(not owner.commit_preview(displayed) and fingerprint(owner) == after_skill,"pre-skill displayed match cannot replay after version boundary")
    owner.queue_free()
    await process_frame

func contained_outline_fixture() -> void:
    var effects = Effects.new()
    root.add_child(effects)
    for hull in range(4):
        var piece := Fixtures.tile(1,"red",hull,Vector2(240,240))
        piece.angle = 0.63
        piece.size = 0.97
        var snapshot := Fixtures.snapshot([piece])
        effects.show_selection(snapshot,{"direct_ids":[1]})
        var outer := Geometry.transformed(Geometry.polygon(hull,0.97),Vector2(240,240),0.63)
        var contained: bool = not effects.direct_contours.is_empty()
        var clearance := INF
        for contour in effects.direct_contours:
            for at in contour:
                contained = contained and Geometry2D.is_point_in_polygon(at,outer)
                for index in range(outer.size()):
                    clearance = minf(clearance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,outer[index],outer[(index+1)%outer.size()])))
        check(contained and clearance >= 5.5,"rotated hull selection centerline reserves widest stroke+AA inside hull: "+str(hull))
    effects.queue_free()

func frames(count: int) -> void:
    for frame in range(count): await process_frame
func pixels(path: String) -> Image:
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    check(image.save_png(path) == OK,"actual native PNG writes")
    return image
func channel_delta(a: Color, b: Color) -> float:
    return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))*255.0
func pixel_checks(recorded: Dictionary) -> void:
    var output := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
    check(DisplayServer.get_name() != "headless" and not output.is_empty(),"pixel verification requires graphical window and fresh output")
    if DisplayServer.get_name() == "headless" or output.is_empty(): return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var records: Array = []
    for size_value in [Vector2i(360,640),Vector2i(720,1280)]:
        root.size = size_value
        await frames(12)
        for fixture_name in ["initial","actual_release"]:
            var owner = load("res://scenes/v2/battle.tscn").instantiate()
            root.add_child(owner)
            owner.start_battle({"enemy_id":"hall1","seed":121,"party":["hero"],"hero_limit":3})
            check(await ready(owner),"pixel fixture initial physical board ready")
            var cp: Dictionary = owner.export_checkpoint()
            cp.board.snapshot = recorded[fixture_name].duplicate(true)
            cp.board.next_id = 43 if fixture_name == "initial" else 49
            owner.restore_checkpoint(cp)
            check(await ready(owner),"exact recorded natural42 poses restored for paired pixel proof")
            await frames(4)
            var excluded := 34 if fixture_name == "initial" else 19
            var selected := 35 if fixture_name == "initial" else 9
            var prefix: String = fixture_name+"-"+str(size_value.x)+"x"+str(size_value.y)
            var before := fingerprint(owner)
            for body in owner.board.pieces: body.hide()
            var empty := await pixels(output+"/"+prefix+"-mask-background.png")
            owner.board.by_id(excluded).show()
            var alone := await pixels(output+"/"+prefix+"-excluded-alone.png")
            for body in owner.board.pieces: body.show()
            var clean := await pixels(output+"/"+prefix+"-clean.png")
            NativeInput.touch(root,point(owner,selected),true)
            await frames(4)
            var plan: Dictionary = owner.displayed_plan.duplicate(true)
            check(plan.get("direct_ids",[]) == ([17,18,24,30,35,36] if fixture_name == "initial" else [8,9,14]),"actual injected pointer displays entire expected component")
            check(not plan.get("removed_ids",[]).has(excluded),"excluded first34/far19 never enters displayed plan")
            var pressed := await pixels(output+"/"+prefix+"-pressed.png")
            check(clean.get_size() == size_value and pressed.get_size() == size_value,"decoded contact proof uses actual native resolution")
            var painted := 0
            var mask_pixels := 0
            var changed_board := 0
            for y in range(clean.get_height()):
                for x in range(clean.get_width()):
                    if channel_delta(empty.get_pixel(x,y),alone.get_pixel(x,y)) > 32:
                        mask_pixels += 1
                        if channel_delta(clean.get_pixel(x,y),pressed.get_pixel(x,y)) > 8: painted += 1
                    if y >= roundi(float(size_value.y)*550.0/1280.0) and channel_delta(clean.get_pixel(x,y),pressed.get_pixel(x,y)) > 8: changed_board += 1
            check(mask_pixels > 50 and painted == 0,"selection adds zero ink to substantial actual excluded-body pixels")
            check(changed_board > 20,"selected component remains visibly marked")
            var gap_delta := 0.0
            if fixture_name == "initial":
                var gap_pixel := Vector2i(240,391) if size_value.x == 360 else Vector2i(480,782)
                gap_delta = channel_delta(clean.get_pixelv(gap_pixel),pressed.get_pixelv(gap_pixel))
                check(gap_delta <= 8,"original first34/35 true background gap remains clean after press")
            check(fingerprint(owner) == before,"pixel selection preserves all resources RNG hulls poses colliders")
            NativeInput.touch(root,point(owner,selected),false,0,true)
            await frames(4)
            check(fingerprint(owner) == before and owner.displayed_plan.is_empty(),"pixel proof cancel preserves owner")
            records.append({"fixture":fixture_name,"window":[size_value.x,size_value.y],"source":"actual engine-injected pointer; recorded natural42 frozen replay, not a normal win","displayed_ids":plan.get("direct_ids",[]),"excluded_id":excluded,"excluded_strong_mask_pixels":mask_pixels,"painted_excluded_pixels":painted,"first_gap_delta":gap_delta,"visible_changed_board_pixels":changed_board,"files":[prefix+"-clean.png",prefix+"-pressed.png"]})
            owner.queue_free()
            await frames(2)
    var file := FileAccess.open(output+"/contact-pixel-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  ")+"\n")
    print(JSON.stringify({"contact_pixels":records}))

func irregular_threshold_fixtures() -> void:
    for target in [1.749,1.751]:
        var a := Fixtures.tile(1,"red",2,Vector2(100,240))
        a.angle = 0.63
        a.size = 0.97
        var b := Fixtures.tile(2,"red",3,Vector2(200,240))
        b.angle = -0.41
        b.size = 1.02
        var low := 100.0
        var high := 300.0
        for iteration in range(30):
            b.x = (low+high)*0.5
            var pair := Fixtures.snapshot([a,b])
            if gap(pair,1,2) < target: low = float(b.x)
            else: high = float(b.x)
        var snapshot := Fixtures.snapshot([a,b,Fixtures.tile(3,"red",0,Vector2(float(b.x)+50,240))])
        var distance := gap(snapshot,1,2)
        check(absf(distance-target) < 0.0001,"rotated star/leaf fixture measures total boundary±epsilon")
        var plan := Selection.preview(snapshot,1,1)
        check((plan.get("direct_ids",[]) == [1,2,3]) == (target < 1.75),"rotated irregular match boundary uses total1.75 only")
        check(Geometry.graph(snapshot,distance)[1].has(2),"explicit graph margin includes exact measured irregular boundary")
        check(not Geometry.graph(snapshot,distance-0.0001)[1].has(2),"explicit graph margin excludes just beyond irregular boundary")
        check(not Geometry.graph(snapshot)[1].has(2),"rotated physical graph stays at1.0")

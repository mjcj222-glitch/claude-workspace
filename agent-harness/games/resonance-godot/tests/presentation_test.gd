extends SceneTree
var battle: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    battle = load("res://scenes/battle.tscn").instantiate()
    root.add_child(battle)
    for child in battle.get_children():
        if child is TextureRect:
            check(child.size==Vector2(720,390),"storybook backdrop stays out of the neutral puzzle area")
    var hero: Node = battle.get("heroine")
    check(hero!=null,"the battle contains the supplied full-body heroine")
    if hero == null: quit(1); return
    var foot: Vector2 = hero.position
    for pose in ["idle","windup","strike"]:
        hero.set_pose(pose)
        check(hero.sprite.texture.get_size()==Vector2(1254,1254),"original full-canvas texture is preserved")
        check(hero.sprite.to_global(hero.anchors[pose]).distance_to(foot)<0.1,"planted foot stays aligned for "+pose)
        check(absf(hero.body_heights[pose]*hero.sprite.scale.y-hero.display_body_height)<0.1,"body height is consistent")
    var stages: Array = []
    hero.pose_changed.connect(func(pose): stages.append(pose))
    await hero.attack()
    check(stages==["windup","strike","recover","idle"],"one attack has windup, strike and recovery")
    check(hero.pose=="idle","attack returns to idle")
    var fx: Node = battle.effects
    fx.clear_all()
    fx.preview([Vector2(90,900)],Color.WHITE)
    check(fx.preview_points.size()==1 and fx.get_child_count()==0,"preview is persistent and does not spawn a particle storm")
    for strength in [1,2]:
        fx.burst(Vector2(120,900),Color.WHITE,strength)
    fx.hit(Vector2(510,210),Color.WHITE)
    fx.skill(Vector2(300,900),Color.WHITE)
    check(fx.get_child_count()==4,"clear, mega, hit and skill produce distinct textured emitters")
    for emitter in fx.get_children():
        check(emitter.texture.resource_path.begins_with("res://assets/kenney-particles/"),"effect uses the local licensed Kenney texture")
    battle.set_reduced(true)
    for frame in range(2): await process_frame
    check(fx.get_child_count()==0 and fx.rings.is_empty() and fx.pulses.is_empty(),"reduced motion clears running effects")
    fx.burst(Vector2.ZERO,Color.WHITE,2)
    fx.skill(Vector2.ZERO,Color.WHITE)
    check(fx.get_child_count()==0,"reduced motion suppresses new emitters")
    stages.clear()
    await hero.attack()
    check(hero.pose=="idle" and stages.is_empty(),"reduced motion keeps the hero still")
    battle.set_reduced(false)
    for tick in range(1800):
        await physics_frame
        if battle.phase=="READY": break
    battle.state.taps = 1
    battle.commit(int(battle.snapshot[0].id))
    await create_timer(0.25).timeout
    check(battle.board.selected_ids.is_empty() and fx.preview_links.is_empty(),"connection lines disappear with the burst, before the hero attack")
    for tick in range(1800):
        await physics_frame
        if battle.phase in ["READY","ERROR"]: break
    check(battle.phase=="READY","presentation sequence returns to a playable board")
    print(JSON.stringify({"suite":"presentation","checks":checks,"failures":failures}))
    quit(0 if failures==0 else 1)

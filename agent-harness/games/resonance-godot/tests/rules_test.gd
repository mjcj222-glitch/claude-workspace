extends SceneTree
const Geometry = preload("res://scripts/piece_geometry.gd")
const Rules = preload("res://scripts/combat_rules.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)
func _initialize() -> void:
    for kind in range(4):
        for size_value in [0.96,1.0,1.04]:
            var poly := Geometry.polygon(kind,size_value)
            check(Geometry.area(poly)>3000,"shape has meaningful area")
            check(Geometry2D.is_point_in_polygon(Vector2.ZERO,poly),"center touch")
            check(not Geometry2D.is_point_in_polygon(Vector2(58,58),poly),"empty corner rejected")
            var max_x := 0.0
            for p in poly: max_x = maxf(max_x,p.x)
            for angle in [0.0,0.38,-0.9]:
                var a := Geometry.transformed(poly,Vector2.ZERO,angle)
                var near := Geometry.transformed(poly,Vector2(2*max_x+0.5,0).rotated(angle),angle)
                var far := Geometry.transformed(poly,Vector2(2*max_x+2.0,0).rotated(angle),angle)
                check(Geometry.distance(a,near)<=Geometry.CONTACT_EPS,"rotated near edge joins")
                check(Geometry.distance(a,far)>Geometry.CONTACT_EPS,"rotated gap does not join")
    var snapshot: Array = []
    var edges := {}
    for i in range(42):
        snapshot.append({"id":i+1,"color":0 if i<8 else 3,"kind":"normal","size":1.0,"x":float(i*80),"y":100.0,"angle":0.0})
        edges[i+1] = []
        if i>0: edges[i+1].append(i)
        if i<41: edges[i+1].append(i+2)
    var state := Rules.fresh()
    var p := Rules.preview(snapshot,edges,1,state)
    check(p.initial.size()==8 and p.special.kind=="mega","direct eight creates one mega")
    check(p.bombs==0 and p.megas==0,"new special cannot recurse")
    check(p.damage==40,"new special has no creation-tap damage")
    check(p.removed.size()==8,"preview IDs are unique")
    var original := JSON.stringify(snapshot)
    Rules.preview(snapshot,edges,1,state)
    check(JSON.stringify(snapshot)==original,"preview does not mutate snapshot")
    snapshot[0].kind = "bomb"
    snapshot[8].color = 2
    state.echo = [9,30]
    p = Rules.preview(snapshot,edges,1,state)
    check(not p.echo_hit,"explosion-only echo contact does not trigger all marks")
    check(not p.removed.has(30),"remote mark survives explosion-only hit")
    state.echo = [1,30]
    p = Rules.preview(snapshot,edges,1,state)
    check(p.echo_hit and p.removed.has(30),"initial group echo triggers prior marks")
    state = Rules.fresh()
    var old_taps: int = state.taps
    Rules.apply_skill(state,0)
    Rules.apply_skill(state,1)
    Rules.apply_skill(state,2)
    check(state.taps==old_taps,"three ready skills consume no taps")
    check(state.ready==[4,4,4],"three-turn cooldown")
    state = Rules.fresh()
    state.taps = 1
    state.hp = 20
    state.shield = 18
    var heal_plan := {"damage":0,"healing":12,"echo":[],"prism_bonus":0,"ignition_bonus":0,"removed":[1,2]}
    var result := Rules.apply(state,heal_plan)
    check(state.hp==32 and result.attack==0 and result.blocked==14,"healing and shield settle before retaliation")
    check(SaveStore.decode('{}').is_empty(),"missing save fields rejected")
    check(SaveStore.decode('{"version":2}').is_empty(),"unknown save version rejected")
    print(JSON.stringify({"suite":"geometry and snapshot combat","checks":checks,"failures":failures}))
    quit(0 if failures==0 else 1)

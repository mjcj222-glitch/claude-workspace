extends SceneTree
## Explicit edge fixtures: isolate a legitimate group under a departing control.
## Normal completion/earning is verified separately without injected panels.
var checks := 0
var failures := 0
func check(ok:bool,label:String)->void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)
func _initialize()->void: call_deferred("run")
func mouse(scene,p:Vector2,down:bool,double:bool=false)->void:
	var e:=InputEventMouseButton.new()
	e.position=p
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=down
	e.double_click=double
	scene._input(e)
func touch(scene,p:Vector2,down:bool)->void:
	var e:=InputEventScreenTouch.new()
	e.position=p
	e.index=0
	e.pressed=down
	scene._input(e)
func depart(scene,kind:String,input_kind:String)->Vector2:
	scene.reset_board();preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	scene.record_timings=false
	scene.sound.muted=true
	var s=scene.session
	s.phase=kind
	s.combat.enemy_hp=0
	s.combat.enemies_defeated=1 if kind=="route" else 2
	s.combat.encounter=0 if kind=="route" else 1
	s.rewards_taken=1 if kind=="route" else 2
	s.relics=["pigment"] if kind=="route" else ["pigment","lens"]
	s.route="" if kind=="route" else "elite"
	s.gold=4 if kind=="route" else 12
	var p:Vector2=scene.UI.route_rect(0).get_center() if kind=="route" else scene.UI.SUMMARY_CONTINUE.get_center()
	if input_kind=="mouse":
		mouse(scene,p,true)
		mouse(scene,p,false)
	else:
		touch(scene,p,true)
		touch(scene,p,false)
	check(s.phase=="ready" and s.combat.encounter==(1 if kind=="route" else 2),kind+" first "+input_kind+" gesture enters next fight")
	var world:Vector2=scene.screen_to_board(p)
	s.panels=[{"id":1000,"pos":world,"radius":37.0,"color":0,"kind":"normal"},{"id":1001,"pos":world+Vector2(74,0),"radius":37.0,"color":0,"kind":"normal"}]
	s.next_id=1002
	scene.visual=s.panels.duplicate(true)
	check(s.plan_for(1000).valid,"explicit under-control group is a legal clear")
	return p
func run()->void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	scene.set_process(false)
	await process_frame
	for kind in ["route","shop"]:
		for input_kind in ["mouse","touch"]:
			var p:Vector2=depart(scene,kind,input_kind)
			if input_kind=="mouse":
				mouse(scene,p,true,true)
				mouse(scene,p,false)
			else:
				touch(scene,p,true)
				touch(scene,p,false)
			check(scene.session.actions==0 and scene.session.phase=="ready" and scene.session.selection.is_empty(),kind+" immediate second "+input_kind+" gesture cannot clear underlying board")
			# A different target is available immediately: this is not a board lock.
			var other:Vector2=p+Vector2(74,0)
			mouse(scene,other,true)
			mouse(scene,other,false)
			check(scene.session.actions==1 and scene.session.phase=="busy",kind+" permits different target immediately")
	if scene.get("transition_repeat_until_ms")!=null:
		var p:Vector2=depart(scene,"route","mouse")
		scene.transition_repeat_until_ms=0
		mouse(scene,p,true)
		mouse(scene,p,false)
		check(scene.session.actions==1,"same position works after repeat window expires")
		p=depart(scene,"route","mouse")
		scene.reset_board()
		check(scene.session.phase=="departure" and scene.transition_repeat_until_ms==0,"restart clears repeat guard")
	scene.queue_free()
	await process_frame
	await process_frame
	print("TRANSITION_REENTRY checks=",checks," failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:
	var path:="res://scripts/board_skill_presentation.gd"
	check(ResourceLoader.exists(path),"real gameplay skill-state presenter exists")
	if not failures.is_empty():finish();return
	var presenter=load(path).new()
	var session=load("res://scripts/board_run_session.gd").new()
	var cases: Array=[
		[3,3,"ready",false,true,"준비"],
		[0,3,"ready",false,false,"충전"],
		[1,3,"ready",false,false,"충전"],
		[1,2,"ready",false,false,"충전"],
		[2,2,"ready",false,true,"준비"],
		[3,3,"busy",false,false,"대기"],
		[3,3,"reward",false,false,"대기"],
		[3,3,"shop",false,false,"대기"],
		[3,3,"ready",true,false,"대기"]]
	for item in cases:
		session.charge=item[0];session.charge_required=item[1];session.phase=item[2]
		var before: Array=[session.charge,session.charge_required,session.phase,session.actions,session.relics.duplicate()]
		var info: Dictionary=presenter.call("snapshot",session,item[3])
		check(info.illuminated==item[4] and info.status_text==item[5],"illumination follows actual availability")
		check(info.charge_text=="%d / %d"%[item[0],item[1]] and info.requirement==item[1],"exact dynamic charge including Ash2")
		check(before==[session.charge,session.charge_required,session.phase,session.actions,session.relics],"drawing state does not mutate gameplay")
	session.phase="ready";session.charge=3;session.charge_required=3;session.skill_mode=true
	check(presenter.call("snapshot",session,false).illuminated,"entering targeting leaves ready illumination")
	session.cancel();session.skill_mode=false
	check(presenter.call("snapshot",session,false).illuminated,"cancel does not consume ready state")
	session.relics=["pigment"];session.ash_reserved=true
	var info: Dictionary=presenter.call("snapshot",session,false)
	check(info.conversion_max==5 and info.reservation_text!="","owned effects described from current state")
	finish()
func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

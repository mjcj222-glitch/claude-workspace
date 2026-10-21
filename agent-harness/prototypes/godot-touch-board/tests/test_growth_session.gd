extends SceneTree
const Session=preload("res://scripts/board_session.gd")
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func fixture(s,count:int,kind:String="normal")->void:
	s.bounds=Rect2(0,0,2000,500)
	s.panels=[]
	for i in range(count):s.panels.append({"id":i+100,"pos":Vector2(80+i*74,100),"radius":37.0,"color":4 if kind=="heart" else 0,"kind":kind})
func clear(s,count:int=2,kind:String="normal")->Dictionary:
	fixture(s,count,kind)
	s.begin(Vector2(80,100),0)
	var result:Dictionary=s.release(Vector2(80,100),0)
	check(not result.is_empty(),"fixture valid manual clear")
	s.finish_refill()
	return result
func skill(s)->Dictionary:
	fixture(s,6)
	s.skill_mode=true
	s.skill_color=2
	s.begin(Vector2(80,100),0)
	var preview:Dictionary=s.selection.duplicate(true)
	var result:Dictionary=s.release(Vector2(80,100),0)
	check(result==preview,"skill executes frozen recharge plan")
	return result
func _init()->void:
	var s=Session.new()
	check(s.charge==3 and s.charge_required==3,"initial skill ready")
	for i in range(3):clear(s)
	check(s.phase=="reward" and s.reward_options.size()==3,"first reward after third completed action")
	check(not s.begin(Vector2(80,100),0),"reward blocks board")
	var serial:int=s.offer_serial
	check(s.choose_relic("lens",serial),"first choice commits")
	check(not s.choose_relic("lens",serial),"duplicate choice rejected")
	for i in range(3):clear(s,2,"heart" if i==0 else "normal")
	check(s.phase=="reward" and s.reward_options.size()==2 and "lens" not in s.reward_options,"second options exclude owned")
	check(not s.choose_relic("ash",serial),"stale first offer rejected")
	check(s.choose_relic("ash",s.offer_serial),"second distinct choice")
	for i in range(3):clear(s)
	check(s.phase=="summary" and s.relics.size()==2,"ninth action summary")
	for stage in s.stats:check(stage.actions==3 and stage.removed==6 and stage.cores==0,"three-stage accounting")
	s.continue_summary()
	clear(s,1,"core")
	check(s.phase=="ready" and s.actions==10,"standalone core counts; no further rewards")
	check(s.stats[2].actions==3,"summary buckets freeze after ninth")
	# Unit fixtures below intentionally set relics/charge; natural-play test never does.
	s=Session.new();s.relics=["ash","lens"];s.charge=0
	clear(s,5)
	check(not s.ash_reserved,"lens five does not reserve ash")
	clear(s,6)
	check(s.ash_reserved and s.charge==2 and s.charge_required==3,"reservation does not retroactively reduce recharge")
	clear(s,6)
	# This fixture skips offers only to isolate recharge; no valid reward claimed.
	s.phase="ready"
	check(s.ash_reserved and s.charge==3,"reservation never stacks or overcharges")
	var before:int=s.actions
	skill(s)
	check(s.charge==0 and s.charge_required==2 and not s.ash_reserved,"next skill consumes single two-clear reservation")
	check(s.actions==before,"skill does not count or charge")
	clear(s);check(s.charge==1,"first reduced recharge")
	clear(s);check(s.charge==2,"second reduced recharge ready")
	clear(s);s.phase="ready";check(s.charge==2,"recharge capped at current requirement")
	skill(s)
	check(s.charge_required==3 and s.charge==0,"following unreserved use restores requirement three")
	var fresh=Session.new()
	check(fresh.relics.is_empty() and fresh.reward_round==0 and fresh.charge_required==3 and fresh.charge==3 and not fresh.ash_reserved and fresh.stats[0].actions==0,"new session resets all growth state")
	print("GROWTH_SESSION failures=",failures)
	quit(1 if failures else 0)

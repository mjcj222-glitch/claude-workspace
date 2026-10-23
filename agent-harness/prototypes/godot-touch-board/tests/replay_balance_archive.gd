extends "res://tests/play_elemental.gd"
## Strict archived legal input replay. Stop explicitly if changed contacts alter a plan.
const SOURCE="res://evidence/balance/baseline/seed20261023-elite-pair0-avoid-intent.json"
const OUTPUT="res://evidence/refill-stall/archive-replay.json"
var report:Dictionary={"source":SOURCE,"clears":[],"status":"pending","full_sequence_conclusive":false}
func finish(status:String,detail:Dictionary={},code:int=0)->void:
	report.status=status;report["detail"]=detail
	var out:=FileAccess.open(OUTPUT,FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	print("ARCHIVE_REPLAY ",status," clears=",report.clears.size()," detail=",detail)
	quit(code)
func point_for(s,id:int)->Vector2:
	for p in s.panels:
		if p.id==id:return p.pos
	return Vector2(INF,INF)
func same_ids(a:Array,b:Array)->bool:
	if a.size()!=b.size():return false
	for i in range(a.size()):
		if int(a[i])!=int(b[i]):return false
	return true
func run()->void:
	RunSession=load("res://scripts/board_run_session.gd")
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var s=RunSession.new();var rng:=RandomNumberGenerator.new();rng.seed=int(source.seed)
	var initial:Dictionary=Motion.initial_board(BOUNDS,48,1,rng);s.initialize_board(initial.panels,initial.next_id)
	for event in source.events:
		match String(event.type):
			"reward":
				if not s.choose_relic(event.id,s.offer_serial):finish("rejected_reward",{},1);return
			"route":
				if not s.choose_route(event.choice):finish("rejected_route",{},1);return
			"shop_purchase":
				if not s.buy_shop(event.item):finish("rejected_shop",{},1);return
			"shop_leave":
				if not s.leave_shop():finish("rejected_exit",{},1);return
			"next_fight":
				var next:Dictionary=Motion.initial_board(BOUNDS,48,s.next_id,rng);s.begin_next_fight(next.panels,next.next_id)
			"enemy_attack":s.finish_attack()
			"skill","clear":
				var is_skill:bool=event.type=="skill"
				if is_skill:s.skill_mode=true;s.skill_color=int(event.color)
				var point:=point_for(s,int(event.start_id))
				if not point.is_finite() or not s.begin(point,-1):finish("archived_start_diverged",{"action":report.clears.size()+1,"id":event.start_id,"phase":s.phase});return
				var preview:Dictionary=s.selection.duplicate(true)
				var actual:Array=preview.get("targets",[]) if is_skill else preview.get("removed",[])
				var archived:Array=event.target_ids if is_skill else event.removed_ids
				if not same_ids(actual,archived):
					finish("archived_plan_diverged",{"type":event.type,"action":report.clears.size()+1,"id":event.start_id,"actual":actual,"archived":archived,"note":"Changed inlet/contact geometry; full old sequence is inconclusive, not reported as victory or successful strict replay."});return
				var present:Dictionary={}
				for p in s.panels:present[p.id]=true
				var executed:Dictionary=s.release(point,-1)
				if executed!=preview:finish("preview_commit_mismatch",{},1);return
				if is_skill:continue
				burst_rng(rng,executed,present)
				var motion:Dictionary=Motion.start(s.panels,BOUNDS,48,s.next_id,rng)
				while not motion.ready and not motion.stalled:Motion.step(motion,BOUNDS,Motion.STEP)
				report.clears.append({"action":report.clears.size()+1,"id":event.start_id,"elapsed":motion.elapsed,"ready":motion.ready,"pending":motion.pending.size()})
				if motion.stalled:finish("refill_stalled",{"action":report.clears.size()},1);return
				s.panels=motion.panels.duplicate(true);s.next_id=motion.next_id;s.finish_refill()
	report.full_sequence_conclusive=true
	finish("archive_complete",{"phase":s.phase,"carry":carry(s),"combat":combat_state(s)})

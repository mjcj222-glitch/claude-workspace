extends "res://tests/play_balance.gd"
## Ordinary seeded runs, no fixtures/forced resources. No balance search.
func run()->void:
	RunSession=load("res://scripts/board_run_session.gd")
	var tasks:Array=[]
	for route in ["safe","elite"]:
		for pair in range(3):tasks.append({"seed":20261021,"route":route,"pair":pair,"policy":"intent-aware"})
	tasks.append({"seed":20261023,"route":"elite","pair":0,"policy":"avoid-intent"})
	var reports:Array=[]
	for task in tasks:
		selected_policy=task.policy
		var result:Dictionary=simulate(task.seed,task.pair,task.route)
		result["audit"]=audit(result)
		result["boss_summary"]=boss_summary(result)
		var complete:bool=result.terminal in ["victory","defeat"] and result.errors.is_empty() and result.audit.errors.is_empty()
		if not complete:failures+=1
		var name:="seed%d-%s-pair%d-%s"%[task.seed,task.route,task.pair,task.policy]
		var f:=FileAccess.open("res://evidence/refill-stall/"+name+".json",FileAccess.WRITE)
		f.store_string(JSON.stringify(result,"  "));f.close()
		reports.append({"task":task,"terminal":result.terminal,"hp":result.carry.hp,"actions":result.carry.actions,"errors":result.errors,"audit_errors":result.audit.errors})
		print("REFILL_NORMAL ",name," complete=",complete," terminal=",result.terminal," hp=",result.carry.hp," actions=",result.carry.actions)
		await process_frame
	var f:=FileAccess.open("res://evidence/refill-stall/normal-summary.json",FileAccess.WRITE);f.store_string(JSON.stringify({"failures":failures,"runs":reports},"  "));f.close()
	quit(1 if failures else 0)

extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func _init()->void:
	var scene=load("res://main.tscn").instantiate()
	for count in [2,6,12,35,48]:
		scene.active_plan={"removed":range(count)}
		var previous:float=-1.0
		for i in range(count):
			var onset:float=scene._clear_onset(i)
			check(onset>previous,"strict effect order")
			previous=onset
		if count>=35:check(previous<=2.10001,"long clear sequence bounded before natural fall")
		if count==2:check(absf(previous-0.075)<0.00001,"ordinary two uses deliberate chime spacing")
	scene.free()
	print("TIMELINE failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
## Short diagnostic: identical idle scene, no input/search/capture/file I/O.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	preload("res://tests/enter_adventure.gd").enter(scene)
	var rid:=root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for i in range(60):
		await process_frame
		await RenderingServer.frame_post_draw
	var samples: Array=[]
	scene.bench.clear()
	var last:=Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		samples.append({"wall_us":now-last,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"cpu":scene.bench.duplicate()})
		last=now
		scene.bench.clear()
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--result="):output=arg.substr(9)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"samples":samples},"  "))
	quit()

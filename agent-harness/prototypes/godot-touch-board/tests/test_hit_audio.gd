extends SceneTree
const Sound=preload("res://scripts/board_audio.gd")
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var sound=Sound.new();root.add_child(sound)
	check(sound.has_method("impact"),"enemy impact has a distinct bounded cached sound")
	if not sound.has_method("impact"):sound.queue_free();await process_frame;quit(1);return
	check(sound.voices.size()==6 and sound.impact_streams.size()==6,"impact uses existing six voices and six precached variants")
	var unique:Dictionary={}
	for stream in sound.impact_streams.values():
		unique[stream.data]=true
		check(stream.mix_rate==22050 and stream.data.size()>=4000 and stream.data.size()<=12000,"impact PCM has bounded duration")
	check(unique.size()==6,"small/long/core and weakness sounds differ")
	var initial:int=sound.cursor;sound.muted=true;sound.impact(2,true)
	check(sound.cursor==initial,"mute suppresses impact playback")
	sound.muted=false;sound.impact(0,false)
	check(sound.cursor==(initial+1)%6,"one impact consumes exactly one existing voice")
	sound.queue_free();await process_frame;await create_timer(0.25).timeout
	print("HIT_AUDIO failures=",failures);quit(1 if failures else 0)

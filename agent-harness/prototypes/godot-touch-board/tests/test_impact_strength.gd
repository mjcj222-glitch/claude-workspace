extends SceneTree
const Audio=preload("res://scripts/board_audio.gd")
const FX=preload("res://scripts/board_quality_fx.gd")
const Feedback=preload("res://scripts/board_feedback.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var a=Audio.new();root.add_child(a)
 check(a.has_method("panel") and a.has_method("clear_pitch"),"cached panel cues distinguish kinds without runtime synthesis")
 if not a.has_method("panel"):a.queue_free();await process_frame;quit(1);return
 check(a.voices.size()==6,"six voices remain bounded")
 check(a.panel_streams.size()==6 and a.panel_streams.normal.size()==24,"finite cached pop/heart/core/strong variants")
 check(a.clear_pitch(14)<a.clear_pitch(15) and a.clear_pitch(23)==a.clear_pitch(200),"long clear rises beyond old fifteenth wrap and has capped pitch")
 var cache:Dictionary={}
 for kind in a.panel_streams:
  for stream in a.panel_streams[kind]:cache[stream.data]=true
 check(cache.size()==52,"all24 pops,24 heals and4 special waveforms are distinct")
 a.panel(20,"normal");var allocated:AudioStream=a.voices[0].stream
 a.panel(20,"normal");check(a.voices[1].stream==allocated,"repeated cue reuses cached PCM")
 a.panel(0,"core");var core:AudioStream=a.voices[4].stream
 a.panel(0,"strong");check(a.voices[4].stream!=core,"strong core has independent deeper explosion cue")
 a.impact(2,true);check(a.voices[5].stream!=null,"final hit has reserved voice not stolen by pops")
 a.muted=true
 check(a.voices.all(func(v):return not v.playing),"mute immediately stops existing tails")
 var cursor:int=a.cursor;a.panel(0,"normal");a.impact(2,true)
 check(a.cursor==cursor,"mute suppresses new cues")
 a.muted=false
 var source:Array=[{"id":1,"kind":"strong"},{"id":2,"kind":"core"},{"id":3,"kind":"normal"}]
 var plan:Dictionary={"valid":true,"removed":[1,2,3],"activated":[1,2,1,404],"damage":1}
 var original:Dictionary=plan.duplicate(true)
 var fx=FX.new();fx.action_started(plan,source,.2,24)
 fx.panel_removed(1,Vector2.ZERO,Color.RED,"strong");fx.action_finished();fx.update(.2)
 var impact:Dictionary=fx.take_impact()
 check(impact.get("strong_cores",0)==1 and impact.cores==2,"impact metadata counts actual removed strong cores uniquely")
 check(plan==original and fx.take_impact().is_empty(),"one-shot impact cannot mutate plan or repeat")
 fx.reduced_effects=true
 check(fx.hit_flash()==0 and fx.stage_offset()==Vector2.ZERO,"reduced suppresses all enhanced flash and recoil")
 var normal=Feedback.new();normal.start({"removed":[2],"activated":[2]},source);normal.consume(2,Vector2.ZERO,Color.RED)
 var strong=Feedback.new();strong.start({"removed":[1],"activated":[1]},source);strong.consume(1,Vector2.ZERO,Color.RED)
 check(strong.rings.back().radius>normal.rings.back().radius,"strong wave is larger than ordinary core wave")
 check(strong.particles.size()<=320 and strong.rings.size()<=24,"strong burst preserves existing budgets")
 strong.reduced_effects=true;strong.start(plan,source);strong.consume(1,Vector2.ZERO,Color.RED)
 check(strong.particles.is_empty(),"reduced emits no heavy shards")
 fx.reset();fx.update(2);strong.reset()
 check(fx.take_impact().is_empty() and fx.trails.is_empty() and strong.rings.is_empty(),"reset cancels old impacts and next-scene debris")
 a.queue_free();await process_frame;await create_timer(.25).timeout
 print("IMPACT_STRENGTH checks=",checks," failures=",failures);quit(1 if failures else 0)

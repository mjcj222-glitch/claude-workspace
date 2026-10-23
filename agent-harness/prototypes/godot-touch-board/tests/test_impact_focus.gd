extends SceneTree
const Audio=preload("res://scripts/board_audio.gd")
const Feedback=preload("res://scripts/board_feedback.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var a=Audio.new();root.add_child(a);a.set_process(false)
 a.panel(1,"normal");var normal_db:float=a.voices[0].volume_db
 a.panel(0,"big_bomb");var explosion:AudioStream=a.voices[4].stream
 check(a.voices[0].volume_db<=normal_db-5,"existing pop yields briefly to bomb transient")
 a.panel(0,"core")
 check(a.voices[4].stream==explosion,"weaker core cannot truncate active large explosion")
 a.panel(2,"normal")
 check(a.voices[1].volume_db<=normal_db-5,"new pop also respects explosion focus")
 a.impact(2,true)
 check(a.voices[5].volume_db==-8,"impact keeps original gain and reserved voice")
 check(a.has_method("reset_feedback"),"interrupted playback has explicit reset")
 if a.has_method("reset_feedback"):
  a._process(.5)
  check(is_equal_approx(a.voices[0].volume_db,normal_db),"pop level recovers without a delayed cue")
  a.impact(2);a.reset_feedback()
  check(a.voices.all(func(v):return not v.playing),"reset stops old attack tails")
  a.panel(1,"normal")
  check(is_equal_approx(a.voices[0].volume_db,normal_db),"next run has no stale attenuation")
 a.muted=true;a.panel(0,"big_bomb");a.muted=false
 a.panel(0,"normal")
 check(a.voices[a.pop_cursor-1 if a.pop_cursor>0 else 3].volume_db==normal_db,"mute cancels focus and cannot queue explosions")
 var f=Feedback.new()
 var panels:Array=[{"id":1,"kind":"big_bomb"}]
 var plan:Dictionary={"removed":[1],"activated":[1]}
 var snapshot:Dictionary=plan.duplicate(true)
 f.start(plan,panels);f.consume(1,Vector2.ZERO,Color.BLUE)
 var waves:Array=f.rings.filter(func(r):return r.core_priority)
 check(waves.size()==2,"bomb has one primary and one secondary wave")
 check(waves.any(func(r):return r.age==0),"primary blast wave starts on actual clear event")
 check(waves.all(func(r):return r.life-r.age<=.34),"blast waves finish before old delayed third ring")
 check(f.particles.all(func(p):return p.life<=.37),"bomb shards do not mask prolonged refill")
 f.update(.15);f.finish()
 check(f._pulse==1.0 and f.count==1 and f.bomb_count==1,"completion has one full count accent")
 f.update(.1);var pulse:float=f._pulse;f.finish()
 check(f._pulse==pulse and plan==snapshot,"duplicate finish cannot reaccent or mutate plan")
 f.reset();f.update(1)
 check(f.rings.is_empty() and not f.visible,"reset cancels pending waves and count")
 f.reduced_effects=true;f.start(plan,panels);f.consume(1,Vector2.ZERO,Color.BLUE)
 check(f.particles.is_empty(),"reduced retains count without shards")
 a.queue_free();await process_frame;await create_timer(.25).timeout
 print("IMPACT_FOCUS checks=",checks," failures=",failures);quit(1 if failures else 0)

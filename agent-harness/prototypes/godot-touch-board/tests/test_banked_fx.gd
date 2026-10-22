extends SceneTree
const FX=preload('res://scripts/board_quality_fx.gd')
const Feedback=preload('res://scripts/board_feedback.gd')
const Audio=preload('res://scripts/board_audio.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1
 print('PASS ' if ok else 'FAIL ',label)
func _initialize():call_deferred('run')
func run():
 var f=FX.new();var panels=[{'id':1,'kind':'normal'},{'id':2,'kind':'heart'}]
 var plan={'valid':true,'removed':[1,2],'damage':4,'base_damage':4,'heal_raw':2,'heal_effective':2}
 for clear in range(2):
  f.action_started(plan,panels,.1,48);f.panel_removed(1,Vector2(100,500),Color.RED,'normal');check(f.trails[0].kind=='collect','clear trail goes to collection not enemy');f.action_finished();f.update(1)
  check(f.take_impact().is_empty(),'clear '+str(clear)+' cannot attack enemy')
 check(f.has_method('release_bank'),'explicit bank release API')
 if f.has_method('release_bank'):
  f.release_bank({'damage':15,'base_damage':12,'weak_bonus':3,'shield_damage':12,'shield_broken':true},20,48)
  f.release_bank({'damage':999},144,48)
  check(f.damage_amount==15,'duplicate release cannot replace or restart bank')
  f.update(.279);check(f.take_impact().is_empty() and f.display_enemy_hp(48)==48,'bank holds HP until one impact')
  f.update(.002);var hit=f.take_impact();check(hit.get('damage')==15 and hit.get('shield_broken',false),'one final combined hit')
  f.update(1);check(f.take_impact().is_empty(),'combined hit cannot repeat')
  f.reset();f.release_bank({'damage':0},6,48);f.update(.29);check(not f.take_impact().is_empty(),'zero damage bank still completes phase')
  f.reset();f.release_bank({'damage':10},12,48);f.reset();f.update(1);check(f.take_impact().is_empty(),'reset cancels pending bank')
 var b=Feedback.new();b.start(plan,panels);b.consume(1,Vector2(100,500),Color.RED)
 check(b.has_method('combo_pose'),'elastic combo pose available')
 if b.has_method('combo_pose'):
  var p=b.combo_pose();b.update(.06);var q=b.combo_pose()
  check(p!=q,'actual consume drives elastic moving pose')
  check(p.center.x>=24 and p.center.x<=328 and p.center.y>=140 and p.center.y<=215,'combo center bounded outside telegraph')
  b.reduced_effects=true;var reduced=b.combo_pose();check(reduced.angle==0 and reduced.scale==Vector2.ONE,'reduced combo stable readable')
 var a=Audio.new();root.add_child(a)
 check(a.panel_streams.normal[0].data.size()>=int(.14*22050)*2,'clear chime has resonant tail')
 a.queue_free();await process_frame
 print('BANKED_FX checks=',checks,' failures=',failures);quit(1 if failures else 0)

extends SceneTree
const FX=preload('res://scripts/board_quality_fx.gd')
const Audio=preload('res://scripts/board_audio.gd')
var failures:=0
var checks:=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1
 print('PASS ' if ok else 'FAIL ',label)
func _initialize():call_deferred('run')
func run():
 seed(613);var expected=randf();seed(613)
 for reduced in [false,true]:
  for count in [9,60]:
   var fx=FX.new();fx.reduced_effects=reduced
   fx.release_bank({'damage':20,'shield_broken':true},count,80)
   fx.update(.279);check(fx.take_impact().is_empty(),'no early hit')
   fx.update(.0011);check(fx.take_impact().get('damage')==20,'one hit at .28')
   check(fx.take_impact().is_empty(),'impact is consumed once')
   fx.update(.08)
   check(fx.stage_offset()==Vector2.ZERO if reduced else fx.stage_offset().length()<32,'bounded enemy recoil; reduced zero')
   fx.update(.17);check(fx.impact_remaining==0,'impact lifetime remains .24')
 check(randf()==expected,'visual update does not consume global RNG')
 var a=Audio.new();root.add_child(a)
 var peak:=0.0
 for stream in a.impact_streams.values():
  for i in range(0,stream.data.size(),2):peak=maxf(peak,absf(stream.data.decode_s16(i)/32767.0))
 check(peak>0 and peak<=.781,'cached impact PCM normalized below clipping')
 check(a.impact_streams.size()==6,'six cached tier/weak variants')
 a.queue_free();await process_frame
 print('CLIMAX_CANDIDATE checks=',checks,' failures=',failures);quit(1 if failures else 0)

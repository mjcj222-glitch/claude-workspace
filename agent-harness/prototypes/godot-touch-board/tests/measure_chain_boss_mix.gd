extends SceneTree
const Audio=preload("res://scripts/board_audio.gd")
var sound
var capture:AudioEffectCapture
var samples:=PackedVector2Array()
var elapsed:=0.0
var event:=0
func _initialize():call_deferred('run')
func run():
 capture=AudioEffectCapture.new();capture.buffer_length=4
 AudioServer.add_bus_effect(0,capture)
 sound=Audio.new();root.add_child(sound)
func _process(delta):
 if sound==null:return false
 elapsed+=delta
 while event<96 and elapsed>=event*.025:
  sound.panel(event%24,'normal')
  if event%16==4:sound.panel(event,'big_bomb')
  if event%16==8:sound.impact(2,true)
  event+=1
 if capture.can_get_buffer(1):samples.append_array(capture.get_buffer(capture.get_frames_available()))
 if elapsed>3:
  var peak:=0.0;var squares:=0.0;var clipped:=0;var bad:=0
  var bytes:=PackedByteArray();bytes.resize(samples.size()*4)
  for i in range(samples.size()):
   var pair:Vector2=samples[i]
   for value in [pair.x,pair.y]:
    if not is_finite(value):bad+=1
    peak=maxf(peak,absf(value));squares+=value*value
    if absf(value)>=1:clipped+=1
   bytes.encode_s16(i*4,int(clampf(pair.x,-1,1)*32767));bytes.encode_s16(i*4+2,int(clampf(pair.y,-1,1)*32767))
  var result={'frames':samples.size(),'peak':peak,'sample_peak_dbfs':linear_to_db(peak),'rms_dbfs':linear_to_db(sqrt(squares/maxi(1,samples.size()*2))),'clipped_samples':clipped,'nonfinite_samples':bad,'driver':AudioServer.get_driver_name(),'method':'Actual AudioServer master capture, 96 pops plus6 big bombs and6 impacts over3seconds; original stereo channels, no device listening'}
  FileAccess.open('res://evidence/chain-boss/actual-mix.json',FileAccess.WRITE).store_string(JSON.stringify(result,'  '))
  var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=AudioServer.get_mix_rate();wav.stereo=true;wav.data=bytes;wav.save_to_wav('res://evidence/chain-boss/actual-mix.wav')
  print(JSON.stringify(result))
  sound.reset_feedback();sound.queue_free();sound=null
  AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
  quit(1 if peak==0 or clipped>0 or bad>0 else 0)
 return false

extends Node
## Original cached PCM. Four pop voices, one core, one impact: six total.
## Per-voice headroom is measured with overlapping actual event playback.
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var pop_cursor := 0
# Presentation-only focus: no queued sounds, bus changes or gameplay timers.
const FOCUS_SECONDS := 0.16
const RELEASE_SECONDS := 0.08
const FOCUS_DB := 6.0
var _focus_remaining := 0.0
var _special_rank := 0
var _pop_levels:Array[float]=[-16.0,-16.0,-16.0,-16.0]
var muted := false:
 set(value):
  muted=value
  if value:reset_feedback()
var impact_streams:Dictionary={}
var panel_streams:Dictionary={"normal":[],"heart":[],"core":[],"strong":[],"bomb":[],"big_bomb":[]}
var finish_streams:Array=[]
var landing_stream:AudioStreamWAV
func _ready()->void:
 for i in range(6):
  var player:=AudioStreamPlayer.new();add_child(player);voices.append(player)
 for tier in range(3):
  for weak in [false,true]:impact_streams[_impact_key(tier,weak)]=_impact_stream(tier,weak)
 for i in range(24):
  panel_streams.normal.append(_pop_stream(i,false))
  panel_streams.heart.append(_pop_stream(i,true))
  finish_streams.append(_pop_stream(i,false,true))
 for kind in ["core","strong","bomb","big_bomb"]:panel_streams[kind].append(_wave_stream(kind))
 landing_stream=_pop_stream(0,false,false,true)
func _impact_key(tier:int,weak:bool)->int:return clampi(tier,0,2)*2+int(weak)
func chain_layers(index:int)->int:return 1+mini(2,maxi(0,index)/8)
func clear_pitch(index:int)->float:return 330.0*pow(2.0,clampi(index,0,23)/12.0)
func _pcm(samples:PackedFloat32Array)->AudioStreamWAV:
 var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
 var peak:=.78
 for sample in samples:peak=maxf(peak,absf(sample))
 var normalization:float=.78/peak
 var bytes:=PackedByteArray();bytes.resize(samples.size()*2)
 for i in range(samples.size()):bytes.encode_s16(i*2,int(samples[i]*normalization*32767))
 stream.data=bytes;return stream
func _impact_stream(tier:int,weak:bool)->AudioStreamWAV:
 var duration:float=.15+tier*.045
 var samples:=PackedFloat32Array();samples.resize(int(duration*22050))
 var noise:=RandomNumberGenerator.new();noise.seed=1773+tier*19+int(weak)
 var filtered:=0.0
 for n in range(samples.size()):
  var t:float=n/22050.0;var progress:float=t/duration
  var envelope:float=minf(t*2400,1)*pow(1-progress,1.6)
  var raw:float=noise.randf_range(-1,1);filtered=lerpf(filtered,raw,.24)
  var body:float=sin(TAU*((112-tier*15)*t-65*t*t))*.58
  var snap:float=(raw-filtered)*exp(-t*95)*.46
  var grit:float=filtered*exp(-t*24)*.22
  var accent:float=(sin(TAU*1174*t)+sin(TAU*1760*t))*.10*exp(-t*27) if weak else 0.0
  samples[n]=(body+snap+grit+accent)*envelope
 return _pcm(samples)
func _pop_stream(index:int,heart:bool,finish:bool=false,landing:bool=false)->AudioStreamWAV:
 var duration:float=.20 if finish else (.19 if not heart else .21)
 var base:float=105 if landing else clear_pitch(index)
 var samples:=PackedFloat32Array();samples.resize(int(duration*22050))
 for n in range(samples.size()):
  var t:float=n/22050.0;var env:float=minf(t*1800,1)*pow(1-t/duration,2)
  var wave:float=sin(TAU*base*t)*.43+sin(TAU*base*2.76*t)*exp(-t*17)*.13
  # More overtones articulate a growing chain without added voices or gain.
  if not heart and not finish and not landing:
   var layers:int=chain_layers(index)
   if layers>=2:wave=wave*.84+sin(TAU*base*3*t)*.08
   if layers>=3:wave=wave*.86+sin(TAU*base*4*t)*.065*(.6+.4*cos(TAU*18*t))
  if heart:wave=(sin(TAU*base*t)*.46+sin(TAU*base*1.5*t)*.17)*(.8+.2*cos(TAU*7*t))
  elif not finish and not landing:wave+=sin(TAU*base*5.4*t)*exp(-t*38)*.045
  if finish:wave=(sin(TAU*base*t)+sin(TAU*base*1.25*t)+sin(TAU*base*1.5*t))*.20
  samples[n]=wave*env
 return _pcm(samples)
func _wave_stream(kind:String)->AudioStreamWAV:
 var large:bool=kind in ["strong","big_bomb"]
 var blast:bool=kind in ["bomb","big_bomb"]
 var duration:float=.28 if large else .19
 var samples:=PackedFloat32Array();samples.resize(int(duration*22050))
 var noise:=RandomNumberGenerator.new();noise.seed=713+int(large)*31+int(blast)*53
 var filtered:=0.0
 for n in range(samples.size()):
  var t:float=n/22050.0;var env:float=minf(t*2200,1)*pow(1-t/duration,1.7)
  var raw:float=noise.randf_range(-1,1);filtered=lerpf(filtered,raw,.12 if large else .22)
  var frequency:float=(69.0 if large else 102.0)+(12.0 if not blast else 0.0)
  var body:float=sin(TAU*(frequency*t-50*t*t))*.48
  var crack:float=(raw-filtered)*exp(-t*(75 if not blast else 45))*.28
  var tail:float=filtered*.26 if blast else sin(TAU*660*t)*exp(-t*25)*.11
  samples[n]=(body+crack+tail)*env
 return _pcm(samples)
func reset_feedback()->void:
 for player in voices:player.stop()
 _focus_remaining=0.0
 _special_rank=0
 cursor=0
 pop_cursor=0
 _apply_focus()
func _apply_focus()->void:
 var duck:float=FOCUS_DB*clampf(_focus_remaining/RELEASE_SECONDS,0.0,1.0)
 for i in range(mini(4,voices.size())):voices[i].volume_db=_pop_levels[i]-duck
func _focus()->void:
 _focus_remaining=FOCUS_SECONDS
 _apply_focus()
func _process(delta:float)->void:
 if _focus_remaining<=0:return
 _focus_remaining=maxf(0.0,_focus_remaining-maxf(0.0,delta))
 _apply_focus()
func _play(stream:AudioStream,index:int,volume:float)->void:
 if muted or voices.is_empty():return
 var player:=voices[index];player.stop();player.volume_db=volume
 if index<4:
  _pop_levels[index]=volume
  _apply_focus()
 player.stream=stream;player.play();cursor=(cursor+1)%6
func panel(index:int,kind:String)->void:
 if muted or voices.is_empty():return
 if kind in ["core","strong","bomb","big_bomb"]:
  var rank:int=["core","strong","bomb","big_bomb"].find(kind)+1
  # Keep an audible explosion onset instead of restarting it for each core.
  if voices[4].playing and rank<=_special_rank:return
  _special_rank=rank
  _focus()
  _play(panel_streams[kind][0],4,-13.0)
  return
 var key:String="heart" if kind=="heart" else "normal"
 _play(panel_streams[key][clampi(index,0,23)],pop_cursor,-16.0);pop_cursor=(pop_cursor+1)%4
func impact(tier:int,weak:bool=false)->void:
 if muted or voices.is_empty():return
 _focus()
 _play(impact_streams[_impact_key(tier,weak)],5,-8.0)
func tone(index:int,finish:bool=false,landing:bool=false)->void:
 if not finish and not landing:panel(index,"normal");return
 _play(landing_stream if landing else finish_streams[clampi(index,0,23)],pop_cursor,-19.0 if landing else -18.0);pop_cursor=(pop_cursor+1)%4
func _exit_tree()->void:
 for player in voices:player.stop();player.stream=null
 voices.clear()

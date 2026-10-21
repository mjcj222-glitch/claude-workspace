extends Node
## Original synthesized PCM: bounded 6 voices, pitch confined to 330..1320 Hz.
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var muted := false
var impact_streams:Dictionary={}
func _ready() -> void:
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -13.0
		add_child(player)
		voices.append(player)
	for tier in range(3):
		for weak in [false,true]:impact_streams[_impact_key(tier,weak)]=_impact_stream(tier,weak)

func _impact_key(tier:int,weak:bool)->int:return clampi(tier,0,2)*2+int(weak)

func _impact_stream(tier:int,weak:bool)->AudioStreamWAV:
	var duration:float=0.13+tier*0.045
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var bytes:=PackedByteArray();bytes.resize(int(duration*22050)*2)
	var noise:=RandomNumberGenerator.new();noise.seed=1773+tier*19+int(weak)
	var filtered:=0.0
	for n in range(bytes.size()/2):
		var t:float=n/22050.0
		var progress:float=t/duration
		var envelope:float=minf(t*1400,1)*pow(1-progress,2.5)
		filtered=lerpf(filtered,noise.randf_range(-1,1),0.5)
		var body:float=sin(TAU*((125-tier*13)*t-120*t*t))*0.68
		var snap:float=filtered*exp(-t*55)*0.55
		var accent:float=sin(TAU*990*t)*exp(-t*28)*0.2 if weak else 0.0
		bytes.encode_s16(n*2,int(clampf((body+snap+accent)*envelope,-1,1)*22000))
	stream.data=bytes;return stream

func impact(tier:int,weak:bool=false)->void:
	if muted or voices.is_empty():return
	var player:=voices[cursor];cursor=(cursor+1)%voices.size()
	player.stop();player.volume_db=-8.0;player.stream=impact_streams[_impact_key(tier,weak)];player.play()

func tone(index: int, finish: bool = false, landing: bool = false) -> void:
	if muted or voices.is_empty():
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.22 if finish else 0.09
	var base := 110.0 if landing else minf(1320.0, 330.0 * pow(2.0, (index % 15) / 12.0))
	var samples := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for n in range(samples):
		var t := float(n) / 22050.0
		var env := minf(1.0, t * 220.0) * pow(1.0 - t / duration, 2.0)
		var wave := sin(TAU * base * t) * 0.7 + sin(TAU * base * 2.0 * t) * 0.2
		if finish:
			wave = (sin(TAU * base * t) + sin(TAU * base * 1.25 * t) + sin(TAU * base * 1.5 * t)) / 3.0
		bytes.encode_s16(n * 2, int(clampf(wave * env, -1, 1) * 22000))
	stream.data = bytes
	var player := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	player.stop()
	player.volume_db=-13.0
	player.stream = stream
	player.play()

func _exit_tree() -> void:
	for player in voices:
		player.stop()
		player.stream = null
	voices.clear()

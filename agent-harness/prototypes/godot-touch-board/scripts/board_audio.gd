extends Node
## Original synthesized PCM: bounded 6 voices, pitch confined to 330..1320 Hz.
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var muted := false
func _ready() -> void:
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -13.0
		add_child(player)
		voices.append(player)
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
	player.stream = stream
	player.play()

func _exit_tree() -> void:
	for player in voices:
		player.stop()
		player.stream = null
	voices.clear()

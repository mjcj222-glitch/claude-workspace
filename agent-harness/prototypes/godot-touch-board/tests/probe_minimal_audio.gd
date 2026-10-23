extends SceneTree
func _initialize():call_deferred("run")
func run():
 var player=AudioStreamPlayer.new();root.add_child(player)
 var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050
 var bytes=PackedByteArray();bytes.resize(22050);wav.data=bytes;player.stream=wav
 player.play();player.stop();player.stream=null;wav=null
 player.queue_free();await process_frame
 print("Minimal AudioStreamPlayer only")
 quit()

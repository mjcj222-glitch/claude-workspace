extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var output:String=OS.get_cmdline_user_args()[0]
 var sound=load("res://scripts/board_audio.gd").new();root.add_child(sound)
 DirAccess.make_dir_recursive_absolute(output)
 for tier in range(3):
  for weak in [false,true]:sound.impact_streams[sound._impact_key(tier,weak)].save_to_wav(output.path_join("impact-%d-%d.wav"%[tier,int(weak)]))
 if sound.has_method("panel"):
  for kind in sound.panel_streams:
   for i in range(sound.panel_streams[kind].size()):sound.panel_streams[kind][i].save_to_wav(output.path_join("%s-%d.wav"%[kind,i]))
 else:
  for i in range(24):
   sound.tone(i)
   sound.voices[(sound.cursor+5)%6].stream.save_to_wav(output.path_join("normal-%d.wav"%i))
 sound.queue_free();await process_frame;await create_timer(.25).timeout;quit()

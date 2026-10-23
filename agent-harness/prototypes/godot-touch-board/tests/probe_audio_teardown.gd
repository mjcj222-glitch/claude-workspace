extends SceneTree
func _initialize():call_deferred("run")
func run():
 var refs=[]
 var started=Time.get_ticks_msec()
 for cycle in range(12):
  var sound=preload("res://scripts/board_audio.gd").new();root.add_child(sound)
  sound.panel(0,"bomb");sound.panel(1,"normal");sound.impact(2,true)
  for voice in sound.voices:
   if voice.has_stream_playback():refs.append(weakref(voice.get_stream_playback()))
  sound.reset_feedback()
  sound.queue_free();await process_frame
 if "--drain" in OS.get_cmdline_user_args():
  while refs.any(func(ref):return ref.get_ref()!=null) and Time.get_ticks_msec()-started<2000:
   OS.delay_msec(1)
   await process_frame
 print("AUDIO refs_remaining=",refs.filter(func(ref):return ref.get_ref()!=null).size()," wall_ms=",Time.get_ticks_msec()-started)
 quit()

extends RefCounted
## AudioServer releases stopped playback on its mixer thread, not a SceneTree
## frame. Tests exiting immediately must observe release, not assume a frame or
## simulated fixed-fps timer is a real audio-thread barrier. No sound suppression.
static func release(scene,tree:SceneTree)->bool:
 var refs=[]
 for voice in scene.sound.voices:
  if voice.has_stream_playback():refs.append(weakref(voice.get_stream_playback()))
 scene.set_process(false)
 scene.sound.reset_feedback()
 scene.queue_free()
 await tree.process_frame
 var started=Time.get_ticks_msec()
 while refs.any(func(ref):return ref.get_ref()!=null) and Time.get_ticks_msec()-started<1000:
  OS.delay_msec(1) # Yield CPU to the mixer; release condition ends the wait.
  await tree.process_frame
 var remaining=refs.filter(func(ref):return ref.get_ref()!=null).size()
 print("AUDIO_TEARDOWN remaining=",remaining," wall_ms=",Time.get_ticks_msec()-started)
 return remaining==0

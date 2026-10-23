extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 for cycle in range(8):
  var view=load("res://main.tscn").instantiate();root.add_child(view);view.set_process(false)
  view.sound.panel(0,"normal");view.sound.panel(1,"big_bomb");view.sound.impact(2,true)
  if not view.sound.voices[4].playing or not view.sound.voices[5].playing:failures+=1
  view.reset_board()
  if view.sound.voices.any(func(voice):return voice.playing):failures+=1
  view.sound.panel(2,"heart");view.sound.panel(3,"bomb");view.sound.impact(1,false)
  if not await preload("res://tests/audio_teardown.gd").release(view,self):failures+=1
 print("AUDIO_SCENE_RESET cycles=8 failures=",failures)
 quit(1 if failures else 0)

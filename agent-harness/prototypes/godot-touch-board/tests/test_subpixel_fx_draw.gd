extends SceneTree
class Probe extends Node2D:
 var view
 var draws:=0
 func _draw():
  view.feedback.draw_hud(view,self)
  view.quality_fx.draw_overlay(view,self)
  draws+=1
func _initialize():call_deferred('run')
func run():
 var view=load('res://main.tscn').instantiate();root.add_child(view);view.set_process(false)
 preload('res://tests/enter_adventure.gd').enter(view)
 view.feedback.visible=true;view.feedback.count=20;view.feedback.finished=true;view.feedback._finish_age=.32-1e-12
 view.quality_fx.release_bank({'damage':20},60,24);view.quality_fx.update(.28);view.quality_fx.impact_remaining=1e-8
 var probe=Probe.new();probe.view=view;root.add_child(probe)
 for i in range(4):
  probe.queue_redraw();await process_frame
 print('SUBPIXEL_REAL_CANVAS draws=',probe.draws)
 var ok=probe.draws>=2
 probe.queue_free();await preload('res://tests/audio_teardown.gd').release(view,self)
 quit(0 if ok else 1)

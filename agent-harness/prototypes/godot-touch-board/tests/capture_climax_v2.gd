extends SceneTree
## Presentation fixture using actual main/hero/enemy assets; not legal gameplay.
class CaptureLabel extends Node2D:
 var host
 func _draw():
  draw_rect(Rect2(30,398,660,63),Color(0,0,0,.85))
  draw_string(ThemeDB.fallback_font,Vector2(40,423),'FX FIXTURE / final strike excerpt / '+('LOW 9' if host.segment==0 else 'HIGH 60'),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
  draw_string(ThemeDB.fallback_font,Vector2(40,448),'Actual game assets; synthetic bank, not normal play',HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
var scene
var label
var clock:=0.0
var segment:=-1
var fired:=false
var done:=false
var nearzero:=false
var nearzero_frames:=0
func _initialize():call_deferred('run')
func run():
 scene=load('res://main.tscn').instantiate();root.add_child(scene);scene.set_process(false)
 preload('res://tests/enter_adventure.gd').enter(scene)
 label=CaptureLabel.new();label.host=self;root.add_child(label)
func _process(delta):
 if scene==null or done:return false
 clock+=delta
 var next=mini(1,int(clock/4))
 if next!=segment:
  segment=next;fired=false;nearzero=false;scene.quality_fx.reset()
  scene.session.character_id='rio' if segment==0 else 'noa'
  scene.session.combat.encounter=0 if segment==0 else 2
  scene.session.phase='ready'
  scene.quality_fx.bank_energy=9 if segment==0 else 60
 var local=fmod(clock,4)
 if local>1 and not fired:
  fired=true;scene.session.phase='player_attack'
  scene.quality_fx.release_bank({'damage':9 if segment==0 else 66,'base_damage':9 if segment==0 else 66},9 if segment==0 else 60,scene.session.combat.enemy_hp)
 scene.time+=delta;scene.quality_fx.update(delta)
 var hit=scene.quality_fx.take_impact()
 if not hit.is_empty():scene.sound.impact(hit.tier,false)
 if local>2.5 and not nearzero:
  nearzero=true;scene.quality_fx.impact_remaining=1e-8
  nearzero_frames=3
  print('NEAR_ZERO_REAL_DRAW segment=',segment)
 if nearzero_frames>0:
  scene.quality_fx.impact_remaining=1e-8;nearzero_frames-=1
 scene.queue_redraw();scene.overlay_surface.queue_redraw();label.queue_redraw()
 if clock>8:
  done=true
  await preload('res://tests/audio_teardown.gd').release(scene,self)
  quit()
 return false

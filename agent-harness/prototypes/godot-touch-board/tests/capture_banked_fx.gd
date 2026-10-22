extends SceneTree
const FX=preload('res://scripts/board_quality_fx.gd')
const Feedback=preload('res://scripts/board_feedback.gd')
const Audio=preload('res://scripts/board_audio.gd')
class HUD extends RefCounted:
 const HERO_RECT=Rect2(8,920,180,160)
 const BOARD_SCREEN=Rect2(30,390,660,530)
class Combat extends RefCounted:
 var encounter=2
class Session extends RefCounted:
 var combat=Combat.new()
 var character_id="rio"
class View extends RefCounted:
 var UI=HUD
 var sandbox:=false
 var session=Session.new()
 var font:Font=load('res://assets/fonts/Pretendard-Medium.otf')
 var font_body:Font=font
 var font_display:Font=font
 func board_to_screen(point:Vector2)->Vector2:return point
class Stage extends Node2D:
 var owner_tree
 func _draw():
  var t=owner_tree
  draw_rect(Rect2(0,0,720,1080),Color('100c20'))
  draw_string(t.view.font,Vector2(30,40),'FX FIXTURE: 3 collects / ONE bank impact',HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
  draw_string(t.view.font,Vector2(30,75),'Synthetic presentation sample; not a normal run',HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color('aa99bb'))
  draw_circle(Vector2(548,162),48,Color('665488'))
  draw_arc(Vector2(548,162),55,0,TAU,6,Color('ffe06c'),3,true)
  draw_string(t.view.font,Vector2(420,250),'TELEGRAPH / SHIELD',HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
  draw_rect(Rect2(30,390,660,530),Color('21152f'))
  for i in range(20):
   var color:Color=[Color('ff705d'),Color('6edb6b'),Color('ffcf5b'),Color('61b7ff')][t.group%4]
   if i<=t.index:color.a=.1
   draw_circle(t.panels[i].pos,25,color)
  t.fx.draw_overlay(t.view,self)
  t.feedback.draw_hud(t.view,self)
var fx=FX.new()
var feedback=Feedback.new()
var view=View.new()
var sound
var stage
var panels:Array=[]
var plan:Dictionary
var clock:=0.0
var group:=-1
var index:=-1
var released:=false
var done:=false
func _initialize():call_deferred('run')
func run():
 sound=Audio.new();root.add_child(sound)
 stage=Stage.new();stage.owner_tree=self;root.add_child(stage)
 var ids=[]
 for i in range(20):
  panels.append({'id':i,'kind':'normal','pos':Vector2(95+(i%5)*125,465+(i/5)*110)})
  ids.append(i)
 plan={'valid':true,'removed':ids,'damage':20,'base_damage':20}
func _process(delta):
 if stage==null or done:return false
 clock+=delta
 var next_group=int(clock/1.7)
 if next_group<3:
  if group!=next_group:
   group=next_group;index=-1;fx.action_started(plan,panels);feedback.start(plan,panels)
  var target_index=mini(19,int(fmod(clock,1.7)/.075))
  while index<target_index:
   index+=1
   var color:Color=[Color('ff705d'),Color('6edb6b'),Color('ffcf5b')][group]
   feedback.consume(index,panels[index].pos,color);fx.panel_removed(index,panels[index].pos,color,'normal');sound.panel(index,'normal')
  if target_index==19:feedback.finish();fx.action_finished()
 elif not released:
  released=true;fx.release_bank({'damage':66,'base_damage':60,'weak_bonus':0,'shield_damage':12,'shield_broken':true},60,96)
 fx.update(delta);feedback.update(delta)
 var hit=fx.take_impact()
 if not hit.is_empty():sound.impact(hit.tier,false)
 stage.queue_redraw()
 if clock>6.7:
  done=true;sound.reset_feedback();sound.queue_free();await process_frame;quit()
 return false

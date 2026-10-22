extends SceneTree
const FX=preload("res://scripts/board_quality_fx.gd")
const Audio=preload("res://scripts/board_audio.gd")
class HUD extends RefCounted:
 const HERO_RECT=Rect2(8,920,190,160)
 const BOARD_SCREEN=Rect2(30,390,660,530)
class View extends RefCounted:
 var UI=HUD
 var sandbox:=true
 var session=null
 var font:Font=ThemeDB.fallback_font
 var font_body:Font=ThemeDB.fallback_font
 var font_display:Font=ThemeDB.fallback_font
 func board_to_screen(p:Vector2)->Vector2:return p
class Canvas extends RefCounted:
 var lines:Array=[]
 var polygons:=0
 var arcs:=0
 var textures:=0
 var text:Array=[]
 func draw_colored_polygon(_points,_tint):polygons+=1
 func draw_line(a,b,c,w=1.0,_aa=false):lines.append({"a":a,"b":b,"color":c,"width":w})
 func draw_circle(_p,_r,_c):pass
 func draw_arc(_p,_r,_a,_b,_n,_c,_w=1.0,_aa=false):arcs+=1
 func draw_string(_f,_p,value,_a,_w,_size,_c):text.append(value)
 func draw_string_outline(_f,_p,_v,_a,_w,_s,_o,_c):pass
 func draw_texture_rect_region(_t,_d,_s,_c):textures+=1
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var f=FX.new()
 var panels=[{'id':1,'kind':'normal'},{'id':2,'kind':'big_bomb'}]
 var plan={'valid':true,'removed':[1,2],'activated':[2],'damage':15,'shield_damage':12,'shield_broken':true,'shield_bonus':6,'combat_context':{'shield_color':2}}
 var saved=plan.duplicate(true)
 f.action_started(plan,panels,.2,48)
 f.panel_removed(1,Vector2(120,500),Color.GREEN,'normal')
 f.action_finished();f.update(.199)
 check(f.take_impact().is_empty(),'shield does not shatter before scheduled hit')
 f.update(.0011)
 check(f.take_impact().is_empty(),'completed clear still cannot shatter shield')
 check(f.big_bombs==1,'collection counts real unique large bombs')
 var bank=plan.duplicate(true);bank.big_bombs=f.big_bombs;bank.bomb_activations=f.bomb_activations
 f.release_bank(bank,2,48);f.update(.28)
 var event=f.take_impact()
 check(event.get('shield_broken',false) and event.get('shield_damage',0)==12,'shield result reaches one shot impact')
 check(f.get('shield_remaining')!=null and f.get('shield_remaining')>0,'shield fracture persists long enough to read')
 check(f.get('big_bombs')==1,'large bomb presentation counted from actual unique activated panels')
 check(plan==saved and f.take_impact().is_empty(),'presentation never edits canonical result or repeats damage')
 var v=View.new();var canvas=Canvas.new()
 f.draw_overlay(v,canvas)
 check(canvas.polygons>=12 and '보호막 파괴' in canvas.text,'actual draw emits shield pieces and readable break result')
 check(canvas.arcs>=5,'large bomb adds two distinct concentric impact waves')
 f.reduced_effects=true
 canvas=Canvas.new();f.draw_overlay(v,canvas)
 check(canvas.polygons==0 and canvas.arcs==2,'reduced effect uses two quiet arcs without fragments')
 check(f.stage_offset()==Vector2.ZERO and f.hit_flash()==0,'reduced mode disables flash and shake')
 f.reset();f.update(1)
 check(f.get('shield_remaining')==0,'reset cancels shield debris')
 f.skill_activated();f.update(.1);canvas=Canvas.new();f.draw_overlay(v,canvas)
 check(canvas.textures==0,'skill sweep never reintroduces old nonpixel portrait')
 f.reduced_effects=false
 var converted={1:2,5:2};var preserved=converted.duplicate(true)
 f.skill_activated(converted);f.update(.1);canvas=Canvas.new();f.draw_overlay(v,canvas)
 var board_lines=canvas.lines.filter(func(line):return line.a.y>=390 and line.a.y<=920 and line.b.y>=390 and line.b.y<=920)
 check(not board_lines.is_empty(),'skill casts visible sweep across board during existing cutin')
 check(board_lines.all(func(line):return line.a.x>=30 and line.b.x<=690 and line.width<=4 and line.color.a<=.6),'sweep remains thin translucent and inside board bounds')
 check(not board_lines.is_empty() and board_lines[0].color.is_equal_approx(Color(Color('ffcf5b'),.5)),'sweep uses selected target color')
 check(converted==preserved,'sweep does not mutate skill conversion map')
 f.reduced_effects=true;canvas=Canvas.new();f.draw_overlay(v,canvas)
 check(canvas.lines.filter(func(line):return line.a.y>=390 and line.a.y<920).is_empty(),'reduced mode omits board sweep')
 f.reduced_effects=false;f.update(.5);canvas=Canvas.new();f.draw_overlay(v,canvas)
 check(canvas.lines.filter(func(line):return line.a.y>=390 and line.a.y<920).is_empty(),'sweep expires with existing half second cutin')
 var a=Audio.new();root.add_child(a)
 check(a.has_method('chain_layers'),'chain timbre has bounded density progression')
 if a.has_method('chain_layers'):
  check(a.chain_layers(0)==1 and a.chain_layers(8)==2 and a.chain_layers(16)==3 and a.chain_layers(100)==3,'harmonic density rises at8 and16 then caps')
 var peak:=0.0
 for kind in a.panel_streams:
  for stream in a.panel_streams[kind]:
   for n in range(0,stream.data.size(),2):peak=maxf(peak,absf(stream.data.decode_s16(n)/32767.0))
 check(peak<=.781,'cached waveform peaks retain headroom')
 check(a.voices.size()==6,'no extra playback voices')
 a.queue_free();await process_frame
 print('CHAIN_BOSS_FX checks=',checks,' failures=',failures);quit(1 if failures else 0)

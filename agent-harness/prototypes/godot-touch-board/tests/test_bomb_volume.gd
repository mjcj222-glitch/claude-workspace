extends SceneTree
const Motion=preload("res://scripts/board_motion.gd")
const Bombs=preload("res://scripts/board_bombs.gd")
const View=preload("res://scripts/board_panel_view.gd")
const Rules=preload("res://scripts/board_rules.gd")
const BOUNDS=Rect2(30,290,660,530)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _init()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=23
 var state:Dictionary=Motion.start([],BOUNDS,48,1,rng)
 var original_id:int=state.pending[0].id;var rng_before:int=rng.state
 Bombs.prepare_supply(state.pending,"big_bomb")
 check(state.pending[0].radius==48,"large supplied body occupies actual48px radius")
 check(state.pending[0].id==original_id and state.pending.size()==48 and rng.state==rng_before,"supply preserves ID count RNG")
 check(View.visual_radius({"kind":"big_bomb","radius":48.0})==48,"physical48 matches visual48, no double scaling")
 state.spawn_clock=1.0;Motion._spawn(state,BOUNDS)
 var born:Dictionary=state.panels[0]
 check(born.pos.y+born.radius<=BOUNDS.position.y-0.9,"large enters fully above top")
 check(born.pos.x-born.radius>=BOUNDS.position.x and born.pos.x+born.radius<=BOUNDS.end.x,"large inlet respects both walls")
 var pair:Array=[{"id":1,"pos":Vector2(200,700),"radius":48.0,"kind":"big_bomb","color":0},{"id":2,"pos":Vector2(285,700),"radius":37.0,"kind":"normal","color":0}]
 check(Rules.contact_graph(pair)[1]==[2],"contact graph uses48+37 at physical touching distance")
 pair[1].pos.x=287
 check(Rules.contact_graph(pair)[1].is_empty(),"outside48+37+tolerance is disconnected")
 var plan:Dictionary=Rules.plan(pair,1,20,30)
 check(plan.direct==[1] and plan.blasts[0].radius==164,"neutral bomb direct and164 blast unchanged")
 # Dense multi-large fixture: actual supplied bodies, no precomputed destinations.
 state=Motion.start([],BOUNDS,48,1,rng)
 for i in range(6):Bombs.prepare_supply([state.pending[i]],"big_bomb")
 var previous:Dictionary={};var frames:Array=[];var max_overlap:=0.;var max_swept:=0.;var max_step:=0.;var uncaused:=0;var top_ok:=true;var walls_ok:=true
 while not state.ready and not state.stalled:
  Motion.step(state,BOUNDS,Motion.STEP)
  var positions:Dictionary={};var row:Array=[]
  for p in state.panels:
   positions[p.id]=p.pos;row.append([p.id,p.pos.x,p.pos.y,p.radius])
   if not previous.has(p.id):top_ok=top_ok and p.pos.y+p.radius<BOUNDS.position.y+1
   else:
    max_step=maxf(max_step,p.pos.distance_to(previous[p.id]))
    if absf(p.pos.x-previous[p.id].x)>.001 and p.get("contact_count",0)==0:uncaused+=1
   walls_ok=walls_ok and p.pos.x-p.radius>=BOUNDS.position.x-.2 and p.pos.x+p.radius<=BOUNDS.end.x+.2 and p.pos.y+p.radius<=BOUNDS.end.y+.2
   for q in state.panels:
    if p.id>=q.id:continue
    max_overlap=maxf(max_overlap,p.radius+q.radius-p.pos.distance_to(q.pos))
    if previous.has(p.id) and previous.has(q.id):
     var r0:Vector2=previous[p.id]-previous[q.id];var dr:Vector2=(p.pos-q.pos)-r0
     var t:float=clampf(-r0.dot(dr)/maxf(.000001,dr.length_squared()),0,1)
     max_swept=maxf(max_swept,p.radius+q.radius-(r0+dr*t).length())
  previous=positions;frames.append(row)
 check(state.ready and state.pending.is_empty() and state.panels.size()==48,"six large plus42 ordinary settle within original bounds/time")
 check(state.panels.filter(func(p):return p.kind=="big_bomb" and p.radius==48).size()==6,"six actual large radii retained through settling")
 check(top_ok and walls_ok,"all entries from above and variable-radius wall/floor clearance")
 check(max_overlap<.2 and max_swept<.6,"dense variable bodies have no sampled or swept penetration")
 check(max_step<20 and uncaused==0,"continuous path and collision-caused lateral response only")
 var report:Dictionary={"fixture":true,"checks":checks,"failures":failures,"ready":state.ready,"elapsed":state.elapsed,"max_overlap":max_overlap,"max_swept":max_swept,"max_step":max_step,"uncaused":uncaused,"frames":frames,"profile":state.profile}
 FileAccess.open("res://evidence/bomb-volume/dense-trace.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print("BOMB_VOLUME checks=",checks," failures=",failures);quit(1 if failures else 0)

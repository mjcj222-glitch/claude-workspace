extends SceneTree
const Motion=preload("res://scripts/board_motion.gd")
const Bombs=preload("res://scripts/board_bombs.gd")
const BOUNDS=Rect2(30,290,660,530)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func grounded(bodies:Array)->bool:
 var reached:Dictionary={}
 for p in bodies:
  if absf(p.pos.y+p.radius-BOUNDS.end.y)<.25:reached[p.id]=true
 for repeat in range(bodies.size()):
  for p in bodies:
   if reached.has(p.id):continue
   for q in bodies:
    if reached.has(q.id) and q.pos.y>p.pos.y+.1 and p.pos.distance_to(q.pos)<=p.radius+q.radius+.25:reached[p.id]=true;break
 return reached.size()==bodies.size()
func run_case(state:Dictionary,label:String)->Dictionary:
 var previous:Dictionary={};var frames:Array=[];var overlap:=0.;var swept:=0.;var jump:=0.;var injected:=0;var top_ok:=true
 for p in state.panels:previous[p.id]=p.duplicate(true)
 while not state.ready and not state.stalled:
  Motion.step(state,BOUNDS,Motion.STEP)
  var next:Dictionary={};var row:Array=[]
  for p in state.panels:
   next[p.id]=p.duplicate(true);row.append([p.id,p.pos.x,p.pos.y,p.radius,p.vel.x,p.vel.y,p.get("contact_count",0)])
   if not previous.has(p.id):top_ok=top_ok and p.pos.y+p.radius<BOUNDS.position.y+1
   else:
    var before:Dictionary=previous[p.id];jump=maxf(jump,p.pos.distance_to(before.pos))
    # A past collision may legitimately leave lateral velocity. New lateral
    # acceleration from rest requires this tick's contact or a wall/floor.
    var collision_this_tick:bool=p.get("contact_count",0)>before.get("contact_count",0)
    var boundary:bool=p.pos.x-p.radius<=BOUNDS.position.x+.2 or p.pos.x+p.radius>=BOUNDS.end.x-.2 or p.pos.y+p.radius>=BOUNDS.end.y-.2
    if not collision_this_tick and not boundary and absf(before.vel.x)<.001 and absf(p.vel.x)>.001:injected+=1
   for q in state.panels:
    if p.id>=q.id:continue
    overlap=maxf(overlap,p.radius+q.radius-p.pos.distance_to(q.pos))
    if previous.has(p.id) and previous.has(q.id):
     var r0:Vector2=previous[p.id].pos-previous[q.id].pos;var dr:Vector2=(p.pos-q.pos)-r0
     var t:float=clampf(-r0.dot(dr)/maxf(.000001,dr.length_squared()),0,1)
     swept=maxf(swept,p.radius+q.radius-(r0+dr*t).length())
  previous=next;frames.append(row)
 check(state.ready,label+" ready within original limit")
 check(overlap<.2 and swept<.6,label+" intermediate and swept non-overlap")
 check(jump<20 and injected==0,label+" no teleport or injected airborne lateral velocity")
 check(top_ok,label+" all new bodies enter fully above")
 check(grounded(state.panels),label+" every settled body has downward contact path to floor")
 return {"fixture":true,"label":label,"ready":state.ready,"elapsed":state.elapsed,"max_overlap":overlap,"max_swept":swept,"max_step":jump,"injected_lateral":injected,"frames":frames,"profile":state.profile}
func _init()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=20261021
 var initial:Dictionary=Motion.initial_board(BOUNDS,48,1,rng)
 var survivors:Array=initial.panels.filter(func(p):return p.id not in [23,24])
 var state:Dictionary=Motion.start(survivors,BOUNDS,48,49,rng)
 Bombs.prepare_supply(state.pending,"big_bomb")
 var original:Dictionary={}
 for p in survivors:original[p.id]=p.pos
 for p in state.panels:check(p.pos==original[p.id],"mixed refill preserves survivor ID/start position")
 var reports:Array=[run_case(state,"mixed survivors large inlet")]
 var large:Dictionary=state.panels.filter(func(p):return p.id==49)[0]
 check(large.radius==48 and large.pos.y+48<BOUNDS.end.y-.25,"large settles on existing bodies rather than floor")
 var removed:Array=[]
 for q in state.panels:
  if q.id!=large.id and q.pos.y>large.pos.y+.1 and q.pos.distance_to(large.pos)<=q.radius+48+.25:removed.append(q.id)
 check(not removed.is_empty(),"actual below contacts selected for support-loss fixture")
 var start:Vector2=large.pos
 var next:Dictionary=Motion.start(state.panels.filter(func(p):return p.id not in removed),BOUNDS,48,state.next_id,rng)
 var support_report:Dictionary=run_case(next,"large support loss")
 var fallen:Dictionary=next.panels.filter(func(p):return p.id==49)[0]
 check(fallen.pos.y>start.y+1,"same large ID descends after actual supports removed")
 support_report["removed_supports"]=removed;support_report["large_before"]=start;support_report["large_after"]=fallen.pos
 reports.append(support_report)
 FileAccess.open("res://evidence/bomb-volume/support-traces.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":reports}))
 print("BOMB_SUPPORT checks=",checks," failures=",failures);quit(1 if failures else 0)

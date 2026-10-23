extends RefCounted
const Rules=preload("res://scripts/board_rules.gd")
static func best_skill(s)->Dictionary:
 var best:Dictionary={};var best_value:float=-INF
 for p in s.panels:
  if p.kind!="normal":continue
  for color in ([int(p.color)] if s.character_id=="noa" else range(4)):
   var plan:Dictionary=s.skill_plan_for(p.id,color)
   if not plan.valid:continue
   var value:float
   if s.character_id=="noa":
    var future:Array=s.panels.duplicate(true)
    for q in future:
     if q.id==p.id:q.kind=plan.planted[p.id]
    var ignition:Dictionary=Rules.plan(future,p.id,s.hp,s.max_hp,s.relics,s.combat.damage_context())
    value=ignition.damage*100.0+ignition.removed.size()
    if s.combat.mitigation_active and not s.combat.mitigation_success and ignition.mitigates_intent:value+=10000
   else:
    var changed:=0
    for q in s.panels:
     if q.id in plan.targets and q.color!=color:changed+=1
    if changed==0:continue
    value=plan.connected.size()*100+changed
   if value>best_value:best_value=value;best={"id":p.id,"point":p.pos,"color":color,"plan":plan}
 return best

# Deliberately poor but legal ordinary play: no heart prioritization and the
# least immediate damage, with intent avoidance only as a tie-breaker. Not a
# human skill/balance model. No HP, board, charge or currency injection.
static func weak_clear(s)->Dictionary:
 var best:Dictionary={};var score:float=INF
 for p in s.panels:
  var plan:Dictionary=s.plan_for(p.id)
  if not plan.valid:continue
  var value:float=plan.damage*100+plan.removed.size()+int(plan.mitigates_intent)*10
  if plan.damage==0:value+=100000
  if value<score:score=value;best={"id":p.id,"point":p.pos,"plan":plan}
 return best

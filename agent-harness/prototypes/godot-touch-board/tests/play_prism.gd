extends "res://tests/play_lifecycle.gd"
var petal_activations=0
func evidence_root()->String:return "res://evidence/prism/normal/"
func reward_choice()->int:return maxi(0,scene.session.reward_options.find("petal"))
func gesture(point:Vector2,hold:float=.35)->Dictionary:
 if movie and scene.session.phase=="ready" and not scene.session.skill_mode:
  for panel in scene.session.panels:
   if scene.board_to_screen(panel.pos).distance_to(point)<0.1 and scene.session.plan_for(panel.id).get("petal_guard",false):hold=maxf(hold,1.25)
 var result=await super.gesture(point,hold)
 if result.get("petal_guard",false):
  petal_activations+=1
  if not scene.session.combat.mitigation_success:errors.append("petal preview did not mitigate")
  record("petal_guard",{"preview":result,"activations":petal_activations})
  await snapshot("petal-guard-%02d"%petal_activations)
 return result
func best_clear()->Dictionary:
 var chosen=super.best_clear();var s=scene.session
 if "petal" in s.relics and s.combat.mitigation_active and not s.combat.mitigation_success and (chosen.is_empty() or chosen.plan.damage<s.combat.enemy_hp):
  for p in s.panels:
   var plan=s.plan_for(p.id)
   if plan.valid and plan.get("petal_guard",false):return {"id":p.id,"point":p.pos,"plan":plan}
 return chosen

func state()->Dictionary:
 var result=super.state()
 result["rain_remaining"]=scene.session.rain_remaining
 result["rain_color"]=scene.session.rain_color
 return result

func best_skill()->Dictionary:
 # Showcase a legal deliberate strategy: bank the ready skill before the boss,
 # then aim it at the displayed shield attribute. This is not game assistance.
 var s=scene.session
 if not movie:return super.best_skill()
 if s.current_node=="extra":return {}
 if s.current_node!="boss" or s.combat.shield_hp<=0:return super.best_skill()
 var best={};var score=-1
 for p in s.panels:
  if p.kind!="normal":continue
  if s.character_id=="noa" and p.color!=s.combat.shield_color:continue
  var color:int=s.combat.shield_color
  var plan=s.skill_plan_for(p.id,color)
  if plan.valid and plan.connected.size()>score:
   score=plan.connected.size();best={"id":p.id,"point":p.pos,"color":color,"plan":plan}
 return best if not best.is_empty() else super.best_skill()

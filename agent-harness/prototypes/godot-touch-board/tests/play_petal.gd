extends "res://tests/play_lifecycle.gd"
var petal_activations=0
func evidence_root()->String:return "res://evidence/petal/normal/"
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

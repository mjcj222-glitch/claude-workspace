extends "res://tests/test_checkpoint_process.gd"
func gesture(point:Vector2,hold:float=.01)->Dictionary:
 if scene.session.phase=="reward" and "petal" in scene.session.reward_options:
  point=scene.UI.reward_rect(scene.session.reward_options.find("petal"),scene.session.reward_options.size()).get_center()
 return await super.gesture(point,hold)
func best_clear()->Dictionary:
 var chosen=super.best_clear();var s=scene.session
 if "petal" in s.relics and s.combat.mitigation_active and not s.combat.mitigation_success and (chosen.is_empty() or chosen.plan.damage<s.combat.enemy_hp):
  for p in s.panels:
   var plan=s.plan_for(p.id)
   if plan.valid and plan.get("petal_guard",false):return {"id":p.id,"point":p.pos,"plan":plan}
 return chosen

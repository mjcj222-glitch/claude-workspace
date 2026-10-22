extends "res://tests/play_prism.gd"
func evidence_root()->String:return "res://evidence/resonance/normal/"
func state()->Dictionary:
 var result=super.state()
 result["pending_damage"]=scene.session.combat.pending_damage
 result["pending_shield"]=scene.session.combat.pending_shield
 result["bank_actions"]=scene.session.combat.actions_in_turn
 return result

extends "res://tests/play_lifecycle.gd"
var seen_turns={}
func evidence_root()->String:return "res://evidence/seed-audit/runs/"
func state()->Dictionary:
 var result=super.state()
 result.erase("panels")
 return result
func record(type:String,details:Dictionary={})->void:
 var row=state();row["type"]=type;row["details"]=details
 events.append(row)
func best_clear()->Dictionary:
 var s=scene.session
 var key=s.current_node+":"+str(s.combat.intent_serial)
 if not seen_turns.has(key):
  seen_turns[key]=true
  var legal=0;var qualifying=0;var direct_max=0;var normal_max=0;var weak_max=0
  for p in s.panels:
   var plan=s.plan_for(p.id)
   if not plan.get("valid",false):continue
   legal+=1
   if plan.get("mitigates_intent",false):qualifying+=1
   direct_max=maxi(direct_max,plan.get("direct",[]).size())
   normal_max=maxi(normal_max,plan.get("normal_count",0));weak_max=maxi(weak_max,plan.get("weak_count",0))
  record("intent_audit",{"legal_start_panels":legal,"qualifying_start_panels":qualifying,"direct_max":direct_max,"normal_max":normal_max,"weak_max":weak_max,"first_action":s.combat.actions_in_turn==0})
  if s.combat.mitigation_active and not s.combat.mitigation_success and s.combat.actions_in_turn==0 and qualifying==0:errors.append("unsatisfiable advertised intent: "+key)
 return super.best_clear()
func gesture(point:Vector2,hold:float=.35)->Dictionary:
 if "--audit-shop-buy" in OS.get_cmdline_user_args() and scene.session.phase=="shop" and point==scene.UI.SUMMARY_CONTINUE.get_center():
  var s=scene.session
  for item in ["relic","heal"]:
   var eligible=s.gold>=(8 if item=="relic" else 4) and (not s.shop_relic_sold and s.shop_remaining_relic()!="" if item=="relic" else not s.shop_heal_sold and s.shop_heal_gain()>0)
   if eligible:
    await gesture(scene.UI.shop_rect(1 if item=="relic" else 0).get_center())
    record("shop_purchase",{"item":item,"audit_shop_policy":true})
 var hp=scene.session.hp;var enemy=scene.session.combat.enemy_hp
 var preview=await super.gesture(point,hold)
 if preview.get("valid",false) and preview.get("mode","")=="clear":
  if scene.session.combat.enemy_hp!=maxi(0,enemy-preview.damage):errors.append("enemy damage differs from preview")
  if scene.session.hp!=mini(scene.session.max_hp,hp+preview.get("heal_effective",0)):errors.append("HP healing differs from preview")
 return preview

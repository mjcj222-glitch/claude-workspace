extends SceneTree
const Rules = preload("res://scripts/board_rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)

func p(id: int, x: float, color: int = 0, kind: String = "normal", y: float = 0) -> Dictionary:
	return {"id":id,"pos":Vector2(x,y),"radius":10.0,"color":color,"kind":kind}

func line(count: int, color: int = 0, kind: String = "normal") -> Array:
	var panels: Array=[]
	for id in range(count): panels.append(p(id,20*id,color,kind))
	return panels

func context(weak: int = 0, intent: String = "plain") -> Dictionary:
	return {"weakness_color":weak,"intent":intent,"intent_serial":7,"incoming_damage":8,"mitigation_success":false}

func _init() -> void:
	for w in range(5):
		var panels: Array=[p(0,0,0,"core")]
		for id in range(1,w+1): panels.append(p(id,20*id))
		var result: Dictionary=Rules.plan(panels,0,10,20,[],context())
		check(result.valid and result.weak_count==w and result.weak_bonus==int(w/2), "W%d bonus floors once" % w)
		check(result.base_damage==w and result.damage==w+int(w/2) and result.normal_count==w, "W%d base ordinary formula preserved" % w)
		check(result.effective_colors.size()==w and not result.effective_colors.has(0), "W%d effective colors exclude core" % w)
		check(not result.mitigates_intent, "W%d plain intent never mitigated" % w)
	var waves: Array=[p(0,0,0,"strong"),p(1,20,1,"core"),p(2,40,0,"core"),p(3,-20,1),p(4,60,1)]
	var wave_result: Dictionary=Rules.plan(waves,0,10,20,[],context())
	check(wave_result.activated==[0,1,2] and wave_result.normal_count==2, "two normals clear through distinct core waves")
	check(wave_result.weak_count==2 and wave_result.weak_bonus==1 and wave_result.damage==3, "separate one-weak waves aggregate before rounding")
	check(wave_result.effective_colors=={3:0,4:0}, "wave effective colors use final conversion")
	waves[2].color=1
	var mixed: Dictionary=Rules.plan(waves,0,10,20,[],context())
	check(mixed.normal_count==2 and mixed.weak_count==1 and mixed.weak_bonus==0 and mixed.damage==2, "mixed final attack colors count only weakness")
	check(mixed.effective_colors=={3:0,4:1}, "mixed waves retain per-panel effective color")
	var conversion: Array=[p(0,0,0,"core"),p(1,20,1),p(2,40,0)]
	var converted_in: Dictionary=Rules.plan(conversion,0,10,20,[],context(0))
	var converted_out: Dictionary=Rules.plan(conversion,0,10,20,[],context(1))
	check(converted_in.weak_count==2 and converted_in.damage==3, "conversion into weakness increases weak count")
	check(converted_out.weak_count==0 and converted_out.damage==2, "conversion out of weakness removes weak eligibility")
	var conflict: Array=[p(0,0,0,"strong"),p(1,20,1,"core"),p(2,10,1,"normal",17)]
	var conflict_result: Dictionary=Rules.plan(conflict,0,10,20,[],context(0))
	check(conflict_result.activated==[0,1] and conflict_result.effective_colors=={2:0} and conflict_result.weak_count==1, "first-claim conflict color remains canonical for weakness")
	var surviving: Array=[p(0,0,0,"strong"),p(1,20,1,"core"),p(2,40,2)]
	var surviving_result: Dictionary=Rules.plan(surviving,0,10,20,[],context(0))
	check(surviving_result.converted.get(2)==0 and not surviving_result.removed.has(2), "fixture has converted but unremoved normal")
	check(surviving_result.weak_count==0 and surviving_result.normal_count==0 and surviving_result.effective_colors.is_empty() and surviving_result.damage==0, "unremoved conversion earns no weakness or base damage")
	var duplicate: Array=[p(0,0),p(0,20)]
	var invalid: Dictionary=Rules.plan(duplicate,0,10,20,[],context(0,"slam"))
	check(not invalid.valid and invalid.damage==0 and invalid.base_damage==0 and invalid.weak_count==0 and invalid.normal_count==0 and not invalid.mitigates_intent, "duplicate input IDs invalid with safe elemental defaults")
	var spawned: Dictionary=Rules.plan(line(6),0,10,20,["ash"],context())
	check(spawned.spawn.kind=="core" and spawned.activated.is_empty() and spawned.normal_count==6 and spawned.weak_count==6 and spawned.damage==9, "protected new core never adds weakness or base damage")
	check(spawned.ash_reserve and spawned.direct_normals==6, "elemental damage leaves ash direct-count trigger unchanged")
	var lens: Dictionary=Rules.plan(line(5),0,10,20,["lens","ash"],context())
	check(lens.spawn.kind=="core" and lens.direct_normals==5 and not lens.ash_reserve, "lens five-normal threshold remains independent of bonus damage")
	var hearts: Dictionary=Rules.plan(line(4,4,"heart"),0,18,20,[],context(4,"direct4"))
	check(hearts.damage==0 and hearts.base_damage==0 and hearts.weak_count==0 and hearts.normal_count==0 and hearts.effective_colors.is_empty(), "hearts excluded from every attack count")
	check(hearts.heal_raw==8 and hearts.heal_effective==2 and hearts.heal_overflow==6 and hearts.mitigates_intent, "heart healing unchanged and direct-four intent still qualifies")
	var cores: Dictionary=Rules.plan(line(4,0,"core"),0,10,20,[],context(0,"direct4"))
	check(cores.weak_count==0 and cores.normal_count==0 and cores.damage==0 and cores.mitigates_intent, "existing cores have no intrinsic damage but direct-four qualifies")
	for count in [7,8]:
		var r: Dictionary=Rules.plan(line(count,1),0,10,20,[],context(0,"slam"))
		check(r.weak_count==0 and r.mitigates_intent==(count>=8), "slam normal threshold %d uses actual normal removals" % count)
	for w in [1,2]:
		var panels: Array=[p(0,0,0,"core")]
		for id in range(1,w+1): panels.append(p(id,id*20))
		var r: Dictionary=Rules.plan(panels,0,10,20,[],context(0,"slam"))
		check(r.mitigates_intent==(w>=2), "slam weakness threshold W%d" % w)
	var non_slam: Dictionary=Rules.plan(line(8),0,10,20,[],context(0,"unknown"))
	check(not non_slam.mitigates_intent, "unknown intent does not acquire implicit conditions")
	var solo_direct: Dictionary=Rules.plan(conversion,0,10,20,[],context(0,"direct4"))
	check(solo_direct.direct.size()==1 and not solo_direct.mitigates_intent, "core chain extras do not satisfy direct-four intent")
	var no_context: Dictionary=Rules.plan(line(4),0,10,20)
	check(no_context.damage==4 and no_context.base_damage==4 and no_context.weak_count==0 and no_context.weak_bonus==0 and no_context.normal_count==4 and no_context.combat_context.is_empty(), "default no-context calls preserve old damage formula")
	var frozen_context:=context(0,"slam")
	frozen_context["nested"]={"ids":[1,2]}
	var before:=conversion.duplicate(true)
	var frozen: Dictionary=Rules.plan(conversion,0,10,20,[],frozen_context)
	frozen_context.weakness_color=1
	frozen_context.intent="plain"
	frozen_context.nested.ids.append(3)
	check(frozen.combat_context.weakness_color==0 and frozen.combat_context.intent=="slam" and frozen.combat_context.nested.ids==[1,2], "combat context is deeply frozen")
	check(frozen.damage==3 and frozen.mitigates_intent and conversion==before, "later context mutation cannot change computed outcome or input panels")
	var skill: Dictionary=Rules.skill_plan(line(4),0,1)
	check(not skill.has("damage") and not skill.has("weak_bonus"), "free skill does not gain elemental damage fields")
	print("ELEMENTAL RULES checks=",checks," failures=",failures)
	quit(1 if failures else 0)

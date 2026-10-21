extends RefCounted
## Pure presentation: no timers, input handlers, game RNG, or phase ownership.
const Art = preload("res://scripts/board_art.gd")
const CUTIN_SECONDS := 0.5
const TRAIL_LIMIT := 48
const TOTAL_SECONDS := 0.9
const CUTIN_RECT := Rect2(8,920,688,160)
const FACE_REGION := Rect2(250,180,590,590.0*160.0/230.0)
const HEAL_STRIP := Rect2(32,272,656,32)
var cutin_remaining := 0.0
var total_remaining := 0.0
var damage_amount := 0
var heal_raw := 0
var heal_effective := 0
var heal_overflow := 0
var trails: Array = []
var _eligible: Dictionary = {}
var _seen: Dictionary = {}
var _active := false
var _finished := false
var reduced_effects := false
var impact_remaining := 0.0
var impact_tier := 0
var weak_bonus := 0
var base_damage := 0
var core_activations := 0
var strong_cores:=0
var bomb_activations:=0
var skill_link := false
var _skill_converted:Dictionary={}
var _elapsed := 0.0
var _impact_due := 0.0
var _impacted := false
var _pending_impact: Dictionary = {}
var _hp_before := -1
var _hp_after := -1
const IMPACT_SECONDS := 0.24
var _effects_rng := RandomNumberGenerator.new()

func _init() -> void:
	_effects_rng.seed = 0x5049474D454E54

func _clear_action() -> void:
	total_remaining = 0.0
	impact_remaining = 0.0
	_elapsed=0.0
	_impact_due=0.0
	_impacted=false
	_pending_impact.clear()
	_hp_before=-1
	_hp_after=-1
	weak_bonus=0
	base_damage=0
	core_activations=0
	strong_cores=0
	bomb_activations=0
	skill_link=false
	damage_amount = 0
	heal_raw = 0
	heal_effective = 0
	heal_overflow = 0
	trails.clear()
	_eligible.clear()
	_seen.clear()
	_active = false
	_finished = false

func reset() -> void:
	_clear_action()
	cutin_remaining = 0.0
	_skill_converted.clear()

func skill_activated(changed:Dictionary={}) -> void:
	cutin_remaining = CUTIN_SECONDS
	_skill_converted=changed.duplicate()

func action_started(plan: Dictionary, panels: Array, impact_due: float=0.0, enemy_hp_before: int=-1) -> void:
	_clear_action()
	if not plan.get("valid", false) or plan.get("mode", "clear") != "clear":
		return
	var actual: Dictionary = {}
	for panel in panels:
		if panel.has("id"):
			actual[int(panel.id)] = panel.get("kind", "normal")
	for id in plan.get("removed", []):
		if actual.has(int(id)):
			_eligible[int(id)] = actual[int(id)]
	_active = not _eligible.is_empty()
	if not _active: return
	# Use the committed final figures, never re-derive damage from effect counts.
	damage_amount = int(plan.get("damage", 0))
	base_damage=int(plan.get("base_damage",damage_amount))
	weak_bonus=int(plan.get("weak_bonus",0))
	var unique_cores:Dictionary={}
	for id in plan.get("activated",[]):
		if _eligible.has(int(id)) and actual.get(int(id),"") in ["core","strong"]:unique_cores[int(id)]=true
	core_activations=unique_cores.size()
	for id in unique_cores:
		if actual[id]=="strong":strong_cores+=1
	var bombs:Dictionary={}
	for id in plan.get("activated",[]):
		if _eligible.has(int(id)) and actual.get(int(id),"") in ["bomb","big_bomb"]:bombs[int(id)]=true
	bomb_activations=bombs.size()
	impact_tier=2 if _eligible.size()>=12 or core_activations>0 or bomb_activations>0 else (1 if _eligible.size()>=6 else 0)
	skill_link=false
	for id in _eligible:
		if _eligible[id]=="normal" and _skill_converted.has(id) and not plan.get("converted",{}).has(id) and plan.get("effective_colors",{}).get(id,_skill_converted[id])==_skill_converted[id]:skill_link=true
	_skill_converted.clear()
	_impact_due=maxf(0.0,impact_due)
	_hp_before=enemy_hp_before
	_hp_after=maxi(0,_hp_before-damage_amount)
	heal_raw = int(plan.get("heal_raw", 0))
	heal_effective = int(plan.get("heal_effective", 0))
	heal_overflow = int(plan.get("heal_overflow", 0))

func panel_removed(id: int, pos: Vector2, color: Color, _kind: String) -> bool:
	if not _active or _finished or not _eligible.has(id) or _seen.has(id):
		return false
	_seen[id] = true
	var actual_kind: String = _eligible[id]
	# Existing feedback owns core rings/shards. Delivery cues distinguish
	# damage (including core objects) from heart healing and overflow.
	if actual_kind in ["normal","heart","core","strong","bomb","big_bomb"]:
		if trails.size() >= TRAIL_LIMIT: trails.pop_front()
		trails.append({"pos":pos,"color":color,"age":0.0,
			"life":maxf(0.05,_impact_due-_elapsed) if actual_kind!="heart" and _impact_due>0 else _effects_rng.randf_range(0.22,0.32),
			"core":actual_kind in ["core","strong","bomb","big_bomb"],
			"bend":_effects_rng.randf_range(-40.0,40.0),
			"kind":"heal" if actual_kind=="heart" else "damage"})
	return true

func action_finished() -> void:
	if not _active or _finished: return
	_finished = true
	total_remaining = TOTAL_SECONDS

func take_impact() -> Dictionary:
	var event:=_pending_impact
	_pending_impact={}
	return event

func display_enemy_hp(actual: int) -> int:
	if _hp_before<0 or damage_amount<=0:return actual
	if not _impacted:return _hp_before
	var t:=clampf((IMPACT_SECONDS-impact_remaining)/0.14,0,1)
	return int(ceil(lerpf(_hp_before,_hp_after,1.0-pow(1.0-t,2))))

func stage_offset() -> Vector2:
	if reduced_effects or impact_remaining<=0:return Vector2.ZERO
	var t:float=1.0-impact_remaining/IMPACT_SECONDS
	var recoil:float=sin(t*PI*3.0)*pow(1.0-t,2)
	return Vector2(9+impact_tier*4,-4)*recoil

func hit_flash() -> float:
	if reduced_effects or impact_remaining<=0:return 0.0
	return maxf(0.0,1.0-(IMPACT_SECONDS-impact_remaining)/0.075)

func update(delta: float) -> void:
	var dt := maxf(0.0,delta)
	_elapsed+=dt
	impact_remaining=maxf(0,impact_remaining-dt)
	if _finished and not _impacted and _elapsed>=_impact_due and damage_amount>0:
		_impacted=true
		impact_remaining=IMPACT_SECONDS
		_pending_impact={"damage":damage_amount,"base_damage":base_damage,"weak_bonus":weak_bonus,"cores":core_activations,"strong_cores":strong_cores,"bombs":bomb_activations,"tier":impact_tier,"skill_link":skill_link}
	cutin_remaining = maxf(0.0,cutin_remaining-dt)
	total_remaining = maxf(0.0,total_remaining-dt)
	for i in range(trails.size()-1,-1,-1):
		trails[i].age += dt
		if trails[i].age >= trails[i].life: trails.remove_at(i)

func _curve(a: Vector2,b: Vector2,bend: float,t: float) -> Vector2:
	var control := a.lerp(b,0.5)+Vector2(bend,-45)
	return a.lerp(control,t).lerp(control.lerp(b,t),t)

func _font(view,key: String) -> Font:
	var candidate = view.get(key)
	return candidate if candidate is Font else view.font

func _text(canvas,font: Font,point: Vector2,text: String,size: int,color: Color,outline: int=2) -> void:
	var origin := point-Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.5,0)
	canvas.draw_string_outline(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline,Color(0.02,0.04,0.06,color.a))
	canvas.draw_string(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func draw_overlay(view,canvas) -> void:
	var target: Vector2 = Art.impact_point(-1 if view.get("sandbox")==true else (view.session.combat.encounter if view.get("session")!=null else 0))
	var hero: Vector2 = view.UI.HERO_RECT.get_center()
	for trail in trails:
		var start: Vector2 = view.board_to_screen(trail.pos)
		var destination: Vector2 = hero if trail.kind=="heal" else target
		var t: float = clampf(trail.age/trail.life,0.0,1.0)
		if reduced_effects:
			canvas.draw_line(start,destination,Color(trail.color,0.18*(1.0-t)),1.5,true)
			continue
		var head := _curve(start,destination,trail.bend,t)
		var tint: Color = Color("ffb6d8") if trail.kind=="heal" else trail.color.lightened(0.28)
		tint.a = sin(PI*t)*0.78
		var previous := _curve(start,destination,trail.bend,maxf(0.0,t-0.18))
		for segment in range(1,7):
			var at := lerpf(maxf(0.0,t-0.18),t,float(segment)/6.0)
			var current := _curve(start,destination,trail.bend,at)
			var tail_color := tint
			tail_color.a *= float(segment)/6.0
			canvas.draw_line(previous,current,tail_color,1.0+float(segment)*0.32,true)
			previous = current
		canvas.draw_line(previous,head,Color(1,0.96,0.82,tint.a),4.0 if trail.get("core",false) else 2.0,true)
		canvas.draw_circle(head,8.0 if trail.get("core",false) else 4.8,Color(1.0,1.0,0.95,tint.a))
		if trail.kind=="heal":
			canvas.draw_colored_polygon(Art._heart_points(head+Vector2(0,-5),5.0),tint)
	if impact_remaining>0:
		var t:float=1.0-impact_remaining/IMPACT_SECONDS
		var strength:float=1.0+impact_tier*0.45+minf(strong_cores+bomb_activations,2)*0.15
		var tint:=Color("e6c2ff") if weak_bonus>0 else Color("ffe2ab")
		tint.a=(1.0-t)*0.8
		if reduced_effects:
			canvas.draw_arc(target,24,0,TAU,24,Color(tint,0.3*(1.0-t)),2,true)
		else:
			canvas.draw_arc(target,lerpf(10,65*strength,t),0,TAU,40,Color(.16,.025,.24,(1-t)*.78),9*(1-t)+1,true)
			canvas.draw_arc(target,lerpf(10,65*strength,t),0,TAU,40,tint,5*(1.0-t)+1,true)
			canvas.draw_arc(target,lerpf(7,46*strength,t),0,TAU,32,Color(1,.95,.8,tint.a*.65),2.5*(1-t)+.6,true)
			if t<.30:
				var shape:=PackedVector2Array()
				for i in range(8):
					shape.append(target+Vector2.from_angle(i*TAU/8+.18)*32*strength*(1-t/.30)*(1.0 if i%2==0 else .26))
				var shadow:=PackedVector2Array()
				for point in shape:shadow.append(target+(point-target)*1.18)
				canvas.draw_colored_polygon(shadow,Color(.28,.035,.38,(1-t/.30)*.9))
				canvas.draw_colored_polygon(shape,Color(1,.92,.72,(1-t/.30)*.85))
			for i in range(6+impact_tier*3):
				var angle:float=TAU*i/(6+impact_tier*3)
				var direction:=Vector2.from_angle(angle)
				canvas.draw_line(target+direction*(9+t*18),target+direction*(18+t*58*strength),tint,4.0*(1.0-t)+0.5,true)
	var body := _font(view,"font_body")
	var display := _font(view,"font_display")
	if total_remaining > 0.0:
		var alpha := minf(1.0,total_remaining/0.23)
		var rise := (1.0-total_remaining/TOTAL_SECONDS)*14.0
		if damage_amount > 0 and _impacted:
			_text(canvas,display,target+Vector2(-55,-38-(0 if reduced_effects else rise)),str(damage_amount),54,Color(1.0,0.89,0.60,alpha),4)
			if weak_bonus>0:_text(canvas,body,target+Vector2(-55,-12),"약점 +%d"%weak_bonus,22,Color(0.9,0.75,1,alpha))
			elif core_activations>0:_text(canvas,body,target+Vector2(-55,-12),"핵 연쇄",22,Color(1,0.85,0.5,alpha))
			elif skill_link and impact_tier>0:_text(canvas,body,target+Vector2(-55,-12),"변환 연계",22,Color(0.9,0.75,1,alpha))
		if heal_raw > 0:
			var a := HEAL_STRIP.position
			var b := HEAL_STRIP.end
			canvas.draw_colored_polygon(PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),Color(0.045,0.065,0.09,0.96*alpha))
			_text(canvas,body,Vector2(360,296),"회복 +%d · 초과 %d (전체 %d)" % [heal_effective,heal_overflow,heal_raw],22,Color(1.0,0.75,0.87,alpha))
	if cutin_remaining <= 0.0: return
	# Footer-only strip: board, targeting palette and reset/cancel remain exposed.
	var age := CUTIN_SECONDS-cutin_remaining
	var alpha := minf(1.0,age/0.055)*minf(1.0,cutin_remaining/0.12)
	var slide := (0.0 if reduced_effects else 14.0)*(1.0-minf(1.0,age/0.10))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(210,920),Vector2(696,920),Vector2(669,1080),Vector2(210,1080)]),Color(0.14,0.055,0.23,0.96*alpha))
	canvas.draw_texture_rect_region(Art.HERO_TEXTURE,Rect2(8,920,230,160),FACE_REGION,Color(1,1,1,alpha))
	# Clip the face's right edge with the same strip color, preserving eyes/mouth.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(238,920),Vector2(238,1080),Vector2(210,1080)]),Color(0.14,0.055,0.23,alpha))
	canvas.draw_line(Vector2(238,920),Vector2(210,1080),Color(0.85,0.74,0.43,alpha),3.0,true)
	var identity:Dictionary=preload("res://scripts/board_characters.gd").definition(view.session.character_id if view.get("session")!=null else "rio")
	_text(canvas,body,Vector2(435+slide,972),identity.name+" · "+identity.role,22,Color(0.88,0.74,0.96,alpha))
	_text(canvas,display,Vector2(435+slide,1030),identity.skill,34,Color(0.96,0.92,0.73,alpha),3)

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
var _effects_rng := RandomNumberGenerator.new()

func _init() -> void:
	_effects_rng.seed = 0x5049474D454E54

func _clear_action() -> void:
	total_remaining = 0.0
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

func skill_activated() -> void:
	cutin_remaining = CUTIN_SECONDS

func action_started(plan: Dictionary, panels: Array) -> void:
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
	heal_raw = int(plan.get("heal_raw", 0))
	heal_effective = int(plan.get("heal_effective", 0))
	heal_overflow = int(plan.get("heal_overflow", 0))

func panel_removed(id: int, pos: Vector2, color: Color, _kind: String) -> bool:
	if not _active or _finished or not _eligible.has(id) or _seen.has(id):
		return false
	_seen[id] = true
	var actual_kind: String = _eligible[id]
	# Existing feedback owns core rings/shards. These ribbons are only delivery
	# cues for normal damage and heart healing, including fully overhealed hearts.
	if actual_kind == "normal" or actual_kind == "heart":
		if trails.size() >= TRAIL_LIMIT: trails.pop_front()
		trails.append({"pos":pos,"color":color,"age":0.0,
			"life":_effects_rng.randf_range(0.36,0.52),
			"bend":_effects_rng.randf_range(-40.0,40.0),
			"kind":"heal" if actual_kind=="heart" else "damage"})
	return true

func action_finished() -> void:
	if not _active or _finished: return
	_finished = true
	total_remaining = TOTAL_SECONDS

func update(delta: float) -> void:
	var dt := maxf(0.0,delta)
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
	var target: Vector2 = view.UI.TARGET_RECT.get_center()
	var hero: Vector2 = view.UI.HERO_RECT.get_center()
	for trail in trails:
		var start: Vector2 = view.board_to_screen(trail.pos)
		var destination: Vector2 = hero if trail.kind=="heal" else target
		var t: float = clampf(trail.age/trail.life,0.0,1.0)
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
		canvas.draw_circle(head,3.0,Color(1.0,1.0,0.95,tint.a))
		if trail.kind=="heal":
			canvas.draw_colored_polygon(Art._heart_points(head+Vector2(0,-5),5.0),tint)
	var body := _font(view,"font_body")
	var display := _font(view,"font_display")
	if total_remaining > 0.0:
		var alpha := minf(1.0,total_remaining/0.23)
		var rise := (1.0-total_remaining/TOTAL_SECONDS)*14.0
		if damage_amount > 0:
			_text(canvas,display,target+Vector2(0,15-rise),str(damage_amount),48,Color(1.0,0.89,0.60,alpha),4)
		if heal_raw > 0:
			var a := HEAL_STRIP.position
			var b := HEAL_STRIP.end
			canvas.draw_colored_polygon(PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),Color(0.045,0.065,0.09,0.96*alpha))
			_text(canvas,body,Vector2(360,296),"회복 +%d · 초과 %d (전체 %d)" % [heal_effective,heal_overflow,heal_raw],22,Color(1.0,0.75,0.87,alpha))
	if cutin_remaining <= 0.0: return
	# Footer-only strip: board, targeting palette and reset/cancel remain exposed.
	var age := CUTIN_SECONDS-cutin_remaining
	var alpha := minf(1.0,age/0.055)*minf(1.0,cutin_remaining/0.12)
	var slide := 14.0*(1.0-minf(1.0,age/0.10))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(210,920),Vector2(696,920),Vector2(669,1080),Vector2(210,1080)]),Color(0.14,0.055,0.23,0.96*alpha))
	canvas.draw_texture_rect_region(Art.HERO_TEXTURE,Rect2(8,920,230,160),FACE_REGION,Color(1,1,1,alpha))
	# Clip the face's right edge with the same strip color, preserving eyes/mouth.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(238,920),Vector2(238,1080),Vector2(210,1080)]),Color(0.14,0.055,0.23,alpha))
	canvas.draw_line(Vector2(238,920),Vector2(210,1080),Color(0.85,0.74,0.43,alpha),3.0,true)
	_text(canvas,body,Vector2(435+slide,972),"리오 · 변환사",22,Color(0.88,0.74,0.96,alpha))
	_text(canvas,display,Vector2(435+slide,1030),"물감 변환",34,Color(0.96,0.92,0.73,alpha),3)

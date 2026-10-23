extends RefCounted
const MaterialArt = preload("res://scripts/board_skin.gd")
## Presentation only: canonical counters never mutate the plan or gameplay RNG.
## Call start only after commit, consume for each clear event, finish once all
## clears resolve. reset cancels presentation without crediting pending IDs.
const PARTICLE_LIMIT := 320
const RING_LIMIT := 24
const HOLD_SECONDS := 1.3
const FADE_SECONDS := 0.4
var reduced_effects := false
var count: int = 0
var core_count: int = 0
var expected_count: int = 0
var total_cores: int = 0
var finished: bool = false
var visible: bool = false
var particles: Array = []
var rings: Array = []
var _eligible: Dictionary = {}
var _cores: Dictionary = {}
var _core_kinds:Dictionary={}
var bomb_count:=0
var total_bombs:=0
var _bombs:Dictionary={}
var _consumed: Dictionary = {}
var _active: bool = false
var _finish_age: float = 0.0
var _pulse: float = 0.0
var _clock: float = 0.0
var _step_age:float=0.0
var _last_color:=Color.WHITE
# Dedicated generator. Effects can change without advancing session randomness.
var _effects_rng := RandomNumberGenerator.new()

func _init() -> void:
	_effects_rng.seed = 0x4348524F4D41

func start(plan: Dictionary, panels: Array) -> void:
	reset()
	var actual: Dictionary = {}
	for p in panels:
		if p is Dictionary and p.has("id") and not actual.has(int(p.id)):
			actual[int(p.id)] = p.get("kind", "normal")
	for id in plan.get("removed", []):
		if actual.has(int(id)):
			_eligible[int(id)] = true
	# Activation must name an actual removed core: malformed plans cannot
	# fabricate activation for a surviving special panel at finish.
	for id in plan.get("activated", []):
		if _eligible.has(int(id)) and actual.get(int(id), "") in ["core", "strong"]:
			_cores[int(id)] = true
			_core_kinds[int(id)]=actual[int(id)]
		elif _eligible.has(int(id)) and actual.get(int(id), "") in ["bomb","big_bomb"]:
			_bombs[int(id)]=actual[int(id)]
	expected_count = _eligible.size()
	total_cores = _cores.size()
	total_bombs=_bombs.size()
	_active = expected_count > 0

func consume(id: int, pos: Vector2, color: Color) -> bool:
	if not _active or finished or not _eligible.has(id) or _consumed.has(id):
		return false
	_consumed[id] = true
	count += 1
	_step_age=0.0
	_last_color=color
	var is_core := _cores.has(id)
	if is_core:
		core_count += 1
	visible = true
	_pulse = 1.0 if is_core or _bombs.has(id) else (0.75 if count % 4 == 0 else 0.35)
	if _bombs.has(id):bomb_count+=1
	_burst(pos, color, String(_bombs.get(id,_core_kinds.get(id,"normal"))))
	return true

func finish() -> void:
	if not _active or finished:
		return
	count = expected_count
	core_count = total_cores
	bomb_count=total_bombs
	finished = true
	visible = count > 0
	_finish_age = 0.0
	_pulse = 1.0

func reset() -> void:
	count = 0
	bomb_count=0
	total_bombs=0
	_bombs.clear()
	_core_kinds.clear()
	core_count = 0
	expected_count = 0
	total_cores = 0
	finished = false
	visible = false
	_active = false
	_finish_age = 0.0
	_pulse = 0.0
	_clock = 0.0
	_step_age=0.0
	_eligible.clear()
	_cores.clear()
	_consumed.clear()
	particles.clear()
	rings.clear()

func _burst(pos: Vector2, color: Color, kind:String) -> void:
	var is_core:=kind in ["core","strong","bomb","big_bomb"]
	var large:=kind in ["strong","big_bomb"]
	var bomb:=kind in ["bomb","big_bomb"]
	var strength := clampf(float(count) / 20.0, 0.2, 1.0)
	var amount := 0 if reduced_effects else 13 + int(strength * 7.0) + (12 if is_core else 0)
	for i in range(amount):
		if particles.size() >= PARTICLE_LIMIT:
			particles.pop_front()
		var angle := TAU * float(i) / float(amount) + _effects_rng.randf_range(-0.16, 0.16)
		var speed := _effects_rng.randf_range(95.0, 245.0) * (1.65 if large else (1.3 if is_core else 1.0))
		var tint := color.lerp(Color.WHITE, _effects_rng.randf_range(0.1, 0.7))
		if i % 5 == 0:
			tint = Color.from_hsv(fposmod(color.h + _effects_rng.randf_range(-0.14, 0.14), 1.0), 0.52, 1.0)
		particles.append({"pos":pos, "velocity":Vector2.from_angle(angle)*speed,
			"age":0.0, "life":_effects_rng.randf_range(0.18, 0.36) if bomb else _effects_rng.randf_range(0.28, 0.62),
			"size":_effects_rng.randf_range(3.2, 7.2), "angle":angle,
			"spin":_effects_rng.randf_range(-7.0, 7.0), "color":tint, "shard":false})
	_add_ring(pos, color.lightened(0.24), 0.0, 0.32, 48.0 + strength*15.0, false)
	_add_ring(pos, Color.WHITE, 0.0, 0.11, 29.0, true)
	if bomb:
		var blast:float=164.0 if kind=="big_bomb" else 98.0
		# Same clear event as the explosion audio; short waves leave refill readable.
		_add_ring(pos, color.lightened(0.35), 0.0, 0.20, blast*.85, false, true)
		_add_ring(pos, color.lightened(0.5), 0.06, 0.26, blast, false, true)
	elif is_core:
		# Three staggered concentric waves clearly separate core activation.
		_add_ring(pos, color.lightened(0.35), 0.03, 0.43, (158.0 if large else 100.0), false, true)
		_add_ring(pos, Color("ffe4a1"), 0.10, 0.48, (182.0 if large else 124.0), false, true)
		_add_ring(pos, color.lightened(0.5), 0.19, 0.51, (208.0 if large else 142.0), false, true)

func _add_ring(pos: Vector2, color: Color, delay: float, life: float, radius: float, flash: bool, core_priority: bool = false) -> void:
	if rings.size() >= RING_LIMIT:
		var replace_index := -1
		for i in range(rings.size()):
			if not rings[i].core_priority:
				replace_index = i
				break
		if replace_index >= 0:
			rings.remove_at(replace_index)
		elif core_priority:
			rings.pop_front()
		else:
			return
	rings.append({"pos":pos,"color":color,"age":-delay,"life":life,"radius":radius,"flash":flash,"core_priority":core_priority})

func update(delta: float) -> void:
	var dt := maxf(0.0, delta)
	_clock += dt
	_step_age+=dt
	_pulse = maxf(0.0, _pulse - dt*5.0)
	for i in range(particles.size()-1, -1, -1):
		var p: Dictionary = particles[i]
		p.age += dt
		if p.age >= p.life:
			particles.remove_at(i)
			continue
		p.pos += p.velocity*dt
		p.velocity.y += 170.0*dt
		p.angle += p.spin*dt
	for i in range(rings.size()-1, -1, -1):
		rings[i].age += dt
		if rings[i].age >= rings[i].life:
			rings.remove_at(i)
	if finished:
		_finish_age += dt
		if _finish_age >= HOLD_SECONDS + FADE_SECONDS:
			visible = false

func draw_effects(canvas: CanvasItem) -> void:
	if reduced_effects:return
	for ring in rings:
		if ring.age < 0.0:
			continue
		var t: float = clampf(ring.age / ring.life, 0.0, 1.0)
		var tint: Color = ring.color
		if ring.flash:
			tint.a = 0.34 * (1.0-t) * (1.0-t)
			canvas.draw_circle(ring.pos, ring.radius*(0.65+0.35*t), tint)
		else:
			var radius: float = lerpf(10.0, ring.radius, 1.0-pow(1.0-t, 2.0))
			tint.a = 0.85*(1.0-t)
			canvas.draw_arc(ring.pos, radius, 0, TAU, 48, tint, 3.5*(1.0-t)+0.7, true)
	for p in particles:
		var t: float = p.age/p.life
		var tint: Color = p.color
		tint.a = (1.0-t)*(1.0-t)
		var extent: float = p.size*(1.0-0.65*t)
		if p.shard:
			var along := Vector2.from_angle(p.angle)*extent
			var across := along.orthogonal()*0.42
			canvas.draw_colored_polygon(PackedVector2Array([p.pos+along, p.pos+across, p.pos-along, p.pos-across]), tint)
		else:
			canvas.draw_circle(p.pos, extent*0.55, tint)
			var trail: Color = tint
			trail.a *= 0.35
			canvas.draw_line(p.pos, p.pos-p.velocity*0.026, trail, 1.3, true)

func _centered(canvas: CanvasItem, font: Font, center: Vector2, text: String, size: int, color: Color, outline: int = 0) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center + Vector2(-width*0.5, float(size)*0.32)
	if outline > 0:
		canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.02,0.03,0.05,color.a))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func combo_pose()->Dictionary:
	var bounce:float=0.0 if reduced_effects else sin(minf(_step_age/.24,1.0)*PI)*exp(-_step_age*4)
	var angle:float=0.0 if reduced_effects else sin(_step_age*23)*exp(-_step_age*12)*.075*(1 if count%2==0 else -1)
	var tint:Color=Color("fff2cb") if reduced_effects else _last_color.lightened(.5).lerp(Color("fff2cb"),minf(count/30.0,.7))
	return {"center":Vector2(176,177-bounce*7),"scale":Vector2.ONE if reduced_effects else Vector2(1+bounce*.12,1+bounce*.22),"angle":angle,"color":tint}

func draw_hud(view, canvas: CanvasItem) -> void:
	if not visible:return
	var alpha:float=clampf(1.0-(_finish_age-HOLD_SECONDS)/FADE_SECONDS,0,1) if finished else 1.0
	var font:Font=view.font
	var display:Font=view.get("font_display") if view.get("font_display") is Font else font
	var pose:=combo_pose()
	var size:int=48 if count<100 else 40
	# No plaque/surface. Only the actual incrementing numeral gets elastic motion.
	if not reduced_effects:
		for echo in range(2,0,-1):
			_centered(canvas,display,pose.center+Vector2(-echo*4,echo*2),str(count),size,Color(pose.color,alpha*.09/echo),0)
	canvas.draw_set_transform(pose.center,pose.angle,pose.scale)
	_centered(canvas,display,Vector2.ZERO,str(count),size,Color(pose.color,alpha),3)
	canvas.draw_set_transform(Vector2.ZERO)
	_centered(canvas,font,Vector2(258,181),"CHAIN",16,Color(1,.93,.8,alpha),1)
	if finished:
		_centered(canvas,font,Vector2(176,208),"에너지 수집",16,Color(.9,.8,1,alpha),1)
		# Large-chain finish accents only: confined to the combo area, not board.
		if count>=12 and _finish_age<.32 and not reduced_effects:
			var progress:float=_finish_age/.32
			for shard in range(8):
				var angle:float=TAU*shard/8
				var center:=Vector2(176,177)+Vector2(cos(angle)*58,sin(angle)*24)*(1+progress*.15)
				if 4*(1-progress)<.5:continue
				var along:=Vector2.from_angle(angle)*4*(1-progress)
				var side:=along.orthogonal()*.4
				canvas.draw_colored_polygon(PackedVector2Array([center+along,center+side,center-along,center-side]),Color(pose.color,(1-progress)*.7))

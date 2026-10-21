extends RefCounted
## Initial continuous layout and local gravity/contact refill simulation.
const RADIUS := 37.0

static func _landing(x: float, radius: float, placed: Array, floor_y: float) -> float:
	var y := floor_y - radius
	for other in placed:
		var dx: float = absf(x - other.pos.x)
		var span: float = radius + other.radius
		if dx < span:
			y = minf(y, other.pos.y - sqrt(span * span - dx * dx))
	return y

static func _place(radius: float, placed: Array, bounds: Rect2, preferred_x: float, rng: RandomNumberGenerator) -> Vector2:
	var candidates: Array = [bounds.position.x + radius, bounds.end.x - radius, preferred_x]
	for i in range(12): candidates.append(rng.randf_range(bounds.position.x + radius, bounds.end.x - radius))
	for a in placed:
		candidates.append(a.pos.x + radius + a.radius)
		candidates.append(a.pos.x - radius - a.radius)
		# Circle-circle intersection produces real touching supports, not a slot grid.
		for b in placed:
			if a.id >= b.id: continue
			var d: float = a.pos.distance_to(b.pos)
			var reach: float = radius + a.radius
			if d > 0.01 and d <= reach * 2.0:
				var middle: Vector2 = (a.pos + b.pos) * 0.5
				var perpendicular: Vector2 = (b.pos - a.pos).normalized().orthogonal()
				var height := sqrt(maxf(0.0, reach * reach - d*d*0.25))
				candidates.append((middle + perpendicular * height).x)
				candidates.append((middle - perpendicular * height).x)
	var best := Vector2(preferred_x, -INF)
	var best_score := -INF
	for x in candidates:
		if x < bounds.position.x + radius - 0.001 or x > bounds.end.x - radius + 0.001: continue
		var y := _landing(x, radius, placed, bounds.end.y)
		# Prefer downward compaction; among equivalent supports retain horizontal position.
		var score := y - absf(x - preferred_x) * 0.005
		if score > best_score:
			best = Vector2(x, y)
			best_score = score
	return best

static func initial_board(bounds: Rect2, count: int, next_id: int, rng: RandomNumberGenerator) -> Dictionary:
	# Only constructs the initial checkpoint arrangement. Never called on refill.
	var placed: Array = []
	while placed.size() < count:
		var preferred_x := rng.randf_range(bounds.position.x + RADIUS, bounds.end.x - RADIUS)
		var target := _place(RADIUS, placed, bounds, preferred_x, rng)
		var color := rng.randi_range(0, 4)
		placed.append({"id": next_id, "pos": target, "from": Vector2(target.x, bounds.position.y - RADIUS - (placed.size() % 4) * 38), "radius": RADIUS, "color": color, "kind": "heart" if color == 4 else "normal"})
		next_id += 1
	placed.sort_custom(func(a, b): return a.id < b.id)
	return {"panels": placed, "next_id": next_id}


# Refill simulation works on current positions only. initial_board() constructs only the initial arrangement.
const STEP := 1.0 / 120.0
const GRAVITY := 6000.0
const MAX_SPEED := 1100.0

static func start(panels: Array, _bounds: Rect2, count: int, next_id: int, rng: RandomNumberGenerator) -> Dictionary:
	var bodies: Array = panels.duplicate(true)
	for p in bodies:
		p.vel = Vector2.ZERO
		p.anchored = false
	var pending: Array = []
	for i in range(maxi(0,count-bodies.size())):
		var color := rng.randi_range(0,4)
		pending.append({"id":next_id,"radius":RADIUS,"color":color,"kind":"heart" if color==4 else "normal","vel":Vector2.ZERO,"anchored":false})
		next_id += 1
	return {"panels":bodies,"pending":pending,"next_id":next_id,"elapsed":0.0,"accumulator":0.0,"spawn_clock":0.0,"lane":0,"ready":false,"quiet":0.0,"stalled":false}

static func _anchor(bodies: Array, bounds: Rect2) -> void:
	for p in bodies:
		p.anchored = absf(p.pos.y+p.radius-bounds.end.y)<0.12 and absf(p.vel.y)<160
	for iteration in range(8):
		var changed := false
		for p in bodies:
			if p.anchored or p.vel.length()>160: continue
			var left: bool = p.pos.x-p.radius <= bounds.position.x+0.12
			var right: bool = p.pos.x+p.radius >= bounds.end.x-0.12
			var centered := false
			for q in bodies:
				if p.id==q.id or not q.anchored:continue
				var offset: Vector2 = q.pos-p.pos
				if offset.y<=0.1 or offset.length()>p.radius+q.radius+0.16:continue
				if offset.x < -0.5:left=true
				elif offset.x > 0.5:right=true
				else:centered=true
			if centered or (left and right):
				p.anchored=true
				p.vel=Vector2.ZERO
				changed=true
		if not changed:break

static func _spawn(state: Dictionary,bounds: Rect2) -> void:
	if state.pending.is_empty() or state.spawn_clock<0.035:return
	var best_x := 0.0
	var best_clearance := -INF
	# Choose a top inlet from the CURRENT surface, not a destination. Survivors
	# are untouched. Round-robin inlets biased short refills toward the left wall.
	for trial in range(33):
		var x := bounds.position.x+RADIUS+trial*(bounds.size.x-2.0*RADIUS)/32.0
		var position := Vector2(x,bounds.position.y-RADIUS-1.0)
		var free := true
		var clearance := bounds.end.y-RADIUS
		for p in state.panels:
			if p.pos.distance_to(position)<p.radius+RADIUS+1.0:
				free=false
				break
			var dx: float=absf(p.pos.x-x)
			var reach: float=p.radius+RADIUS
			if dx<reach:clearance=minf(clearance,p.pos.y-sqrt(reach*reach-dx*dx))
		if free and clearance>best_clearance:
			best_x=x
			best_clearance=clearance
	if best_clearance>-INF:
		var body: Dictionary=state.pending.pop_front()
		body.pos=Vector2(best_x,bounds.position.y-RADIUS-1.0)
		state.panels.append(body)
		state.spawn_clock=0.0

static func _tick(state: Dictionary,bounds: Rect2) -> void:
	var bodies: Array=state.panels
	_anchor(bodies,bounds)
	state.spawn_clock+=STEP
	_spawn(state,bounds)
	for p in bodies:
		if p.anchored:
			p.vel=Vector2.ZERO
			continue
		p.vel.y=minf(MAX_SPEED,p.vel.y+GRAVITY*STEP)
		p.pos+=p.vel*STEP
	# Small substeps plus contact projection prevent pass-through. Static support
	# bodies never move; lateral motion is exclusively a collision response.
	for iteration in range(128):
		var penetration_max := 0.0
		for p in bodies:
			if p.anchored:continue
			if p.pos.x-p.radius<bounds.position.x:
				p.pos.x=bounds.position.x+p.radius
				p.vel.x=maxf(0,p.vel.x)
			if p.pos.x+p.radius>bounds.end.x:
				p.pos.x=bounds.end.x-p.radius
				p.vel.x=minf(0,p.vel.x)
			if p.pos.y+p.radius>bounds.end.y:
				p.pos.y=bounds.end.y-p.radius
				p.vel.y=0
				p.vel.x*=0.5
		for i in range(bodies.size()):
			var a: Dictionary=bodies[i]
			for j in range(i+1,bodies.size()):
				var b: Dictionary=bodies[j]
				if a.anchored and b.anchored:continue
				var offset: Vector2=a.pos-b.pos
				var reach: float=a.radius+b.radius
				var distance_sq := offset.length_squared()
				if distance_sq >= reach*reach:continue
				var distance := sqrt(distance_sq)
				penetration_max=maxf(penetration_max,reach-distance)
				a.contact_count=int(a.get("contact_count",0))+1
				b.contact_count=int(b.get("contact_count",0))+1
				var normal := offset/distance if distance>0.0001 else Vector2.UP
				var wa := 0.0 if a.anchored else 1.0
				var wb := 0.0 if b.anchored else 1.0
				var correction: Vector2=normal*(reach-distance+0.001)/(wa+wb)
				a.pos+=correction*wa
				b.pos-=correction*wb
				var relative: float=(a.vel-b.vel).dot(normal)
				if relative<0:
					var impulse: Vector2=-normal*relative/(wa+wb)
					a.vel+=impulse*wa
					b.vel-=impulse*wb
				# Damp only after actual contact; free-fall has no sideways force.
				if wa>0:a.vel*=0.985
				if wb>0:b.vel*=0.985
		if penetration_max<0.04:break
	state.elapsed+=STEP
	var max_speed := 0.0
	var inside: bool = state.pending.is_empty()
	for p in bodies:
		max_speed=maxf(max_speed,p.vel.length())
		if p.pos.y-p.radius<bounds.position.y-0.1:inside=false
	if inside and max_speed<80:
		state.quiet+=STEP
	else:state.quiet=0.0
	if state.quiet>=0.05:
		state.ready=true
		for p in bodies:p.vel=Vector2.ZERO
	# Bounded failure state instead of an infinite hidden lock. Never teleport.
	if state.elapsed>=4.0 and not state.ready:state.stalled=true

static func step(state: Dictionary,bounds: Rect2,delta: float) -> void:
	if state.ready or state.stalled:return
	state.accumulator+=minf(delta,0.1)
	while state.accumulator>=STEP and not state.ready and not state.stalled:
		state.accumulator-=STEP
		_tick(state,bounds)

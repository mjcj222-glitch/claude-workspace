class_name ResonanceEffects
extends Node2D

var reduced := false
var rings: Array = []
var pulses: Array = []

func burst(location: Vector2, color: Color, strength: int = 1) -> void:
    if reduced: return
    var particles := CPUParticles2D.new()
    particles.position = location
    particles.emitting = false
    particles.amount = 7 if strength == 1 else 16
    particles.lifetime = 0.28 if strength == 1 else 0.42
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.direction = Vector2.UP
    particles.spread = 180
    particles.gravity = Vector2(0,220)
    particles.initial_velocity_min = 45
    particles.initial_velocity_max = 95 if strength == 1 else 180
    var soft := GradientTexture2D.new()
    var mask := Gradient.new()
    mask.set_color(0,Color.WHITE)
    mask.set_color(1,Color(1,1,1,0))
    soft.gradient = mask
    soft.width = 24
    soft.height = 24
    soft.fill = GradientTexture2D.FILL_RADIAL
    soft.fill_from = Vector2(0.5,0.5)
    soft.fill_to = Vector2(1.0,0.5)
    particles.texture = soft
    particles.scale_amount_min = 0.08
    particles.scale_amount_max = 0.22 if strength == 1 else 0.32
    particles.color = color.lightened(0.25)
    var gradient := Gradient.new()
    gradient.set_color(0,Color(1,1,1,1))
    gradient.set_color(1,Color(1,1,1,0))
    particles.color_ramp = gradient
    add_child(particles)
    particles.finished.connect(particles.queue_free)
    particles.emitting = true
    rings.append({"position":location,"color":color,"time":0.0,"duration":0.20 if strength == 1 else 0.30,"radius":40 if strength == 1 else 105})

func hit(location: Vector2, color: Color) -> void:
    if reduced: return
    pulses.append({"position":location,"color":color,"time":0.0})

func _process(delta: float) -> void:
    for ring in rings: ring.time += delta
    rings = rings.filter(func(r): return r.time < r.duration)
    for pulse in pulses: pulse.time += delta
    pulses = pulses.filter(func(p): return p.time < 0.18)
    queue_redraw()

func _draw() -> void:
    for ring in rings:
        var color: Color = ring.color
        var t: float = ring.time/ring.duration
        color.a = (1-t)*0.55
        draw_arc(ring.position,8+ring.radius*t,0,TAU,40,color,3*(1-t),true)
    for pulse in pulses:
        var color: Color = pulse.color
        color.a = (1-pulse.time/0.18)*0.4
        draw_circle(pulse.position,45+80*pulse.time,color)

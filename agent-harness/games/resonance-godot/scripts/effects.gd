class_name ResonanceEffects
extends Node2D

var reduced := false
var rings: Array = []
var pulses: Array = []
var preview_points: Array = []
var preview_links: Array = []
var preview_color := Color.WHITE
const LIGHT = preload("res://assets/kenney-particles/light_01.png")
const STAR = preload("res://assets/kenney-particles/star_01.png")
const RING = preload("res://assets/kenney-particles/circle_03.png")
const SPARK = preload("res://assets/kenney-particles/spark_01.png")
const SLASH = preload("res://assets/kenney-particles/slash_02.png")
const MAGIC = preload("res://assets/kenney-particles/magic_01.png")

func preview(points: Array, color: Color, links: Array = []) -> void:
    preview_points = points.duplicate()
    preview_links = links.duplicate()
    preview_color = color
    queue_redraw()

func clear_all() -> void:
    preview_points.clear()
    preview_links.clear()
    rings.clear()
    pulses.clear()
    for child in get_children(): child.queue_free()
    queue_redraw()

func emitter(location: Vector2, color: Color, texture: Texture2D, amount: int, lifetime: float, speed: float, pixel_size: float) -> void:
    var particles := CPUParticles2D.new()
    particles.position = location
    particles.emitting = false
    particles.texture = texture
    particles.amount = amount
    particles.lifetime = lifetime
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.direction = Vector2.UP
    particles.spread = 180
    particles.gravity = Vector2(0,80)
    particles.initial_velocity_min = speed*0.4
    particles.initial_velocity_max = speed
    particles.scale_amount_min = pixel_size*0.65/512.0
    particles.scale_amount_max = pixel_size/512.0
    particles.color = color
    var gradient := Gradient.new()
    gradient.set_color(0,Color(1,1,1,0.75))
    gradient.set_color(1,Color(1,1,1,0))
    particles.color_ramp = gradient
    add_child(particles)
    particles.finished.connect(particles.queue_free)
    particles.emitting = true

func burst(location: Vector2, color: Color, strength: int = 1) -> void:
    if reduced: return
    emitter(location,color.lightened(0.2),STAR if strength==1 else SPARK,5 if strength==1 else 14,0.24 if strength==1 else 0.42,65 if strength==1 else 145,17 if strength==1 else 44)
    rings.append({"position":location,"color":color,"time":0.0,"duration":0.20 if strength == 1 else 0.34,"radius":28 if strength == 1 else 90})

func hit(location: Vector2, color: Color) -> void:
    if reduced: return
    pulses.append({"position":location,"color":color,"time":0.0})
    emitter(location,color,SLASH,1,0.18,0,125)

func skill(location: Vector2, color: Color) -> void:
    if reduced: return
    emitter(location,color,MAGIC,4,0.40,35,34)
    rings.append({"position":location,"color":color,"time":0.0,"duration":0.40,"radius":48})

func _process(delta: float) -> void:
    for ring in rings: ring.time += delta
    rings = rings.filter(func(r): return r.time < r.duration)
    for pulse in pulses: pulse.time += delta
    pulses = pulses.filter(func(p): return p.time < 0.18)
    queue_redraw()

func _draw() -> void:
    for link in preview_links:
        draw_line(link[0],link[1],Color(0.08,0.08,0.1,0.65),5,true)
        draw_line(link[0],link[1],Color(1,0.95,0.72,0.9),2.4,true)
    for point in preview_points:
        var tint := preview_color.lightened(0.3)
        tint.a = 0.20 if reduced else 0.38
        draw_texture_rect(LIGHT,Rect2(point-Vector2(12,28),Vector2(24,24)),false,tint)
    for ring in rings:
        var color: Color = ring.color
        var t: float = ring.time/ring.duration
        color.a = (1-t)*0.55
        draw_arc(ring.position,8+ring.radius*t,0,TAU,40,color,3*(1-t),true)
        if ring.radius>60:
            color.a *= 0.45
            var radius: float = 12+ring.radius*t
            draw_texture_rect(RING,Rect2(ring.position-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)
    for pulse in pulses:
        var color: Color = pulse.color
        color.a = (1-pulse.time/0.18)*0.4
        draw_circle(pulse.position,45+80*pulse.time,color)

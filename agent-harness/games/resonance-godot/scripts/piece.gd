class_name ResonancePiece
extends RigidBody2D

const Geometry = preload("res://scripts/piece_geometry.gd")
var identity := 0
var color_index := 0
var kind := "normal"
var size_factor := 1.0
var selected := false
var marked := false
var polygon := PackedVector2Array()
var collider: CollisionPolygon2D
var font: Font
var reduced := false
var shimmer := 0.0
var pop_scale := Vector2.ONE:
    set(value):
        pop_scale = value
        queue_redraw()

func _process(delta: float) -> void:
    if not reduced and (marked or kind != "normal"):
        shimmer += delta
        queue_redraw()

func pop_feedback() -> void:
    var tween := create_tween()
    tween.tween_property(self,"pop_scale",Vector2(1.06,0.87),0.065).set_trans(Tween.TRANS_QUAD)
    tween.tween_property(self,"pop_scale",Vector2(1.10,1.10),0.065).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self,"pop_scale",Vector2(0.05,0.05),0.070).set_trans(Tween.TRANS_QUAD)

func configure(id_value: int, color_value: int, size_value: float, special: String = "normal") -> void:
    identity = id_value
    color_index = color_value
    size_factor = size_value
    kind = special
    polygon = Geometry.polygon(color_index, size_factor)
    collider = CollisionPolygon2D.new()
    collider.polygon = polygon
    add_child(collider)
    mass = 1.0
    linear_damp = 0.7
    angular_damp = 2.2
    continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
    contact_monitor = true
    max_contacts_reported = 24
    var material := PhysicsMaterial.new()
    material.friction = 0.28
    material.bounce = 0.04
    physics_material_override = material
    font = ThemeDB.fallback_font

func recolor(value: int) -> void:
    color_index = value
    polygon = Geometry.polygon(value, size_factor)
    collider.polygon = polygon
    queue_redraw()

func snapshot() -> Dictionary:
    return {"id": identity, "color": color_index, "kind": kind, "size": size_factor,
        "x": position.x, "y": position.y, "angle": rotation}

func contains(world_point: Vector2) -> bool:
    return Geometry2D.is_point_in_polygon(to_local(world_point), polygon)

func _draw() -> void:
    var color: Color = Geometry.COLORS[color_index]
    # The full outer silhouette is the collider polygon. Bevels and stripes
    # are inset; only locked, resolving pieces use the transient pop transform.
    draw_set_transform(Vector2.ZERO,0,pop_scale)
    draw_colored_polygon(polygon,color.darkened(0.54))
    var inner := PackedVector2Array()
    for p in polygon:
        inner.append(p*0.79+Vector2(-1.5,-3).rotated(-rotation))
    var light := Vector2(-0.45,-0.9)
    for i in range(polygon.size()):
        var j := (i+1)%polygon.size()
        var outward := (polygon[i]+polygon[j]).normalized().rotated(rotation)
        var amount := outward.dot(light)
        var bevel := color.lightened(0.58*maxf(0,amount)) if amount>0 else color.darkened(-amount*0.40)
        draw_colored_polygon(PackedVector2Array([polygon[i]*0.98,polygon[j]*0.98,inner[j],inner[i]]),bevel)
    var colors := PackedColorArray()
    for p in inner:
        var top := clampf((30-p.rotated(rotation).y)/60,0,1)
        colors.append(color.darkened(0.12).lerp(color.lightened(0.48 if not selected else 0.66),top))
    draw_polygon(inner,colors)
    # Narrow diagonal glints are clipped to the face, including concave stars.
    for offset in [-14.0,7.0]:
        var band := PackedVector2Array([Vector2(-60,offset+32),Vector2(60,offset-38),Vector2(60,offset-34),Vector2(-60,offset+36)])
        for part in Geometry2D.intersect_polygons(inner,band):
            draw_colored_polygon(part,Color(1,1,1,0.14))
    var rim := PackedVector2Array()
    for p in polygon: rim.append(p*0.96)
    rim.append(rim[0])
    draw_polyline(rim,Color("fff8ce") if selected else color.lightened(0.18),3.5 if selected else 1.3,true)
    var face_edge := PackedVector2Array(inner)
    face_edge.append(inner[0])
    draw_polyline(face_edge,color.lightened(0.62),0.85,true)
    draw_set_transform(Vector2.ZERO,-rotation,pop_scale)
    draw_arc(Vector2(-7,-9),13,PI*1.1,PI*1.68,12,Color(1,1,1,0.72),3.2,true)
    draw_circle(Vector2(-15,-17),2.6,Color(1,1,1,0.8))
    if marked:
        draw_circle(Vector2.ZERO,18,Color("193c5ce8"))
        draw_arc(Vector2.ZERO,23,0,TAU,40,Color("b8fcff"),2.4,true)
        var sway := 0.0 if reduced else sin(shimmer*2)*0.12
        draw_arc(Vector2.ZERO,27,0.25+sway,PI-0.25+sway,22,Color("d7ffff"),1.7,true)
        draw_arc(Vector2.ZERO,27,PI+0.25+sway,TAU-0.25+sway,22,Color("d7ffff"),1.7,true)
        draw_string(font,Vector2(-15,5),"ECHO",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("edffff"))
    if kind == "mega" or kind == "bomb":
        var mega := kind == "mega"
        var radius := 27.0 if mega else 22.0
        draw_circle(Vector2.ZERO,radius,Color("332740"))
        draw_arc(Vector2.ZERO,radius,0,TAU,40,Color("fff4a2"),3,true)
        if mega:
            draw_arc(Vector2.ZERO,31,0,TAU,44,Color("ffb436"),2.3,true)
            var glow := 0.75 if reduced else 0.75+0.20*sin(shimmer*3)
            for i in range(8):
                var a := i*TAU/8
                draw_line(Vector2.from_angle(a)*32,Vector2.from_angle(a)*35,Color(1,0.92,0.50,glow),2,true)
        draw_circle(Vector2(0,-6),9 if mega else 8,Color("fff1ac"))
        draw_line(Vector2(2,-14),Vector2(5,-19),Color("fff1ac"),3,true)
        draw_line(Vector2(5,-19),Vector2(10,-17),Color("ff9947"),2,true)
        draw_string(font,Vector2(-21 if mega else -17,15),"BOMB",HORIZONTAL_ALIGNMENT_LEFT,-1,14 if mega else 11,Color("fff4d0"))
    elif kind == "charge":
        draw_circle(Vector2.ZERO,24,Color("193a4c"))
        var rim_light := Color("fff1a1")
        rim_light.a = 1 if reduced else 0.85+0.15*sin(shimmer*2.5)
        draw_arc(Vector2.ZERO,26,0,TAU,36,rim_light,2.5,true)
        draw_colored_polygon(PackedVector2Array([Vector2(3,-20),Vector2(-13,3),Vector2(-1,3),Vector2(-5,21),Vector2(15,-5),Vector2(3,-5)]),Color("fff1a1"))
    elif color_index == 3:
        draw_line(Vector2(0,-12), Vector2(0,12), Color("f8fff5"), 4, true)
        draw_line(Vector2(-12,0), Vector2(12,0), Color("f8fff5"), 4, true)

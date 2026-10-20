extends RigidBody2D
## Surface conversion never modifies the physical hull or pose.

const Config = preload("res://scripts/v2/config.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
var identity := 0
var hull_id := 0
var match_type := "red"
var size_factor := 1.0
var bomb_tier := 0
var polygon := PackedVector2Array()
var collider: CollisionPolygon2D

func configure(id: int, hull: int, type: String, size: float, tier: int = 0) -> void:
    identity = id
    hull_id = hull
    size_factor = size
    match_type = type
    bomb_tier = clampi(tier, 0, 3) if type == "blue" else 0
    polygon = Geometry.polygon(hull_id, size_factor)
    if collider == null:
        collider = CollisionPolygon2D.new()
        add_child(collider)
    collider.polygon = polygon
    mass = Config.PIECE_MASS
    linear_damp = Config.LINEAR_DAMP
    angular_damp = Config.ANGULAR_DAMP
    continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
    contact_monitor = true
    max_contacts_reported = Config.MAX_CONTACTS
    var material := PhysicsMaterial.new()
    material.friction = Config.FRICTION
    material.bounce = Config.BOUNCE
    physics_material_override = material
    queue_redraw()

func apply_type(type: String) -> void:
    match_type = type
    if type != "blue":
        bomb_tier = 0
    queue_redraw()

func snapshot() -> Dictionary:
    return {"id": identity, "hull_id": hull_id, "match_type": match_type,
        "size": size_factor, "x": position.x, "y": position.y,
        "angle": rotation, "bomb_tier": bomb_tier}

func contains(world_point: Vector2) -> bool:
    return Geometry2D.is_point_in_polygon(to_local(world_point), polygon)

func _draw() -> void:
    if polygon.is_empty():
        return
    var color: Color = Config.TYPE_COLORS[match_type]
    # Only this outer silhouette touches the collision boundary; all decoration is inset.
    draw_colored_polygon(polygon, color.darkened(0.46))
    var inner := PackedVector2Array()
    for point in polygon:
        inner.append(point * 0.80)
    for i in range(polygon.size()):
        var j := (i + 1) % polygon.size()
        var light := (polygon[i] + polygon[j]).normalized().rotated(rotation).dot(Vector2(-0.45, -0.9))
        var bevel := color.lightened(maxf(0, light) * 0.50) if light > 0 else color.darkened(-light * 0.35)
        draw_colored_polygon(PackedVector2Array([polygon[i], polygon[j], inner[j], inner[i]]), bevel)
    draw_colored_polygon(inner, color.lightened(0.15))
    # Inset reflective bands follow the face, without changing its silhouette.
    var shine := PackedVector2Array([Vector2(-80,-80),Vector2(80,-80),Vector2(80,-18),Vector2(-80,4)])
    for cap in Geometry2D.intersect_polygons(inner, shine):
        draw_colored_polygon(cap, Color(1,1,1,0.20))
    var reflection := PackedVector2Array([Vector2(-80,-25),Vector2(80,-47),Vector2(80,-41),Vector2(-80,-19)])
    for band in Geometry2D.intersect_polygons(inner, reflection):
        draw_colored_polygon(band, Color(1,1,1,0.12))
    var rim := PackedVector2Array()
    for point in polygon: rim.append(point * 0.96)
    rim.append(rim[0])
    draw_polyline(rim, color.lightened(0.35), 1.2, true)
    draw_set_transform(Vector2.ZERO, -rotation)
    # Every hull of a surface type uses this same large central motif.
    var ink := Color("fff9ee")
    if bomb_tier > 0:
        # Bomb decoration surrounds the shared type motif rather than replacing it.
        draw_circle(Vector2.ZERO, 21, Color("243049"))
        var tier_color: Color = [ink, ink, Color("ffd16d"), Color("ff8b76")][bomb_tier]
        draw_arc(Vector2.ZERO, 22, 0, TAU, 48, tier_color, 2.0 + bomb_tier * 0.55, true)
        draw_line(Vector2(9, -21), Vector2(12, -24), Color("ffc735"), 3, true)
        draw_style_box(_tier_badge(), Rect2(-13,14,26,11))
        for i in range(bomb_tier):
            var x := (i - (bomb_tier - 1) * 0.5) * 6
            draw_line(Vector2(x,16),Vector2(x,22),tier_color,3.0,true)
    if match_type == "red":
        draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(12, -2), Vector2(10, 10),
            Vector2(0, 17), Vector2(-11, 10), Vector2(-13, 0), Vector2(-5, -10), Vector2(-4, 2)]), ink)
    elif match_type == "yellow":
        var star := PackedVector2Array()
        for i in range(10):
            star.append(Vector2.from_angle(-PI / 2 + i * TAU / 10) * (18.0 if i % 2 == 0 else 8.0))
        draw_colored_polygon(star, ink)
    elif match_type == "blue":
        for y in [-9, 0, 9]:
            var wave := PackedVector2Array()
            for i in range(17):
                var x := -17.0 + i * 34.0 / 16
                wave.append(Vector2(x, y + sin(x / 6.0) * 3.5))
            draw_polyline(wave, ink, 3.0, true)
    else:
        var heart := PackedVector2Array()
        for i in range(40):
            var t := i * TAU / 40
            heart.append(Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))))
        draw_colored_polygon(heart, ink)

func _tier_badge() -> StyleBoxFlat:
    var badge := StyleBoxFlat.new()
    badge.bg_color = Color("152234")
    badge.set_corner_radius_all(4)
    return badge

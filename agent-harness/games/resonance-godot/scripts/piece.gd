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
    draw_colored_polygon(polygon, color.darkened(0.08))
    var inner := PackedVector2Array()
    for p in polygon:
        inner.append(p * 0.92)
    draw_colored_polygon(inner, color.lightened(0.09 if not selected else 0.28))
    var edge := PackedVector2Array(inner)
    edge.append(inner[0])
    draw_polyline(edge, Color("fff8db") if selected else color.lightened(0.40), 2.4, true)
    draw_arc(Vector2(-7, -9), 15, PI*1.03, PI*1.68, 10, Color(1,1,1,0.40), 4, true)
    if marked:
        draw_arc(Vector2.ZERO, 19, 0, TAU, 30, Color("fff4bf"), 2.4, true)
    if kind != "normal":
        draw_circle(Vector2.ZERO, 17, Color("193a4c"))
        draw_arc(Vector2.ZERO, 17, 0, TAU, 28, Color("ffefaa"), 2.3, true)
        var glyph: String = "+" if kind == "charge" else ("*" if kind == "bomb" else ["O", "=", "I", "+"][color_index])
        draw_string(font, Vector2(-8, 9), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("fff1aa"))
    elif color_index == 3:
        draw_line(Vector2(0,-12), Vector2(0,12), Color("f8fff5"), 4, true)
        draw_line(Vector2(-12,0), Vector2(12,0), Color("f8fff5"), 4, true)

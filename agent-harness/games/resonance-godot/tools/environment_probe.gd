extends SceneTree

func _initialize() -> void:
    call_deferred("run_probe")

func run_probe() -> void:
    var world := Node2D.new()
    root.add_child(world)
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(200, 400)
    var floor_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(400, 20)
    floor_shape.shape = rectangle
    floor_body.add_child(floor_shape)
    world.add_child(floor_body)
    var piece := RigidBody2D.new()
    piece.position = Vector2(200, 50)
    var polygon := CollisionPolygon2D.new()
    # A concave star: one authoritative polygon, decomposed by Godot's solids mode.
    var points := PackedVector2Array()
    for i in range(10):
        var radius := 30.0 if i % 2 == 0 else 17.0
        points.append(Vector2.from_angle(-PI / 2 + i * TAU / 10) * radius)
    polygon.polygon = points
    piece.add_child(polygon)
    world.add_child(piece)
    var before := piece.position.y
    for i in range(300):
        await physics_frame
    var result := {"engine": Engine.get_version_info().string,
        "display": DisplayServer.get_name(), "physics_ticks": 300,
        "start_y": before, "final_y": piece.position.y,
        "linear_speed": piece.linear_velocity.length(),
        "sleeping": piece.sleeping,
        "fall_and_collision": piece.position.y > 300 and piece.position.y < 390}
    print(JSON.stringify(result))
    quit(0 if result.fall_and_collision else 1)

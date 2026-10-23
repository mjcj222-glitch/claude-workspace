extends RefCounted

# Input.parse_input_event accepts window coordinates. Node2D positions and
# Control rectangles are in the stretched viewport's logical coordinates.
static func window_point(viewport: Viewport, logical_point: Vector2) -> Vector2:
    return viewport.get_final_transform() * logical_point

static func touch(viewport: Viewport, logical_point: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.position = window_point(viewport,logical_point)
    event.pressed = pressed
    event.index = index
    event.canceled = canceled
    Input.parse_input_event(event)

static func mouse(viewport: Viewport, logical_point: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = window_point(viewport,logical_point)
    event.pressed = pressed
    Input.parse_input_event(event)

extends RefCounted
## Uniform fit between logical physics coordinates and a display rectangle.
## A differing aspect ratio is centered/letterboxed, never stretched or cropped.
## The inverse intentionally does not clamp: outside gestures must stay outside.

static func board_scale(logical: Rect2, display: Rect2) -> Vector2:
	assert(logical.size.x > 0.0 and logical.size.y > 0.0, "Logical board needs positive dimensions")
	assert(display.size.x > 0.0 and display.size.y > 0.0, "Displayed board needs positive dimensions")
	var uniform := minf(display.size.x/logical.size.x, display.size.y/logical.size.y)
	return Vector2(uniform,uniform)

static func _origin(logical: Rect2, display: Rect2, scale: Vector2) -> Vector2:
	return display.position+(display.size-logical.size*scale)*0.5

static func board_to_screen(point: Vector2, logical: Rect2, display: Rect2) -> Vector2:
	var scale := board_scale(logical,display)
	return _origin(logical,display,scale)+(point-logical.position)*scale

static func screen_to_board(point: Vector2, logical: Rect2, display: Rect2) -> Vector2:
	var scale := board_scale(logical,display)
	return logical.position+(point-_origin(logical,display,scale))/scale

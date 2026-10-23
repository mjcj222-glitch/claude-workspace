extends Control

var max_value := 180.0
var value := 180.0:
    set(new_value):
        value = new_value
        queue_redraw()
var tint := Color("87d8bb")

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("162f3b"))
    draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/max_value,0,1),size.y)),tint)

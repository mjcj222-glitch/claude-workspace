extends Control
const Config = preload("res://scripts/v2/config.gd")
var elapsed := 0.0
var active := false
var still := false
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    position = Vector2(24,24)
    size = Vector2(672,288)
    clip_contents = true
    var hero := get_node("Hero") as TextureRect
    hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero.texture = preload("res://assets/heroine/heroine-attack-strike-v1.png")
    hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hero.position = Vector2(196,4)
    hero.size = Vector2(280,280)
    hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hide()
    hero.hide()
func play(reduced: bool) -> void:
    still = reduced
    elapsed = 0
    active = true
    modulate.a = 1
    get_node("Hero").position = Vector2(196,4)
    get_node("Hero").show()
    show()
    queue_redraw()
func _process(delta: float) -> void:
    if not active: return
    if elapsed >= Config.HERO_SHOW_SECONDS:
        active = false
        get_node("Hero").hide()
        hide()
    elif not still:
        get_node("Hero").position.x = 196 + 15 * sin(elapsed/Config.HERO_SHOW_SECONDS*PI)
    elapsed += delta
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("181c2ef0"))
    draw_line(Vector2(1,1),Vector2(size.x-1,1),Color("b7e8e0"),2)
    draw_line(Vector2(1,size.y-1),size-Vector2.ONE,Color("b7e8e0"),2)

extends Control
const Config = preload("res://scripts/v2/config.gd")
var elapsed := 0.0
var active := false
var still := false
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var hero := get_node("Hero") as TextureRect
    hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero.texture = preload("res://assets/heroine/heroine-attack-strike-v1.png")
    hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hero.position = Vector2(175,24)
    hero.size = Vector2(360,360)
    hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hide()
    hero.hide()
func play(reduced: bool) -> void:
    still = reduced
    elapsed = 0
    active = true
    modulate.a = 1
    get_node("Hero").position = Vector2(175,24)
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
        get_node("Hero").position.x = 175 + 15 * sin(elapsed/Config.HERO_SHOW_SECONDS*PI)
    elapsed += delta
func _draw() -> void:
    draw_rect(Rect2(24,38,672,318),Color("181c2ef0"))
    draw_line(Vector2(24,38),Vector2(696,38),Color("b7e8e0"),2)
    draw_line(Vector2(24,356),Vector2(696,356),Color("b7e8e0"),2)

extends Control
## Input points are root-canvas logical coordinates, never scaled physics poses.
const Effects = preload("res://scripts/v2/board_effects.gd")
var viewport: SubViewport
var display: TextureRect
var effects: Node2D
var board: Node
func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    viewport = SubViewport.new()
    viewport.name = "BoardWorld"
    viewport.size = Vector2i(600,600)
    viewport.world_2d = World2D.new()
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = false
    add_child(viewport)
    display = TextureRect.new()
    display.name = "Surface"
    display.texture = viewport.get_texture()
    display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    display.stretch_mode = TextureRect.STRETCH_SCALE
    display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(display)
    var background := Polygon2D.new()
    background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(600,0),Vector2(600,600),Vector2(0,600)])
    background.color = Color("191b21")
    background.z_index = -100
    viewport.add_child(background)
    effects = Effects.new()
    effects.name = "Effects"
    viewport.add_child(effects)
    queue_redraw()
func bind_board(value: Node) -> void:
    if board == value: return
    if board != null and is_instance_valid(board): viewport.remove_child(board)
    board = value
    if board.get_parent() != null: board.get_parent().remove_child(board)
    viewport.add_child(board)
    viewport.move_child(board, 0)
func logical_to_board(point: Vector2) -> Vector2:
    return (get_global_transform().affine_inverse() * point) * Vector2(600,600) / size
func board_to_logical(point: Vector2) -> Vector2:
    return get_global_transform() * (point * size / Vector2(600,600))
func contains_logical(point: Vector2) -> bool:
    return Rect2(Vector2.ZERO,Vector2(600,600)).has_point(logical_to_board(point))
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("191b21"))
    # A quiet, neutral playfield lets the type symbols carry the information.
    for y in range(12, int(size.y), 24):
        for x in range(12, int(size.x), 24):
            draw_circle(Vector2(x,y),0.65,Color("292c33"))

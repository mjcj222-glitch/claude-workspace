extends RefCounted
## Original relic SVGs. Raw-source loading permits a fresh checkout without an
## editor import; exported projects fall back to Godot's imported resources.
const PATHS = {
	"pigment": "res://assets/relics/pigment.svg",
	"lens": "res://assets/relics/lens.svg",
	"ash": "res://assets/relics/ash.svg",
}
static var _textures: Dictionary = {}

static func _texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	if not PATHS.has(id):
		return null
	var path: String = PATHS[id]
	var texture: Texture2D
	if FileAccess.file_exists(path):
		var source := FileAccess.get_file_as_string(path)
		var image := Image.new()
		if image.load_svg_from_string(source) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture != null:
		_textures[id] = texture
	return texture

static func draw_icon(canvas: CanvasItem, id: String, rect: Rect2, highlighted: bool = false) -> void:
	var texture := _texture(id)
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if highlighted:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.50,0.81,0.73,0.13)
		style.border_color = Color(0.64,0.96,0.84,0.60)
		style.set_border_width_all(1)
		style.set_corner_radius_all(14)
		canvas.draw_style_box(style,rect)
	# Uniform fit preserves recognisable silhouette for non-square containers.
	var side := minf(rect.size.x,rect.size.y)
	var target := Rect2(rect.get_center()-Vector2.ONE*side*0.5,Vector2.ONE*side)
	canvas.draw_texture_rect(texture,target,false)

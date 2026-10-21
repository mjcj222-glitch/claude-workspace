extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/board_art.gd")
	if script == null:
		push_error("ART API missing: board_art.gd must expose the panel, hero, target renderers")
		quit(1)
		return
	for method in ["draw_panel", "draw_hero", "draw_target"]:
		if not script.has_method(method):
			push_error("ART API missing: " + method)
			quit(1)
			return
	var preview = Preview.new()
	preview.art = script
	root.add_child(preview)
	await process_frame
	await process_frame
	print("ART API: 3/3 methods, 15 panel variants drawn")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/chroma-art-preview.png")
	quit(0)

class Preview extends Node2D:
	var art
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 1080), Color("10141e"))
		for row in range(3):
			for col in range(5):
				art.draw_panel(self, {"id": row * 5 + col, "pos": Vector2(100 + col * 125, 140 + row * 140), "radius": 48.0, "color": col, "kind": ["normal", "core", "strong"][row] if col < 4 else "heart"}, 1.0, ["", "direct", "chain"][row], 1.0)
		art.draw_hero(self, Vector2(200, 650), 1.0, true)
		art.draw_target(self, Vector2(500, 650), 1.0, 0.3)

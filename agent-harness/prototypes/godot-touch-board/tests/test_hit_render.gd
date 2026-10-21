extends SceneTree
const Art=preload("res://scripts/board_art.gd")
class Probe extends Node2D:
	func _draw()->void:
		var source:=Rect2(0,60,1536,672)
		draw_texture_rect_region(Art.DRAGON_TEXTURE,Rect2(0,0,720,315),source)
		Art._draw_dragon_hit(self,Rect2(0,340,720,315),source,Vector2.ZERO,0)
func _initialize()->void:call_deferred("run")
func run()->void:
	var probe:=Probe.new();root.add_child(probe)
	for i in range(3):probe.queue_redraw();await process_frame
	await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	var failures:=0
	for y in range(30,300,30):
		for x in range(30,700,30):
			var a:=frame.get_pixel(x,y);var b:=frame.get_pixel(x,y+340)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.025:failures+=1
	frame.save_png("res://evidence/impact/dragon-render-check.png")
	print("HIT_RENDER mismatched_samples=",failures)
	quit(1 if failures else 0)

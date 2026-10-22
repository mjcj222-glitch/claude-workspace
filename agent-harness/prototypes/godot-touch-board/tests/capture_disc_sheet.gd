extends SceneTree
class Sheet extends Node2D:
 const Art=preload("res://scripts/board_art.gd")
 func _draw()->void:
  draw_rect(Rect2(0,0,720,400),Color("171326"))
  draw_string(ThemeDB.fallback_font,Vector2(30,34),"CHROMA  /  DISC BOMBS",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
  for color in range(4):
   for row in range(3):
    var radius:float=37 if row==0 else 48
    Art.draw_bomb(self,Vector2(100+color*170,105+row*110),radius,row>0,"direct" if row==2 else "",color)
func _initialize()->void:call_deferred("capture")
func capture()->void:
 root.size=Vector2i(720,400)
 root.add_child(Sheet.new())
 await process_frame
 await RenderingServer.frame_post_draw
 var result:int=root.get_texture().get_image().get_region(Rect2i(0,0,720,400)).save_png("res://evidence/disc-bombs/disc-sheet.png")
 quit(result)

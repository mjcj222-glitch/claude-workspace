extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func _initialize()->void:
 var art=load("res://scripts/board_pixel_heroes.gd")
 var probe=art.frame("rio",0.0,"idle")
 check(probe is Dictionary,"detailed art frame exposes source region and transform")
 if not probe is Dictionary:quit(1);return
 var texture=art.texture()
 check(texture!=null and texture.get_size()==Vector2(1447,1087),"full original transparent atlas available")
 check(texture is CanvasTexture and texture.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"atlas enforces nearest sampling without changing canvas")
 for hero in ["rio","noa"]:
  var idle=art.frame(hero,0.0,"idle")
  check(idle==art.frame(hero,0.0,"idle"),hero+" frame deterministic")
  check(idle!=art.frame(hero,.5,"idle"),hero+" breathing animation")
  for state in ["ready","skill","cheer","hit"]:
   check(idle!=art.frame(hero,.5,state),hero+" distinct "+state+" presentation")
  check(art.frame(hero,0.0,"idle",true)==art.frame(hero,.5,"idle",true),hero+" reduced idle stable")
  for state in ["idle","ready","skill","cheer","hit"]:
   var f=art.frame(hero,.5,state)
   check(Rect2(0,0,1447,1087).encloses(f.region) and f.region.size.x<=540,hero+" "+state+" enlarged face crop inside original atlas")
   check(f.offset.length()<8 and f.zoom<=1.04,hero+" "+state+" motion bounded")
 check(art.frame("rio",0.0).region.end.x<=art.frame("noa",0.0).region.position.x,"hero source regions never bleed into other character")
 print("PIXEL_HEROES checks=",checks," failures=",failures)
 quit(1 if failures else 0)

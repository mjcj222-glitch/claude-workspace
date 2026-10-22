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
  check(art.destination_rect(Rect2(8,926,180,140),hero,0.0).size==art.destination_rect(Rect2(8,926,180,140),hero,.5).size,hero+" idle keeps silhouette size stable under nearest sampling")
  for state in ["ready","skill","cheer","hit"]:
   check(idle!=art.frame(hero,.5,state),hero+" distinct "+state+" presentation")
  check(art.frame(hero,0.0,"idle",true)==art.frame(hero,.5,"idle",true),hero+" reduced idle stable")
  for state in ["idle","ready","skill","cheer","hit"]:
   var f=art.frame(hero,.5,state)
   check(Rect2(0,0,1447,1087).encloses(f.region) and f.region.size.y>=950,hero+" "+state+" full body including hat and boots inside original atlas")
   check(f.offset.length()<8 and f.zoom<=1.04,hero+" "+state+" motion bounded")
   var dock=Rect2(8,926,180,140)
   var dest=art.destination_rect(dock,hero,.5,state)
   check(dock.encloses(dest) and dest.position==dest.position.round() and dest.size==dest.size.floor(),hero+" "+state+" full body stays pixel aligned inside footer")
   check(absf(dest.size.x/dest.size.y-f.region.size.x/f.region.size.y)<.015,hero+" "+state+" aspect ratio preserved")
 check(art.frame("rio",0.0).region.end.x<=art.frame("noa",0.0).region.position.x,"hero source regions never bleed into other character")
 print("PIXEL_HEROES checks=",checks," failures=",failures)
 quit(1 if failures else 0)

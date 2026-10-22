extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func _initialize()->void:
 var source="res://scripts/board_pixel_heroes.gd"
 check(FileAccess.file_exists(source),"original pixel hero renderer exists")
 if not FileAccess.file_exists(source):quit(1);return
 var art=load(source)
 for hero in ["rio","noa"]:
  var idle=art.frame(hero,0.0,"idle")
  check(idle==art.frame(hero,0.0,"idle"),hero+" frame deterministic")
  check(idle!=art.frame(hero, .5,"idle"),hero+" idle animation")
  check(idle!=art.frame(hero,0.0,"skill"),hero+" skill flourish")
  check(idle!=art.frame(hero,0.0,"hit"),hero+" hit reaction")
  check(art.frame(hero,0.0,"idle",true)==art.frame(hero, .5,"idle",true),hero+" reduced effects stable")
  for state in ["idle","skill","hit"]:
   var cells=art.frame(hero, .5,state)
   var inside=true
   for cell in cells:
    if not Rect2(0,0,32,32).encloses(cell.rect):inside=false
   check(inside,hero+" "+state+" bounded to portrait")
 check(art.frame("rio",0.0,"idle")!=art.frame("noa",0.0,"idle"),"distinct character silhouettes/palettes")
 print("PIXEL_HEROES checks=",checks," failures=",failures)
 quit(1 if failures else 0)

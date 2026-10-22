extends RefCounted
## Original hand-authored 32×32 pixel figures, CC0-1.0. No traced/reference art.
## Pure presentation. Coordinates are integer pixels; no session/RNG mutations.
const INK=Color("251b3b")
const SKIN=Color("ffe1bd")
const LIGHT=Color("fff4dd")
static func tile(cells:Array,x:int,y:int,w:int,h:int,color:Color)->void:
 cells.append({"rect":Rect2(x,y,w,h),"color":color})
static func frame(hero:String,time:float,state:String="idle",reduced:bool=false)->Array:
 var cells:Array=[]
 var noa:=hero=="noa"
 var bob:=0 if reduced or state=="hit" else int(floor(time*2.5))%2
 var shift:=1 if state=="hit" and not reduced else 0
 var cloth:=Color("8272d7") if noa else Color("36a992")
 var bright:=Color("c8b9ff") if noa else Color("8ce8bd")
 var hair:=Color("405881") if noa else Color("b95e45")
 var hair_light:=Color("82b5cf") if noa else Color("edaa72")
 var y:=bob
 # Stepped shadow, boots and cape behind a broad-headed chibi silhouette.
 tile(cells,8,29,17,1,Color("282235"))
 tile(cells,10+shift,22+y,12,4,INK)
 tile(cells,11+shift,22+y,10,3,cloth)
 tile(cells,10+shift,27,5,2,INK);tile(cells,18+shift,27,5,2,INK)
 tile(cells,11+shift,26+y,3,2,LIGHT);tile(cells,19+shift,26+y,3,2,LIGHT)
 # Hair silhouette differs: Noa pointed hood, Rio asymmetric beret.
 if noa:
  tile(cells,14+shift,2+y,5,2,INK);tile(cells,11+shift,4+y,11,2,INK)
  tile(cells,9+shift,6+y,15,12,INK);tile(cells,10+shift,6+y,13,11,cloth)
  tile(cells,12+shift,5+y,9,2,bright)
 else:
  tile(cells,10+shift,4+y,14,3,INK);tile(cells,8+shift,7+y,17,3,INK)
  tile(cells,11+shift,5+y,12,3,cloth);tile(cells,9+shift,8+y,15,2,bright)
  tile(cells,21+shift,3+y,2,2,Color("edc765"))
 tile(cells,9+shift,10+y,15,9,INK)
 tile(cells,10+shift,10+y,13,8,hair)
 tile(cells,11+shift,12+y,11,7,SKIN)
 tile(cells,10+shift,10+y,13,3,hair)
 tile(cells,11+shift,10+y,4,2,hair_light)
 tile(cells,10+shift,12+y,2,5,hair);tile(cells,22+shift,12+y,1,6,hair)
 tile(cells,15+shift,12+y,3,2,hair)
 # Face: timed blink; hit expression is readable without a white flash.
 var blink:=not reduced and fmod(time,3.5)>3.2
 var eye_h:=1 if blink or state=="hit" else 2
 tile(cells,13+shift,15+y,2,eye_h,INK);tile(cells,19+shift,15+y,2,eye_h,INK)
 if not blink and state!="hit":
  tile(cells,13+shift,15+y,1,1,LIGHT);tile(cells,19+shift,15+y,1,1,LIGHT)
 tile(cells,12+shift,17+y,2,1,Color("ed9fa6"));tile(cells,20+shift,17+y,2,1,Color("ed9fa6"))
 tile(cells,16+shift,18+y,2,1,Color("b76c75"))
 tile(cells,12+shift,20+y,10,5,INK);tile(cells,13+shift,20+y,8,4,cloth)
 tile(cells,15+shift,20+y,4,2,LIGHT);tile(cells,16+shift,22+y,2,2,Color("e9c56e"))
 # Left arm and held tool: paintbrush versus star staff.
 tile(cells,9+shift,20+y,3,4,INK);tile(cells,10+shift,21+y,2,2,SKIN)
 var hand_y:=17 if state=="skill" else 21+y
 tile(cells,22+shift,hand_y,3,3,INK);tile(cells,22+shift,hand_y,2,2,SKIN)
 tile(cells,25,13 if state=="skill" else 17,1,10,Color("a97755"))
 if noa:
  star(cells,25,12 if state=="skill" else 16,Color("a6eafa"))
 else:
  tile(cells,24,11 if state=="skill" else 15,3,4,INK)
  tile(cells,24,11 if state=="skill" else 15,3,2,Color("ffb9d6"))
  tile(cells,25,10 if state=="skill" else 14,1,2,LIGHT)
 if state=="skill":
  star(cells,5,10,bright);star(cells,28,5,LIGHT)
  if not reduced:star(cells,4,21-int(floor(time*5))%3,Color("edc765"))
 return cells
static func star(cells:Array,x:int,y:int,color:Color)->void:
 tile(cells,x-1,y,3,1,color);tile(cells,x,y-1,1,3,color)
static func draw(canvas:CanvasItem,rect:Rect2,hero:String,time:float,state:String="idle",reduced:bool=false)->void:
 var scale_px:=maxf(1.0,floor(minf(rect.size.x,rect.size.y)/32.0))
 var origin:Vector2=(rect.position+(rect.size-Vector2(32,32)*scale_px)*.5).floor()
 for cell in frame(hero,time,state,reduced):
  canvas.draw_rect(Rect2(origin+cell.rect.position*scale_px,cell.rect.size*scale_px),cell.color)

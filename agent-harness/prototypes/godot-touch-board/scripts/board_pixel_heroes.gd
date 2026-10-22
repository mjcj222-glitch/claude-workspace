extends RefCounted
## Original generated pixel-style illustration, not hand-drawn 32px sprites.
## Presentation-only atlas crop/motion; never touches session state or game RNG.
const PATH="res://assets/characters/rio-noa-sheet.png"
const REGIONS={"rio":Rect2(220,100,420,373),"noa":Rect2(970,125,420,373)}
static var _texture:CanvasTexture
static func texture()->Texture2D:
 if _texture!=null:return _texture
 # Fresh source checkout and imported exported package both supported.
 var source:Texture2D
 if FileAccess.file_exists(PATH+".import") or not FileAccess.file_exists(PATH):
  source=load(PATH) as Texture2D
 elif FileAccess.file_exists(PATH):
  var image=Image.load_from_file(PATH)
  if image!=null:source=ImageTexture.create_from_image(image)
 if source==null:source=load(PATH) as Texture2D
 if source!=null:
  _texture=CanvasTexture.new();_texture.diffuse_texture=source
  _texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 return _texture
static func frame(hero:String,time:float,state:String="idle",reduced:bool=false)->Dictionary:
 var clock:=0.0 if reduced else time
 var breathing:=sin(clock*2.3)
 var offset:=Vector2(0,round(breathing*1.5))
 var zoom:=1.0+.007*breathing
 var accent:=0.0
 var tint:=Color.WHITE
 match state:
  "ready":
   offset.y-=1;accent=.45+.15*sin(clock*3.0)
  "skill":
   offset=Vector2(round(sin(clock*5.0)*2),-3);zoom=1.025;accent=1.0
  "cheer":
   offset.y=-2-round(abs(sin(clock*5.0))*3);accent=.8;zoom=1.015
  "hit":
   offset=Vector2(2 if reduced else round(sin(clock*16.0)*3),1)
   tint=Color(1,.86,.88);zoom=.99
 if reduced:offset=Vector2.ZERO;zoom=1.0
 return {"region":REGIONS.get(hero,REGIONS.rio),"offset":offset,"zoom":zoom,"accent":accent,"tint":tint,"state":state}
static func sparkle(canvas:CanvasItem,at:Vector2,size:float,color:Color)->void:
 canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-size),at+Vector2(size*.3,-size*.3),at+Vector2(size,0),at+Vector2(size*.3,size*.3),at+Vector2(0,size),at+Vector2(-size*.3,size*.3),at+Vector2(-size,0),at+Vector2(-size*.3,-size*.3)]),color)
static func draw(canvas:CanvasItem,rect:Rect2,hero:String,time:float,state:String="idle",reduced:bool=false)->void:
 var sheet=texture()
 if sheet==null:return
 var f=frame(hero,time,state,reduced)
 # Integer logical-pixel placement and nearest filtering retain crisp detail.
 # The input rect is a bust viewport; no tiny full-body scaling in the footer.
 var size=(rect.size*f.zoom).round()
 var destination=Rect2((rect.get_center()-size*.5+f.offset).round(),size)
 canvas.draw_texture_rect_region(sheet,destination,f.region,f.tint,false,true)
 if f.accent>0:
  var color=Color("85ffe0") if hero=="rio" else Color("dcc4ff")
  color.a=f.accent
  var phase:=0.0 if reduced else time
  for i in range(3):
   var at=rect.position+Vector2(rect.size.x*(.1+.4*i),rect.size.y*(.2+.12*sin(phase*2+i*2)))
   sparkle(canvas,at.round(),3.0+float(i%2),color)

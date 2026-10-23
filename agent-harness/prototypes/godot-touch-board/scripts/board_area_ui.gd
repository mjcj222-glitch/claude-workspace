extends RefCounted
const MaterialArt=preload("res://scripts/board_premium_skin.gd")
const ORDER=["entry","rest","event","safe","elite","extra","shop","boss"]
const CENTERS=[Vector2(360,268),Vector2(180,408),Vector2(540,408),Vector2(180,548),Vector2(540,548),Vector2(180,688),Vector2(540,688),Vector2(360,828)]
const ENTER=Rect2(84,946,552,88)
static func node_rect(index:int)->Rect2:return Rect2(CENTERS[index]-Vector2(90,44),Vector2(180,88))
static func option_rect(index:int)->Rect2:return Rect2(64,390+170*index,592,148)
static func active(phase:String)->bool:return phase in ["map","rest","event","spoils"]
static func rect(phase:String,index:int)->Rect2:
 return (node_rect(index) if index<8 else ENTER) if phase=="map" else (ENTER if phase=="spoils" else option_rect(index))
static func hit(phase:String,pos:Vector2)->int:
 var count:=9 if phase=="map" else (1 if phase=="spoils" else 2)
 for i in range(count):
  if rect(phase,i).has_point(pos):return i
 return -1
static func description(s,id:String)->Array:
 match id:
  "entry":return ["HP24 · 3회 후 공격4 · 약점 불꽃","승리4G + 미보유 유물1"]
  "rest":return ["3G로 최대8 회복 또는 무료 통과","회복 상한30 · 충전은 그대로"]
  "event":return ["3G로 명시된 미보유 유물 또는 +2G","비용·유물 확인 후 한 가지만 선택"]
  "safe":return ["HP36 · 경감7→3 / 일반5 · 새잎","승리4G + 유물1 · 이후 경로 선택"]
  "elite","extra":return ["HP44 · 경감8→4 / 일반6 · 번개","승리8G + 유물1 · 소진 시 추가4G"]
  "shop":return ["회복4G / 남은 유물8G · 각 한 번","구매 없이 나갈 수 있음 · 이후 보스"]
  "boss":return ["HP48 · 가능한 강타10→4 / 일반6","약점 물결 · 승패로 한 구역 종료"]
 return ["다음으로 갈 지점을 선택하세요","지도에서 연결된 밝은 지점만 입장 가능"]
static func draw(view,canvas:CanvasItem)->void:
 var s=view.session;var ui=view.UI
 canvas.draw_rect(Rect2(0,88,720,992),Color("100b1b"))
 ui._modal_text(view,canvas,Vector2(360,130),"자수정 온실 · 한 구역",32,Color("fff0d3"),true,true)
 ui._modal_text(view,canvas,Vector2(360,171),"생명 %d/30 · %dG · 유물%d · 충전%d/%d"%[s.hp,s.gold,s.relics.size(),s.charge,s.charge_required],24,ui.MINT,true)
 if s.phase=="map":
  if s.relics.is_empty():ui._modal_text(view,canvas,Vector2(360,211),"보유 유물 없음",21,ui.MUTED,true)
  for i in range(s.relics.size()):
   var relic:String=s.relics[i]
   ui.RelicArt.draw_icon(canvas,relic,Rect2(136+i*176,183,36,36))
   ui._modal_text(view,canvas,Vector2(180+i*176,209),ui.RELIC_COPY[relic].name,21,ui.MUTED)
  var allowed:Array=s.allowed_nodes()
  var reachable:Array=s.reachable_nodes()
  for source in s.EDGES:
   if source=="start":continue
   for target in s.EDGES[source]:
    var a:Vector2=CENTERS[ORDER.find(source)];var b:Vector2=CENTERS[ORDER.find(target)]
    var tint:Color=Color("a57bd2") if source==s.current_node and target in allowed else Color("35283e")
    canvas.draw_line(a,b,tint,3,true)
    var direction:Vector2=a.direction_to(b);var mid:Vector2=a.lerp(b,.5)
    canvas.draw_polyline(PackedVector2Array([mid-direction*8+direction.orthogonal()*5,mid,mid-direction*8-direction.orthogonal()*5]),tint,2,true)
  for i in range(ORDER.size()):
   var id:String=ORDER[i];var available:bool=id in allowed;var visited:bool=s.visited.has(id);var selected:bool=s.selected_node==id
   MaterialArt.button(canvas,node_rect(i),ui.MINT,"selected" if selected else ("normal" if available else "disabled"))
   ui._modal_text(view,canvas,CENTERS[i]+Vector2(0,-2),s.NODES[id].name+(" ✓" if visited else ""),24,Color("fff0d3") if available or visited else ui.MUTED,true)
   var tag:String="후보" if selected else ("방문" if visited else ("선택 가능" if available else ("앞의 경로" if id in reachable else "닫힌 길")))
   ui._modal_text(view,canvas,CENTERS[i]+Vector2(0,27),tag,21,ui.MINT if available else ui.MUTED,true)
  var lines:Array=description(s,s.selected_node)
  for i in range(2):ui._modal_text(view,canvas,Vector2(360,894+29*i),lines[i],22,Color("e8d7ef"),true)
  MaterialArt.button(canvas,ENTER,ui.MINT,"disabled" if s.selected_node=="" else ("pressed" if view.modal_index==8 else "ready"))
  ui._modal_text(view,canvas,ENTER.get_center()+Vector2(0,10),(s.NODES[s.selected_node].name+" 입장") if s.selected_node!="" else "다음 지점을 고르세요",29,Color("fff0ff"),true,true)
  return
 if s.phase=="spoils":
  ui._modal_text(view,canvas,Vector2(360,360),"승리 보상",36,ui.MINT,true,true)
  ui._modal_text(view,canvas,Vector2(360,440),s.reward_notice,27,Color("fff0d3"),true)
  ui._modal_text(view,canvas,Vector2(360,492),"이미 지급했어요 · 확인해도 중복 지급 없음",23,ui.MUTED,true)
  MaterialArt.button(canvas,ENTER,ui.MINT,"ready");ui._modal_text(view,canvas,ENTER.get_center()+Vector2(0,10),"지도로",29,Color.WHITE,true,true);return
 var rest:bool=s.phase=="rest"
 ui._modal_text(view,canvas,Vector2(360,285),"휴식 · 한 번만 선택" if rest else "촉매 거래 · 한 가지만 선택",32,Color("fff0d3"),true,true)
 var relic:String=s.event_relic() if not rest else ""
 var enabled:bool=s.gold>=3 and (s.rest_gain()>0 if rest else relic!="")
 var names:Array=["3G · 생명 +%d (%d → %d)"%[s.rest_gain(),s.hp,s.hp+s.rest_gain()],"무료로 지나가기"] if rest else ["3G · "+(ui.RELIC_COPY[relic].name if relic!="" else "유물 칸 가득"),"보급품 받기 · +2G"]
 for i in range(2):
  var r:=option_rect(i);var can:bool=i==1 or enabled
  MaterialArt.button(canvas,r,ui.MINT,"disabled" if not can else ("pressed" if view.modal_index==i else "normal"))
  ui._modal_text(view,canvas,r.position+Vector2(26,48),names[i],29,Color("fff0d3") if can else ui.MUTED)
  var detail:String=("최대8 회복 · 체력 상한30" if i==0 else "비용·회복 없이 다음 경로") if rest else ((ui.relic_copy(relic,s).change if relic!="" else "교환 불가 · 아래 보급품 선택 가능") if i==0 else "비용 없음 · 유물 대신 재화 선택")
  ui._modal_text(view,canvas,r.position+Vector2(26,91),detail,23,ui.MUTED)
  ui._modal_text(view,canvas,r.position+Vector2(26,126),"잔액/체력/미보유 유물을 확인하세요" if not can else "눌렀다 놓으면 확정 · 되돌리기 없음",22,ui.MUTED)

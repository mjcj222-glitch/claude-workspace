extends SceneTree
const Session=preload("res://scripts/board_session.gd")
const Art=preload("res://scripts/board_art.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func p(id:int,pos:Vector2,kind:String)->Dictionary:return {"id":id,"pos":pos,"kind":kind,"radius":48.0 if kind=="big_bomb" else 37.0,"color":0}
func _init()->void:
 var s=Session.new();s.panels=[p(1,Vector2(200,500),"big_bomb")]
 check(s.begin(Vector2(244,500),-1) and s.selection.get("valid",false),"exposed enlarged body rim can be pressed")
 if s.selection.is_empty():print("BOMB_BODY checks=",checks," failures=",failures);quit(1);return
 s.cancel();check(not s.begin(Vector2(250,500),-1),"beyond visible body does not hit")
 s.panels.append(p(2,Vector2(274,500),"normal"));s.begin(Vector2(241,500),-1)
 check(not s.selection.get("valid",true),"front neighbor owns its visible pixels even inside enlarged bomb rim")
 s.cancel();s.panels[1].kind="bomb";s.begin(Vector2(241,500),-1)
 check(s.selection.direct==[1],"transparent padding of smaller bomb cannot steal exposed large rim")
 s.cancel();s.panels=[p(1,Vector2(200,500),"big_bomb"),p(3,Vector2(274,500),"big_bomb")];s.begin(Vector2(237,500),-1)
 check(s.selection.direct==[3],"overlapping large shells use the same high-ID front order as rendering")
 s.cancel();s.panels=[p(1,Vector2(67,500),"big_bomb")]
 check(s.begin(Vector2(31,500),-1),"inside board wall fragment remains selectable")
 s.cancel();check(not s.begin(Vector2(29,500),-1),"clipped outside body cannot steal UI or click beyond board")
 var view=load("res://scripts/board_panel_view.gd")
 check(view!=null,"shared view metadata exists")
 if view!=null:
  check(view.visual_radius(p(1,Vector2.ZERO,"big_bomb"))==48 and view.visual_radius(p(2,Vector2.ZERO,"bomb"))==30,"large body96px is larger than normal body60px and chip74px")
  var original:Array=[p(9,Vector2.ZERO,"normal"),p(7,Vector2.ZERO,"big_bomb"),p(2,Vector2.ZERO,"big_bomb")]
  var snapshot:Array=original.duplicate(true);var order:Array=view.draw_order(original)
  check(order.map(func(x):return x.id)==[2,7,9] and original==snapshot,"render order stable without mutating board state")
 s.panels=[p(1,Vector2(200,500),"big_bomb")];var before:Array=s.panels.duplicate(true)
 s.begin(Vector2(244,500),-1);var plan:Dictionary=s.selection.duplicate(true);s.cancel();s.release(Vector2(244,500),-1)
 check(s.actions==0 and s.panels==before,"rim cancellation has no action or state change")
 s.begin(Vector2(244,500),-1);var committed:Dictionary=s.release(Vector2(244,500),-1)
 check(committed.removed==plan.removed and committed.blasts[0].radius==164,"rim selects same canonical explosion, not expanded damage")
 var layout=preload("res://scripts/board_layout.gd")
 for zoom in [.5,1.0,1.25]:
  var logical:=Rect2(30,290,660,530);var display:=Rect2(25,50,660*zoom,530*zoom)
  var rim:=Vector2(244,500);var screen:Vector2=layout.board_to_screen(rim,logical,display)
  var back:Vector2=layout.screen_to_board(screen,logical,display)
  check(back.distance_to(rim)<.001 and view.hit_test([p(1,Vector2(200,500),"big_bomb")],back)==1,"zoom inverse preserves visible outer-rim selection at "+str(zoom))
 print("BOMB_BODY checks=",checks," failures=",failures);quit(1 if failures else 0)

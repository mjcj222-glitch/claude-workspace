extends RefCounted
const Store=preload("res://scripts/board_checkpoint.gd")
const RETRY=Rect2(40,90,640,62)
const RETRY_DELAYS=[1000,3000,7000]
const PRIMARY=Rect2(84,440,552,90)
const SECONDARY=Rect2(84,570,552,90)
var enabled=false
var store
var modal=""
var notice=""
var error=""
var pending={}
var pointer=-99
var choice=-1
var dirty=false
var terminal_done=false
var terminal_pending=false
var last_state={}
var pending_save={}
var failures=0
var retry_at=0
func setup(view,args:Array):
 # Script-driven diagnostics never touch ordinary user data. Save tests must
 # opt into an isolated directory explicitly; normal project launches save.
 var explicit_directory=false
 for arg in args:
  if arg.begins_with("--save-dir="):explicit_directory=true
 enabled=not view.sandbox and not view.short_run and "--no-save" not in args and ("--script" not in OS.get_cmdline_args() or explicit_directory)
 if not enabled:return
 var path="user://chroma-checkpoint"
 for arg in args:
  if arg.begins_with("--save-dir="):path=arg.trim_prefix("--save-dir=")
 view.get_tree().auto_accept_quit=false
 store=Store.new(path)
 var loaded=store.load_run()
 if loaded.ok:
  pending=loaded.data;modal="resume"
  notice="이전 정상 저장을 복구합니다" if loaded.recovered else "진행 중인 탐험이 있습니다"
 elif loaded.get("closed",false):modal="closed";notice="완료 기록이 있어 재개하지 않습니다"
 elif loaded.get("exists",false):modal="invalid";notice="저장을 읽을 수 없습니다 · 원본은 보관됩니다"
func cancel():
 pointer=-99;choice=-1
func request_new(view):
 if not enabled:view.reset_board();return
 view.cancel_input();cancel()
 if (view.session.phase in ["victory","defeat"] and terminal_done) or modal=="closed":
  begin_new(view);return
 modal="confirm";notice="진행 중인 탐험 대신 새로 시작할까요?"
func begin_new(view):
 if not store.archive():error=store.error;return
 modal="";pending={};last_state={};dirty=false;terminal_done=false;error="";cancel()
 pending_save={};failures=0;retry_at=0;terminal_pending=false
 view.reset_board()
func press(pos:Vector2,id:int):
 if pointer!=-99:return
 var index=0 if PRIMARY.has_point(pos) else (1 if SECONDARY.has_point(pos) else -1)
 if index<0:return
 pointer=id;choice=index
func move(pos:Vector2,id:int):
 var rect=RETRY if choice==2 else (PRIMARY if choice==0 else SECONDARY)
 if id==pointer and not rect.has_point(pos):cancel()
func retry_hit(pos:Vector2)->bool:return enabled and error!="" and RETRY.has_point(pos)
func press_retry(pos:Vector2,id:int):
 if pointer==-99 and retry_hit(pos):pointer=id;choice=2
func release(view,pos:Vector2,id:int):
 if id!=pointer:return
 var index=choice;var hit=(RETRY if index==2 else (PRIMARY if index==0 else SECONDARY)).has_point(pos);cancel()
 if not hit:return
 if index==2:
  failures=0;retry_at=0;dirty=true;checkpoint(view);return
 if modal=="quit":
  if index==0:
   if request_quit(view):view.get_tree().quit()
  else:view.get_tree().quit()
  return
 if modal=="confirm":
  if index==0:begin_new(view)
  else:
   modal="resume" if not pending.is_empty() else ""
   if modal=="" and store.load_run().get("exists",false) and not view.session.departure_started:modal="invalid"
 elif modal=="resume":
  if index==0:
   Store.restore(view,pending);last_state=pending.duplicate(true);pending={};modal="";dirty=false
   view.status="마지막 완료 시점에서 이어갑니다"
  else:request_new(view)
 elif modal=="closed":
  if index==0:begin_new(view)
 elif modal=="invalid":
  if index==0:request_new(view)
 # A second click on the departing button must not hit the underlying board
 # or character card. Other positions remain responsive immediately.
 if modal=="":
  view.transition_repeat_at=pos
  view.transition_repeat_until_ms=Time.get_ticks_msec()+view.TRANSITION_REPEAT_MS
func _stable(view)->bool:
 return view.session.phase in Store.STABLE and view.session.departure_started and view.session.owner==-99 and view.modal_pointer==-99 and view.detail_pointer==-99 and not view.falling
func _attempt(view,now:int):
 var terminal=view.session.phase in ["victory","defeat"]
 var ok=false
 if terminal:
  ok=terminal_done or store.close_run()
  terminal_done=ok
 elif not pending_save.is_empty():
  ok=store.save(pending_save)
  if ok:last_state=pending_save.duplicate(true)
 else:return
 if ok:
  dirty=not terminal and not _stable(view);pending_save={};error="";failures=0;retry_at=0
 else:
  error=store.error;dirty=true;failures+=1
  retry_at=now+RETRY_DELAYS[failures-1] if failures<=RETRY_DELAYS.size() else -1
func checkpoint(view,now:int=-1):
 if not enabled or modal!="" or not dirty:return
 if now<0:now=Time.get_ticks_msec()
 var terminal=view.session.phase in ["victory","defeat"]
 if terminal and not terminal_pending:
  terminal_pending=true;failures=0;retry_at=0;pending_save={}
 if not terminal and _stable(view):
  var data=Store.capture(view)
  if data==last_state and error=="":dirty=false;return
  pending_save=data
 if not terminal and pending_save.is_empty():return
 if retry_at==-1 or now<retry_at:return
 _attempt(view,now)
func request_quit(view)->bool:
 if not enabled:return true
 view.cancel_input();cancel()
 # Never capture an animation; retry the most recent completed checkpoint.
 if _stable(view) and modal in ["","quit"]:
  var data=Store.capture(view)
  if data!=last_state:pending_save=data;dirty=true
 if view.session.phase in ["victory","defeat"] and not terminal_done:dirty=true
 if dirty:_attempt(view,Time.get_ticks_msec())
 if error=="":return true
 modal="quit";notice="저장 실패 · 이전 진행이 남을 수 있습니다"
 return false
func draw(view,canvas:CanvasItem):
 if not enabled:return
 var ui=view.UI
 if modal=="":
  if error!="":
   canvas.draw_rect(RETRY,Color("24152c"))
   ui._modal_text(view,canvas,Vector2(360,108),"저장되지 않음 · 최근 진행을 잃을 수 있습니다",20,Color("ffb0aa"),true)
   ui._modal_text(view,canvas,Vector2(360,137),("자동 재시도 중" if retry_at!=-1 else "자동 재시도 중단")+" · 여기를 눌러 다시 시도",19,Color("ffb0aa"),true)
  return
 canvas.draw_rect(Rect2(0,88,720,992),Color("100b1b"))
 ui._modal_text(view,canvas,Vector2(360,230),"저장 확인" if modal=="quit" else ("탐험 이어하기" if modal=="resume" else "새 탐험"),36,Color("fff0d3"),true,true)
 ui._modal_text(view,canvas,Vector2(360,310),notice,23,Color("f3f2ef"),true)
 var first="이어하기" if modal=="resume" else ("이전 탐험 보관 후 새로 시작" if modal=="confirm" else "새 탐험")
 var second="취소" if modal=="confirm" else "새 탐험"
 if modal=="quit":first="저장 재시도 후 종료";second="저장 없이 종료"
 for i in range(2 if modal in ["resume","confirm","quit"] else 1):
  var rect=PRIMARY if i==0 else SECONDARY
  ui.MaterialArt.button(canvas,rect,Color("dfb5ff"),"pressed" if choice==i else "normal")
  ui._modal_text(view,canvas,rect.get_center()+Vector2(0,10),first if i==0 else second,27,Color("fff0ff"),true,true)
 ui._modal_text(view,canvas,Vector2(360,750),"완료된 행동 뒤 자동 저장됩니다",24,ui.MUTED,true)
 ui._modal_text(view,canvas,Vector2(360,793),"연쇄·낙하·반격 중 종료하면",23,ui.MUTED,true)
 ui._modal_text(view,canvas,Vector2(360,829),"마지막 완료 시점부터 다시 진행합니다",23,ui.MUTED,true)
 if error!="":ui._modal_text(view,canvas,Vector2(360,905),error,21,Color("ffb0aa"),true)

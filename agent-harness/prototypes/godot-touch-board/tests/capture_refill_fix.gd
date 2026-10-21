extends SceneTree
## Diagnostic fixture playback, not an uninterrupted normal run or timing evidence.
const Art=preload("res://scripts/board_art.gd")
const BOUNDS=Rect2(30,290,660,530)
class Display extends Node2D:
	var samples:Array=[]
	var initial:Array=[]
	var colors:Dictionary={}
	var at:=0.0
	var font:Font
	func _draw()->void:
		draw_rect(Rect2(0,0,720,430),Color("100c16"))
		draw_string(font,Vector2(18,27),"seed23 · 저장 상태 재현 / 고정30fps · 실시간 측정 아님",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
		for i in range(2):
			var x:float=18+i*355
			var result:Dictionary=samples[i]
			draw_string(font,Vector2(x,58),"수정 전 · 상단 재이탈" if i==0 else "수정 후 · 현재 입구 선택",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("dfbe83"))
			draw_set_transform(Vector2(x,76),0,Vector2(0.47,0.47))
			draw_rect(Rect2(Vector2.ZERO,BOUNDS.size),Color("07060a"))
			draw_rect(Rect2(Vector2.ZERO,BOUNDS.size),Color("dfbe83"),false,2)
			var frame:Array=initial if at<=0.0 else result.frames[mini(result.frames.size()-1,maxi(0,int(at*120)-1))]
			for row in frame:
				var panel:Dictionary=colors[int(row[0])].duplicate(true)
				panel.pos=Vector2(row[1],row[2])-BOUNDS.position
				Art.draw_panel(self,panel,at)
				if int(row[0])==255:draw_arc(panel.pos,40,0,TAU,32,Color("fff5a3"),3,true)
			draw_set_transform(Vector2.ZERO)
			var done:bool=at>=result.state.elapsed
			var status:="4.008s · 멈춤" if i==0 and done else ("0.992s · 정상 완료" if i==1 and done else "낙하 중")
			draw_string(font,Vector2(x,356),status,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("ff6477") if i==0 and done else Color("e3c4ff"))
			draw_string(font,Vector2(x,389),"같은 시작 위치·속도·난수",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("b9adc7"))
		draw_string(font,Vector2(18,419),"밝은 테두리: 새 패널 ID255 · 물리/입력 규칙과4초 제한 유지",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("b9adc7"))
func _initialize()->void:call_deferred("run")
func read_var(path:String)->Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ);return f.get_var(false)
func run()->void:
	var view:=Display.new()
	view.font=load("res://assets/fonts/Pretendard-Medium.otf")
	if view.font==null:view.font=ThemeDB.fallback_font
	var saved:=read_var("res://evidence/balance/stall-reproduction/state.var")
	view.samples=[read_var("res://evidence/refill-stall/exact-red.var"),read_var("res://evidence/refill-stall/exact-green.var")]
	for panel in saved.motion.panels:view.colors[int(panel.id)]=panel
	for panel in saved.survivors_before_refill:view.initial.append([panel.id,panel.pos.x,panel.pos.y])
	root.add_child(view)
	for frame in range(152):
		view.at=minf(4.01,float(frame)/30.0);view.queue_redraw()
		await process_frame
		if frame==151:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(0,0,720,430)).save_png("res://evidence/refill-stall/comparison-final.png")
	quit()

extends SceneTree
## Presentation contract checks: existing hit geometry and critical text fit.
const UI = preload("res://scripts/board_ui.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ",label)
func _initialize() -> void:
	check(UI.BOARD_SCREEN==Rect2(30,268,660,530),"full board mapping remains unchanged")
	check(UI.SKILL==Rect2(180,846,412,100) and UI.RESET==Rect2(608,12,88,88) and UI.MUTE==Rect2(608,850,88,88),"existing pointer targets unchanged")
	check(UI.SUMMARY_CONTINUE==Rect2(84,670,552,88),"existing modal continue target unchanged")
	for i in range(4):check(UI.color_rect(i)==Rect2(150+136*i,966,120,88),"palette target unchanged")
	for i in range(3):check(UI.owned_rect(i)==Rect2(180+104*i,974,88,88),"owned target unchanged")
	var body: Font = load("res://assets/fonts/Pretendard-Medium.otf")
	var bold: Font = load("res://assets/fonts/Pretendard-SemiBold.otf")
	var display: Font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	for text in ["색 선택 중 · 다시 누르면 취소","최대 5개 변환 · 소거 무료"]:
		check(body.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<=372,"skill body fits without shrinking: "+text)
	for count in [2,3]:
		check(bold.get_string_size("%d / %d"%[count,count],HORIZONTAL_ALIGNMENT_LEFT,-1,24).x<=82,"full charge label fits next to title")
	check(display.get_string_size("색을 잇는 붓",HORIZONTAL_ALIGNMENT_LEFT,-1,28).x<=240,"skill title avoids charge indicator")
	for id in UI.RELIC_COPY:
		var copy: Dictionary = UI.RELIC_COPY[id]
		check(display.get_string_size(copy.name,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x<=440,"relic heading fits")
		for text in [copy.change]+copy.lines:
			check(body.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<=449,"relic body fits without shrinking: "+text)
	print("SKIN_CONTRACT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

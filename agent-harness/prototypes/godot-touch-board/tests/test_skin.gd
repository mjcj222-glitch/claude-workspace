extends SceneTree
## Presentation contract checks: existing hit geometry and critical text fit.
const UI = preload("res://scripts/board_ui.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ",label)
func _initialize() -> void:
	check(UI.BOARD_SCREEN==Rect2(30,390,660,530),"premium board retains full logical dimensions")
	check(UI.SKILL==Rect2(190,950,240,112) and UI.RESET==Rect2(616,0,88,88) and UI.MUTE==Rect2(520,0,88,88),"premium control geometry matches rendered artwork")
	check(UI.SUMMARY_CONTINUE==Rect2(84,670,552,88),"existing modal continue target unchanged")
	for i in range(4):check(UI.color_rect(i)==Rect2(96+136*i,220,120,88),"upper palette keeps44px touch targets")
	for i in range(3):check(UI.owned_rect(i)==Rect2(440+88*i,976,88,88),"compact relic dock keeps44px touch targets")
	var body: Font = load("res://assets/fonts/Pretendard-Medium.otf")
	var bold: Font = load("res://assets/fonts/Pretendard-SemiBold.otf")
	var display: Font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	for text in ["준비 · 3 / 3","충전 · 1 / 2","최대 5개 · 소거 무료"]:
		check(body.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<=240,"skill copy fits without shrinking: "+text)
	for count in [2,3]:
		check(bold.get_string_size("%d / %d"%[count,count],HORIZONTAL_ALIGNMENT_LEFT,-1,24).x<=82,"full charge label fits next to title")
	check(display.get_string_size("변환",HORIZONTAL_ALIGNMENT_LEFT,-1,30).x<=180,"skill title fits gemstone inset")
	for id in UI.RELIC_COPY:
		var copy: Dictionary = UI.RELIC_COPY[id]
		check(display.get_string_size(copy.name,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x<=440,"relic heading fits")
		for text in [copy.change]+copy.lines:
			check(body.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<=449,"relic body fits without shrinking: "+text)
	print("SKIN_CONTRACT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

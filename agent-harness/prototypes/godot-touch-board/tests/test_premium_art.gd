extends SceneTree
const Art=preload("res://scripts/board_art.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var art=Art.new()
	check(art.has_method("draw_battle_stage") and art.has_method("draw_premium_hero") and art.has_method("draw_skill_button"),"separate original artwork has runtime integration")
	if not failures.is_empty():finish();return
	var box:=Rect2(190,950,240,112)
	var fitted: Rect2=art.call("skill_button_rect",box)
	check(box.encloses(fitted) and is_equal_approx(fitted.size.x/fitted.size.y,1983.0/793.0),"full gold button silhouette fits without stretching or clipping")
	for age in [0.0,0.2,1.0,10.0]:
		check(art.call("skill_illumination",false,age)==0.0,"unavailable never pulses bright")
		check(art.call("skill_illumination",true,age)>0.0,"available state illuminates")
	check(art.call("stage_variant",0)=="training" and art.call("stage_variant",1)=="training" and art.call("stage_variant",2)=="dragon","baked dragon only represents final encounter")
	check(ResourceLoader.exists("res://assets/premium/amethyst-dragon-arena-v1.png") and ResourceLoader.exists("res://assets/premium/skill-button-amethyst-base-v1.png"),"actual separate original textures imported")
	finish()
func finish()->void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

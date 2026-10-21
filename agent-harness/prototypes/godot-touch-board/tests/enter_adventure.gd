extends RefCounted
## Explicit normal departure for preexisting main-scene integration tests.
## Session-only/sandbox fixtures retain their original API.
static func enter(scene,hero:String="rio")->void:
	if scene.session.phase!="departure":return
	var index:=0 if hero=="rio" else 1
	var card:Vector2=scene.UI.character_rect(index).get_center()
	scene.press(card,-1);scene.release(card,-1)
	var button:Vector2=scene.UI.DEPART.get_center()
	scene.press(button,-1);scene.release(button,-1)
	assert(scene.session.phase=="ready" and scene.session.character_id==hero)
	# Outside any timed interaction; let the real departing-control double-tap
	# guard expire before legacy fixture assertions start.
	OS.delay_msec(510)

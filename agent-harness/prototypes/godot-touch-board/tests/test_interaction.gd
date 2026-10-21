extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL " + label)
func _init() -> void:
	var path := "res://scripts/board_session.gd"
	if not ResourceLoader.exists(path):
		check(false, "session exists to enforce pointer/action contract")
		quit(1)
		return
	var Session = load(path)
	var s = Session.new()
	s.bounds = Rect2(0, 0, 400, 400)
	s.panels = [{"id":1,"pos":Vector2(80,100),"radius":30.0,"color":0,"kind":"normal"},{"id":2,"pos":Vector2(140,100),"radius":30.0,"color":0,"kind":"normal"},{"id":3,"pos":Vector2(200,100),"radius":30.0,"color":1,"kind":"normal"}]
	check(s.begin(Vector2(80,100), 0), "valid press starts preview")
	var preview: Dictionary = s.selection.duplicate(true)
	check(not s.begin(Vector2(140,100), 1), "additional finger ignored")
	check(s.release(Vector2(140,100), 1).is_empty(), "additional finger cannot commit")
	check(s.actions == 0, "additional finger consumes no action")
	s.move(Vector2(500,500), 0)
	check(s.selection.is_empty(), "outside movement cancels")
	check(s.release(Vector2(80,100), 0).is_empty() and s.actions == 0, "reenter cannot commit cancelled press")
	s.begin(Vector2(80,100), 0)
	s.cancel()
	check(s.release(Vector2(80,100), 0).is_empty(), "focus/system cancellation")
	s.begin(Vector2(80,100), 0)
	var executed: Dictionary = s.release(Vector2(80,100), 0)
	check(executed == preview, "release executes exact preview plan")
	check(s.actions == 1 and s.damage_total == 2, "valid clear counts once")
	check(not s.begin(Vector2(200,100), 0), "busy ignores press without queuing")
	s.phase = "ready"
	check(s.release(Vector2(200,100), 0).is_empty(), "busy press cannot execute later")
	check(s.panels.size() == 1, "removed applied once; refill separate")
	s.begin(Vector2(200,100), 0)
	s.release(Vector2(200,100), 0)
	check(s.actions == 1, "invalid singleton free")
	s.skill_mode = true
	s.skill_color = 2
	s.begin(Vector2(200,100), 0)
	var sp: Dictionary = s.release(Vector2(200,100), 0)
	check(not sp.is_empty() and s.panels[0].color == 2, "skill applies shown conversion")
	check(s.actions == 1 and s.charge == 0 and s.phase == "ready", "skill no action or refill, consumes charge")
	for i in range(3):
		s.phase = "ready"
		s.panels = [{"id":20,"pos":Vector2(80,100),"radius":30.0,"color":0,"kind":"normal"},{"id":21,"pos":Vector2(140,100),"radius":30.0,"color":0,"kind":"normal"}]
		s.begin(Vector2(80,100), 0)
		s.release(Vector2(80,100), 0)
		check(s.charge == i + 1, "exactly three manual clears recharge")
	check(s.actions == 4, "three recharge clears each consume one action")
	print("INTERACTION failures=", failures)
	quit(1 if failures else 0)

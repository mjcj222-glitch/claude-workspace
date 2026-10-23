extends "res://tests/v2/window_input_test.gd"
## OS injection is external XTest; only the stale-version fixture mutates versions.
var sequence := 0
var bridge := ""
func _initialize() -> void:
    source = "authenticated X11 XTest OS mouse, Escape, focus, external XResizeWindow; stale-version fixtures"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--bridge-dir="): bridge = arg.trim_prefix("--bridge-dir=")
    call_deferred("run")
func request(payload: Dictionary) -> void:
    sequence += 1
    payload.sequence = sequence
    var file := FileAccess.open(bridge+"/request.json",FileAccess.WRITE)
    if file == null: check(false,"OS bridge path opens"); return
    file.store_string(JSON.stringify(payload))
    file.close()
    var deadline := Time.get_ticks_msec()+10000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if FileAccess.file_exists(bridge+"/ack.json"):
            var ack = JSON.parse_string(FileAccess.get_file_as_string(bridge+"/ack.json"))
            if ack is Dictionary and ack.get("sequence",-1) == sequence:
                await frames(6)
                return
    check(false,"OS bridge timeout")
func resize_window(size_value: Vector2i) -> void:
    await request({"kind":"resize","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,root.get_window_id()),"width":size_value.x,"height":size_value.y})
    await frames(10)
func mouse(point: Vector2, action: String) -> void:
    var native: Vector2 = Vector2(root.position)+NativeInput.window_point(root,point)
    await request({"kind":"mouse","action":action,"x":roundi(native.x),"y":roundi(native.y)})
func press(point: Vector2) -> void: await mouse(point,"press")
func release(point: Vector2) -> void: await mouse(point,"release")
func move(point: Vector2) -> void: await mouse(point,"move")
func cancel() -> void: await request({"kind":"escape"})
func focus_out() -> void: await request({"kind":"focus_out"})
func capture(name_value: String) -> void:
    await RenderingServer.frame_post_draw
    await request({"kind":"capture","name":name_value+".png","x":root.position.x,"y":root.position.y,"width":root.size.x,"height":root.size.y})

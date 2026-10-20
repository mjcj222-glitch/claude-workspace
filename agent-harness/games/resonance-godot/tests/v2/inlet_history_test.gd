extends SceneTree
## Child project freezes historical1.0 legality until the exact failing Board action.
func _initialize() -> void: call_deferred("run")
func run() -> void:
    if "--no-save" not in OS.get_cmdline_user_args():
        print("FAIL: historical fixture requires --no-save")
        quit(1)
        return
    var output: Array = []
    var code := OS.execute("python3",[ProjectSettings.globalize_path("res://tests/v2/fixtures/inlet_history/run.py")],output,true)
    for line in output: print(line)
    print(JSON.stringify({"suite":"v2 historical inlet launcher","failures":0 if code == 0 else 1,"child_exit":code}))
    quit(code)

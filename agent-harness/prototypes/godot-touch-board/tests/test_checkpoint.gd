extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
var failures=0
var checks=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(scene)
 var data=Store.capture(scene)
 check(Store.valid(data),"stable area snapshot validates")
 var folder="/tmp/chroma-checkpoint-unit-"+str(OS.get_process_id())
 var store=Store.new(folder)
 check(store.save(data),"atomic initial save")
 var loaded=store.load_run()
 check(loaded.ok and loaded.data==data,"lossless int64 RNG and Vector2 roundtrip")
 data.session.gold=2
 check(store.save(data),"second checkpoint keeps backup")
 FileAccess.open(folder+"/current.json",FileAccess.WRITE).store_string("truncated")
 loaded=store.load_run()
 check(loaded.ok and loaded.recovered and loaded.data.session.gold==0,"corrupt current recovers last valid")
 check(FileAccess.get_file_as_string(folder+"/current.json")=="truncated","read preserves corrupt bytes")
 check(store.save(loaded.data),"explicit recovery can save")
 var invalids=[]
 var bad=data.duplicate(true);bad.rng="1";invalids.append(bad)
 bad=data.duplicate(true);bad.session.panels[1].id=bad.session.panels[0].id;invalids.append(bad)
 bad=data.duplicate(true);bad.session.hp=999;invalids.append(bad)
 bad=data.duplicate(true);bad.session.phase="busy";invalids.append(bad)
 bad=data.duplicate(true);bad.session.history=["boss"];invalids.append(bad)
 bad=data.duplicate(true);bad.combat.intent="unknown";invalids.append(bad)
 bad=data.duplicate(true);bad.session.panels[0].pos=Vector2(INF,1);invalids.append(bad)
 for i in invalids.size():check(not Store.valid(invalids[i]),"invalid schema "+str(i))
 var encoded=JSON.parse_string(Store.encode(data));encoded.version=99
 FileAccess.open(folder+"/unsupported.json",FileAccess.WRITE).store_string(JSON.stringify(encoded))
 check(not store.read_file(folder+"/unsupported.json").ok,"incompatible version rejected")
 encoded=JSON.parse_string(Store.encode(data));encoded.sha256="bad"
 FileAccess.open(folder+"/checksum.json",FileAccess.WRITE).store_string(JSON.stringify(encoded))
 check(not store.read_file(folder+"/checksum.json").ok,"checksum rejected")
 # A leftover uncommitted temporary file must never outrank current.
 FileAccess.open(folder+"/current.json.tmp",FileAccess.WRITE).store_string(Store.encode(data))
 check(store.load_run().data.session.gold==0,"uncommitted temp ignored")
 DirAccess.remove_absolute(folder+"/current.json.tmp")
 DirAccess.make_dir_recursive_absolute(folder+"/current.json.tmp")
 check(not store.save(data) and store.error!="","write failure explicitly reported")
 check(store.load_run().data.session.gold==0,"failed replacement retains current")
 DirAccess.remove_absolute(folder+"/current.json.tmp")
 check(store.close_run(),"terminal barrier committed")
 check(not store.load_run().ok and store.load_run().closed,"terminal cannot recover prior rewards")
 FileAccess.open(folder+"/closed",FileAccess.WRITE).store_string("")
 check(not store.load_run().ok,"corrupt terminal barrier remains conservative")
 check(not store.save(data),"closed run cannot overwrite barrier")
 check(store.archive() and not store.load_run().get("exists",false),"explicit new run preserves old directory in archive")
 scene.queue_free();await process_frame
 print("CHECKPOINT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

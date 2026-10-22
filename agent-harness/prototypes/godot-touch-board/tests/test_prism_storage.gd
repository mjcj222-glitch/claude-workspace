extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(scene,"noa")
 var data=Store.capture(scene);data.session.rain_remaining=2;data.session.rain_color=3;data.session.charge=0
 var folder="/tmp/chroma-prism-store-"+str(OS.get_process_id());var store=Store.new(folder)
 check(store.save(data),"rain snapshot valid")
 var loaded=store.load_run();check(loaded.ok and loaded.data==data,"rain RNG and board roundtrip exact")
 var old=data.duplicate(true)
 for key in Store.BANK+["strike_settled"]:old.combat.erase(key)
 old.session.erase("rain_remaining");old.session.erase("rain_color");old.combat.erase("shield_hp");old.combat.erase("shield_color")
 var bytes=var_to_bytes(old);var text=JSON.stringify({"version":1,"sha256":Store.checksum(bytes),"payload":Marshalls.raw_to_base64(bytes)})
 var path=folder+"/legacy.json";FileAccess.open(path,FileAccess.WRITE).store_string(text)
 var migrated=store.read_file(path)
 check(migrated.ok and migrated.data.session.rain_remaining==0 and migrated.data.combat.shield_hp==0,"legacy defaults no retroactive shield")
 check(migrated.data.rng==old.rng and migrated.data.session.panels==old.session.panels,"migration preserves RNG IDs and board")
 check(FileAccess.get_file_as_string(path)==text,"read leaves original bytes untouched")
 var bad=data.duplicate(true);bad.session.charge=1
 check(not Store.valid(bad),"active rain cannot bank charge")
 bad=data.duplicate(true);bad.session.rain_remaining=4;check(not Store.valid(bad),"rain bounded to3")
 bad=data.duplicate(true);bad.combat.shield_hp=12;check(not Store.valid(bad),"nonboss shield rejected")
 if not await preload("res://tests/audio_teardown.gd").release(scene,self):failures+=1
 print("PRISM_STORAGE checks=",checks," failures=",failures);quit(1 if failures else 0)

extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
const BANK=["pending_damage","pending_shield","pending_removed","pending_base","pending_weak","pending_specials","pending_bombs","pending_big_bombs"]
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _initialize():call_deferred("run")
func write_version(path:String,data:Dictionary,version:int)->String:
 var bytes=var_to_bytes(data)
 var text=JSON.stringify({"version":version,"sha256":Store.checksum(bytes),"payload":Marshalls.raw_to_base64(bytes)})
 FileAccess.open(path,FileAccess.WRITE).store_string(text)
 return text
func run():
 check(Store.VERSION==3,"bank ledger uses explicit schema version3")
 if Store.VERSION!=3:quit(1);return
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(scene,"rio")
 var c=scene.session.combat
 var plan={"valid":true,"mode":"clear","damage":5,"base_damage":4,"weak_bonus":1,"removed":[1,2,3,4,5,6],"activated":[5,6],"blasts":[{"kind":"big_bomb"}],"shield_damage":0}
 c.record_clear(plan);scene.session.actions+=1
 c.record_clear(plan);scene.session.actions+=1
 var data=Store.capture(scene)
 check(c.enemy_hp==24 and data.combat.pending_damage==10 and data.combat.pending_removed==12,"first two clears capture accumulated attack without early enemy damage")
 check(data.combat.pending_base==8 and data.combat.pending_weak==2 and data.combat.pending_specials==4 and data.combat.pending_bombs==2,"ledger retains damage and effect categories")
 check(Store.valid(data),"two-clear ready checkpoint validates")
 var folder="/tmp/chroma-bank-store-"+str(OS.get_process_id());var store=Store.new(folder)
 check(store.save(data),"bank checkpoint atomically saves")
 var loaded=store.load_run()
 print("ROUNDTRIP ",loaded.get("reason","ok"))
 check(loaded.ok and loaded.data==data,"bank checkpoint read roundtrip exact")
 if not loaded.ok:
  await preload("res://tests/audio_teardown.gd").release(scene,self);quit(1);return
 scene.quality_fx.skill_activated({1:2})
 Store.restore(scene,loaded.data)
 check(Store.capture(scene)==data,"restore preserves bank RNG board and hero exactly")
 check(scene.quality_fx.bank_energy==12 and scene.quality_fx.trails.is_empty() and scene.quality_fx.cutin_remaining==0,"restore charged orb energy without replaying attack trails")
 for version in [1,2]:
  var old=data.duplicate(true)
  for key in BANK:old.combat.erase(key)
  old.combat.erase("strike_settled")
  if version==1:
   old.session.erase("rain_remaining");old.session.erase("rain_color")
   old.combat.erase("shield_hp");old.combat.erase("shield_color")
  var path=folder+"/legacy"+str(version)+".json";var bytes=write_version(path,old,version)
  var migrated=store.read_file(path)
  check(migrated.ok,"version"+str(version)+" legacy first/two-clear save accepted")
  if migrated.ok:
   var empty=true
   for key in BANK:empty=empty and migrated.data.combat[key]==0
   check(empty and not migrated.data.combat.strike_settled,"legacy applied damage does not become a second pending attack")
   check(migrated.data.rng==old.rng and migrated.data.session.panels==old.session.panels and migrated.data.combat.actions_in_turn==2,"migration retains RNG board and completed clear count")
  check(FileAccess.get_file_as_string(path)==bytes,"legacy original bytes unchanged by read")
  old.combat.pending_damage=3;write_version(path,old,version)
  check(not store.read_file(path).ok,"old version cannot smuggle a partial new bank")
 for key in BANK:
  var bad=data.duplicate(true);bad.combat[key]=-1
  check(not Store.valid(bad),"reject negative "+key)
 var bad=data.duplicate(true);bad.combat.pending_removed=97
 check(not Store.valid(bad),"two clears cannot bank more than96 removed panels")
 bad=data.duplicate(true);bad.combat.pending_big_bombs=3
 check(not Store.valid(bad),"big bomb count cannot exceed total bombs")
 bad=data.duplicate(true);bad.combat.pending_bombs=5
 check(not Store.valid(bad),"bombs cannot exceed activated specials")
 bad=data.duplicate(true);bad.combat.pending_shield=1
 check(not Store.valid(bad),"no shield damage can be banked against zero shield")
 bad=data.duplicate(true);bad.combat.pending_damage=999
 check(not Store.valid(bad),"banked damage bounded by actual base/weak/break bonus")
 bad=data.duplicate(true);bad.combat.strike_settled=true
 check(not Store.valid(bad),"ready first/two-clear state cannot already be settled")
 bad=data.duplicate(true);bad.session.phase="player_attack"
 check(not Store.valid(bad),"partial player attack is not a stable checkpoint")
 bad=data.duplicate(true);bad.session.phase="player_impact"
 check(not Store.valid(bad),"impact hold is not a stable checkpoint")
 if not await preload("res://tests/audio_teardown.gd").release(scene,self):failures+=1
 print("BANKED_CHECKPOINT checks=",checks," failures=",failures);quit(1 if failures else 0)

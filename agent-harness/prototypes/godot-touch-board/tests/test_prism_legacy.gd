extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
func _initialize():
 var path="/tmp/chroma-prism-legacy-slot/current.json"
 if not FileAccess.file_exists(path):
  printerr("Create the isolated 8cb12de legacy fixture before running this check.");quit(2);return
 var original=FileAccess.get_file_as_string(path)
 var envelope=JSON.parse_string(original)
 var old=bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
 var loaded=Store.new().read_file(path)
 var ok=loaded.ok
 if ok:
  var restored=loaded.data.duplicate(true)
  restored.session.erase("rain_remaining");restored.session.erase("rain_color");restored.combat.erase("shield_hp");restored.combat.erase("shield_color")
  ok=restored==old and loaded.data.session.rain_remaining==0 and loaded.data.combat.shield_hp==0 and original==FileAccess.get_file_as_string(path)
 print("ACTUAL_8cb12de_MIGRATION exact_legacy_fields_rng_preserved=",ok)
 quit(0 if ok else 1)

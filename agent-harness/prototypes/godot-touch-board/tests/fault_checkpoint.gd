extends "res://scripts/board_checkpoint.gd"
# Test-only failures. No permissions, mounts or actual disk filling changed.
var fault=""
var writes=0
func _write_temp(path:String,text:String)->int:
 writes+=1
 if fault=="readonly":return ERR_FILE_NO_PERMISSION
 if fault=="full":
  var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(text.substr(0,20));f.close()
  return ERR_FILE_CANT_WRITE
 return super._write_temp(path,text)
func _replace_file(from:String,to:String)->int:
 if fault=="rename":return ERR_CANT_CREATE
 return super._replace_file(from,to)
func read_file(path:String)->Dictionary:
 if fault=="read" and path.ends_with("current.json"):return {"ok":false,"reason":"read"}
 return super.read_file(path)

func archive()->bool:
 if fault=="archive":error="이전 저장 보관 실패";return false
 return super.archive()

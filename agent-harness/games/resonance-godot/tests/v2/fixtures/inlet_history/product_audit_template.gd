extends "res://scripts/v2/board.gd"
## Generated fixture copy changes only this extends path to current product Board.
var births: Array = []
func _spawn(item: Dictionary, restored: bool = false):
    var body = super._spawn(item,restored)
    births.append(body.snapshot())
    return body

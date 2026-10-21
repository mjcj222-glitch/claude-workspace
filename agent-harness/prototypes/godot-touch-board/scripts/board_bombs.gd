extends RefCounted
## Our prototype hypotheses, not Crash Fever size/radius values.
const NORMAL_RADIUS:=98.0
const LARGE_RADIUS:=164.0
const LARGE_BODY_RADIUS:=48.0
static func is_bomb(kind:String)->bool:return kind in ["bomb","big_bomb"]
static func radius(kind:String)->float:return LARGE_RADIUS if kind=="big_bomb" else NORMAL_RADIUS
static func prepare_supply(pending:Array,kind:String)->void:
 if pending.is_empty() or not is_bomb(kind):return
 # Replace exactly one already randomized refill body, never add a body or move
 # a survivor. Pending bodies enter through the unchanged top-inlet solver.
 pending[0].kind=kind
 pending[0].radius=LARGE_BODY_RADIUS if kind=="big_bomb" else 37.0
 pending[0].color=0 # no elemental property; neutral glyph is drawn separately

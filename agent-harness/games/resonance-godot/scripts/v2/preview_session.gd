extends RefCounted
## Stores the displayed plan. Native focus, resize and OS cancel call cancel().

var _plan: Dictionary = {}
var _pointer_id := 0
var _held := false

func begin(plan: Dictionary, pointer_id: int) -> bool:
    if _held or plan.is_empty():
        return false
    _plan = plan.duplicate(true)
    _pointer_id = pointer_id
    _held = true
    return true

func move(pointer_id: int, inside: bool) -> void:
    if pointer_id == _pointer_id and not inside:
        # Keep ownership until release, so a second finger cannot restart this
        # cancelled hold. Reentry never restores the plan.
        _plan = {}

func release(pointer_id: int, inside: bool, board_version: int, combat_version: int) -> Dictionary:
    if not _held or pointer_id != _pointer_id:
        return {}
    var consumed := _plan
    cancel()
    if consumed.is_empty() or not inside or int(consumed.board_version) != board_version or int(consumed.combat_version) != combat_version:
        return {}
    return consumed

func cancel() -> void:
    _plan = {}
    _held = false

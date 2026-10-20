extends Node
## Owns the displayed plan, physical board and the single pending refill.
signal finished(outcome: Dictionary)
signal recovery_failed(reason: String)
signal checkpoint_available
const Board = preload("res://scripts/v2/board.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
const Skills = preload("res://scripts/v2/skill_rules.gd")
const Session = preload("res://scripts/v2/preview_session.gd")
const Config = preload("res://scripts/v2/config.gd")
const View = preload("res://scenes/v2/battle_view.tscn")
var board: Node
var view: Control
var state: Dictionary = {}
var snapshot: Dictionary = {}
var phase := "IDLE"
var displayed_plan: Dictionary = {}
var session = Session.new()
var selected_skill := ""
var destination := ""
var action_count := 0
var refill_batch_count := 0
var event_log: Array = []
# Presentation-only: adopted from a new accepted settlement, never checkpoint state.
var refund_notice: Dictionary = {}
var lock_measurements: Array = []
var reduced := false
var _pointer := -999
var _hold_kind := ""
var _hold_value := ""
var _hold_rect := Rect2()
var _hold_inside := false
var _pending_refill := false
var _generated_bombs := 0
var _pending_board_version := -1
var _pending_epoch := -1
var _finished_sent := false
var _epoch := 0
var _lock_start_usec := 0
var _lock_start_frame := 0
var _lock_count := 0

func _ready() -> void:
    view = View.instantiate()
    add_child(view)
    board = Board.new()
    view.bind_board(board)
    board.settled.connect(_on_settled)
    board.settle_failed.connect(_on_settle_failed)
    get_viewport().size_changed.connect(cancel_input)

func start_battle(context: Dictionary) -> void:
    cancel_input()
    _epoch += 1
    _reset_transients()
    _pending_refill = false
    _finished_sent = false
    action_count = 0
    refill_batch_count = 0
    event_log.clear()
    lock_measurements.clear()
    state = Combat.fresh(context)
    reduced = bool(context.get("reduced",false))
    if state.is_empty():
        phase = "ERROR"
        return
    phase = "SETTLING"
    _render_state()
    board.new_board(int(context.get("seed",0)))

func export_checkpoint() -> Dictionary:
    if phase not in ["READY","FINISHED"] or _pointer != -999 or board.settling or _pending_refill:
        return {}
    return {"state":state.duplicate(true),"board":board.checkpoint(),"reduced":reduced}

func restore_checkpoint(record: Dictionary) -> void:
    cancel_input()
    _epoch += 1
    _reset_transients()
    _pending_refill = false
    phase = "RESTORING"
    var previous_revision := int(state.get("revision",0))
    state = record.state.duplicate(true)
    state.revision = maxi(previous_revision,int(state.revision)) + 1
    _generated_bombs = 0
    _pending_board_version = -1
    _pending_epoch = -1
    keyboard_id = -1
    reduced = bool(record.get("reduced",false))
    _finished_sent = state.status != "active"
    board.restore(record.board)
    snapshot = board.capture()
    _wait_for_input()

func _reset_transients() -> void:
    refund_notice = {}
    view.show_refund_notice({})
    var cutin = view.get_node("CutinLayer")
    cutin.active = false
    cutin.elapsed = 0.0
    cutin.get_node("Hero").hide()
    cutin.hide()
    view.get_node("BoardViewport").effects.reset_transients()

func _render_state() -> void:
    view.show_state(state,state.get("party",[]))
    view.show_skill_mode(selected_skill,destination)

func cancel_input() -> void:
    session.cancel()
    displayed_plan = {}
    _pointer = -999
    _hold_kind = ""
    _hold_value = ""
    _hold_inside = false
    selected_skill = ""
    destination = ""
    if phase in ["PREVIEW","TARGET"]: phase = "READY"
    if is_instance_valid(view):
        view.show_plan(snapshot,{})
        view.show_skill_mode("","")

func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_WM_GO_BACK_REQUEST]:
        cancel_input()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.canceled:
            if event.index == _pointer: cancel_input()
        elif event.pressed: _press(event.position,event.index)
        else: _release(event.position,event.index)
    elif event is InputEventScreenDrag:
        _move(event.position,event.index)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
        if event.pressed: _press(event.position,-1)
        else: _release(event.position,-1)
    elif event is InputEventMouseMotion and event.device != -1:
        _move(event.position,-1)
    elif event is InputEventKey and not event.echo:
        _keyboard(event)

func _board_id(point: Vector2) -> int:
    var viewport = view.get_node("BoardViewport")
    if not viewport.contains_logical(point): return -1
    return board.piece_at(viewport.logical_to_board(point))

func _hit_ui(point: Vector2) -> Dictionary:
    for portrait in view.get_node("Party").get_children():
        if portrait.visible and portrait.get_global_rect().has_point(point):
            return {"kind":"portrait","value":portrait.name.to_lower(),"rect":portrait.get_global_rect()}
    var choices = view.get_node("Bars/Destinations")
    if choices.visible:
        for choice in choices.get_children():
            if choice.get_global_rect().has_point(point):
                return {"kind":"destination","value":choice.name.to_lower(),"rect":choice.get_global_rect()}
    return {}

func _press(point: Vector2, pointer: int) -> void:
    if _pointer != -999 or phase not in ["READY","TARGET"] or board.settling: return
    var ui := _hit_ui(point)
    if not ui.is_empty():
        if ui.kind == "portrait" and not Skills._available(state,ui.value): return
        _pointer = pointer
        _hold_kind = ui.kind
        _hold_value = ui.value
        _hold_rect = ui.rect
        _hold_inside = true
        if ui.kind == "portrait" and ui.value == "bomber":
            _show_preview(Skills.preview(snapshot,state,"bomber"),pointer)
        return
    var id := _board_id(point)
    if id < 0: return
    var plan: Dictionary
    if selected_skill.is_empty(): plan = Combat.preview(snapshot,state,id)
    else: plan = Skills.preview(snapshot,state,selected_skill,id,destination)
    if plan.is_empty(): return
    _pointer = pointer
    _hold_kind = "board"
    _hold_inside = true
    _show_preview(plan,pointer)

func _show_preview(plan: Dictionary, pointer: int) -> void:
    if not session.begin(plan,pointer): return
    displayed_plan = plan.duplicate(true)
    phase = "PREVIEW"
    if plan.has("actor_id"): view.show_skill_plan(snapshot,plan,state)
    else: view.show_plan(snapshot,plan)

func _move(point: Vector2, pointer: int) -> void:
    if pointer != _pointer: return
    var inside: bool = view.get_node("BoardViewport").contains_logical(point) if _hold_kind == "board" else _hold_rect.has_point(point)
    if not inside:
        _hold_inside = false
        session.move(pointer,false)
        displayed_plan = {}
        view.show_plan(snapshot,{})

func _release(point: Vector2, pointer: int) -> void:
    if pointer != _pointer: return
    _move(point,pointer)
    var consumed := session.release(pointer,_hold_inside,int(board.version),int(state.revision))
    if not consumed.is_empty():
        if commit_preview(consumed): return
    elif _hold_inside and _hold_kind == "portrait" and _hold_value != "bomber":
        selected_skill = _hold_value
        destination = ""
        _pointer = -999
        _hold_kind = ""
        phase = "TARGET"
        _render_state()
        return
    elif _hold_inside and _hold_kind == "destination":
        destination = _hold_value
        _pointer = -999
        _hold_kind = ""
        phase = "TARGET"
        _render_state()
        return
    cancel_input()

func commit_preview(plan: Dictionary) -> bool:
    if phase != "PREVIEW" or plan.is_empty() or plan != displayed_plan or board.settling \
        or int(plan.board_version) != int(board.version) or int(plan.combat_version) != int(state.revision):
        return false
    var release_usec := Time.get_ticks_usec()
    var release_frame := Engine.get_physics_frames()
    # Lock synchronously before any timer, board operation or signal can reenter.
    var result: Dictionary = Skills.apply(state,plan) if plan.has("actor_id") else Combat.apply_action(state,plan)
    if not result.ok: return false
    phase = "RESOLVING"
    state = result.state
    refund_notice = {}
    view.show_refund_notice({})
    event_log.append_array(result.events)
    session.cancel()
    displayed_plan = {}
    _pointer = -999
    _hold_kind = ""
    selected_skill = ""
    destination = ""
    _render_state()
    if plan.has("actor_id"):
        snapshot = board.apply_types(plan.changes)
        view.show_plan(snapshot,{})
        if plan.actor_id == "hero":
            phase = "CUTIN"
            view.get_node("CutinLayer").play(reduced)
            _finish_cutin(_epoch)
        else:
            _wait_for_input()
    else:
        action_count += 1
        _lock_start_usec = release_usec
        _lock_start_frame = release_frame
        _lock_count = plan.removed_ids.size()
        _clear_and_refill(plan.duplicate(true),_epoch)
    return true

func _finish_cutin(epoch: int) -> void:
    # The cutin owns its exact0.7s display; no refill callback is involved.
    while view.get_node("CutinLayer").active:
        await get_tree().process_frame
        if epoch != _epoch: return
    _wait_for_input()

func _clear_and_refill(plan: Dictionary, epoch: int) -> void:
    var effects = view.get_node("BoardViewport").effects
    effects.play_compression(snapshot,plan,reduced)
    if not reduced:
        await get_tree().create_timer(0.12).timeout
        if epoch != _epoch: return
    effects.show_selection(snapshot,{})
    effects.play_blast(plan.blast_circles,reduced)
    var decorated := Skills.decorate_refill(board.make_refill(plan.removed_ids.size()),state,plan)
    refill_batch_count += 1
    _generated_bombs = int(decorated.generated_bombs)
    _pending_refill = true
    _pending_board_version = int(board.version)+1
    _pending_epoch = _epoch
    phase = "SETTLING"
    board.apply_clear(plan.removed_ids,decorated.batch)

func _on_settled(value: Dictionary) -> void:
    if phase in ["RESTORING","RECOVERING","ERROR"]: return
    # A stale/foreign signal is not proof that this owner's committed board is done.
    if board.settling or value != board.capture(): return
    if _pending_refill and (phase != "SETTLING" or _pending_epoch != _epoch or int(value.version) != _pending_board_version): return
    snapshot = value.duplicate(true)
    if _pending_refill:
        _pending_refill = false
        var result := Combat.finish_refill(state,_generated_bombs)
        if not result.ok:
            _on_settle_failed("정산 상태가 일치하지 않아요.")
            return
        state = result.state
        event_log.append_array(result.events)
        for event in result.events:
            if event.type == "energy_refunded":
                refund_notice = event.duplicate(true)
                view.show_refund_notice(refund_notice)
        lock_measurements.append({"removed_count":_lock_count,"start_frame":_lock_start_frame,
            "end_frame":Engine.get_physics_frames(),"simulation_seconds":float(Engine.get_physics_frames()-_lock_start_frame)/Engine.physics_ticks_per_second,
            "wall_seconds":float(Time.get_ticks_usec()-_lock_start_usec)/1000000.0,
            "physical_seconds":board.elapsed,"timed_out":false})
    elif phase != "SETTLING": return
    _wait_for_input()

func _wait_for_input() -> void:
    if state.status == "active":
        # Acquire ownership before checking even a synchronous permutation.
        cancel_input()
        phase = "RECOVERING"
        _epoch += 1
        var epoch := _epoch
        view.get_node("PreviewLine").text = "막힌 판을 확인하고 복구하고 있어요."
        var result: Dictionary = await board.recover_if_blocked()
        if epoch != _epoch or phase != "RECOVERING" or is_queued_for_deletion() or not is_inside_tree(): return
        if result.status == "error":
            _on_settle_failed("판을 복구하지 못했어요. 마지막 정상 지점을 재개해 주세요.")
            return
        snapshot = result.snapshot.duplicate(true)
        phase = "READY"
        _render_state()
        view.show_plan(snapshot,{})
        checkpoint_available.emit()
    else:
        phase = "FINISHED"
        _render_state()
    if phase == "FINISHED" and not _finished_sent:
        _finished_sent = true
        finished.emit({"status":state.status,"hp":state.hp,"energy":state.energy,"enemy_id":state.enemy_id})

func _on_settle_failed(reason: String) -> void:
    _epoch += 1
    if _pending_refill:
        lock_measurements.append({"removed_count":_lock_count,"physical_seconds":board.elapsed,"timed_out":true,
            "wall_seconds":float(Time.get_ticks_usec()-_lock_start_usec)/1000000.0})
    _pending_refill = false
    cancel_input()
    phase = "ERROR"
    view.get_node("PreviewLine").text = reason
    recovery_failed.emit(reason)

var keyboard_id := -1
func _keyboard(event: InputEventKey) -> void:
    if event.keycode == KEY_ESCAPE and event.pressed:
        cancel_input()
        return
    if event.keycode in [KEY_1,KEY_2,KEY_3]:
        var actors := ["hero","bomber","gardener"]
        var actor: String = actors[int(event.keycode)-KEY_1]
        var portrait = view.get_node_or_null("Party/"+actor.capitalize())
        if portrait != null:
            if event.pressed: _press(portrait.get_global_rect().get_center(),-2)
            else: _release(portrait.get_global_rect().get_center(),-2)
        return
    if event.pressed and event.keycode in [KEY_R,KEY_Y,KEY_B] and selected_skill == "hero" and _pointer == -999:
        destination = {KEY_R:"red",KEY_Y:"yellow",KEY_B:"blue"}[event.keycode]
        _render_state()
        return
    if event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN] and _pointer == -999 and phase in ["READY","TARGET"]:
        var current = board.by_id(keyboard_id)
        if current == null:
            keyboard_id = int(snapshot.pieces[0].id)
        else:
            var direction: Vector2 = {KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}[event.keycode]
            var best := INF
            for piece in board.pieces:
                var offset: Vector2 = piece.position-current.position
                var forward := offset.dot(direction)
                if forward > 0:
                    var score := offset.length_squared()/forward
                    if score < best:
                        best = score
                        keyboard_id = piece.identity
        view.show_keyboard_focus(snapshot,keyboard_id)
    if event.keycode in [KEY_ENTER,KEY_SPACE]:
        var tile = board.by_id(keyboard_id)
        if tile == null: return
        var point: Vector2 = view.get_node("BoardViewport").board_to_logical(tile.position)
        if event.pressed: _press(point,-2)
        else: _release(point,-2)

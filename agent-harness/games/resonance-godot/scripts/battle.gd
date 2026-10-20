extends Node2D

const Board = preload("res://scripts/board.gd")
const Geometry = preload("res://scripts/piece_geometry.gd")
const Rules = preload("res://scripts/combat_rules.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Effects = preload("res://scripts/effects.gd")
const HealthBar = preload("res://scripts/health_bar.gd")
const SAVE_PATH := "user://resonance_godot_v1.json"
const SKILL_NAMES := ["프리즘 링크", "연쇄 점화", "생명의 온실"]
const SKILL_HINTS := ["파랑 → 불꽃 · 다음 공격 강화", "소형 폭탄 2개 · 폭발 강화", "회복 6개 · 다음 반격 −18"]
var board: ResonanceBoard
var effects: ResonanceEffects
var state := Rules.fresh()
var snapshot: Array = []
var edges := {}
var phase := "SETTLING"
var preview_plan := {}
var press_id := -1
var press_pointer := -2
var press_position := Vector2.ZERO
var keyboard_id := -1
var action_log: Array = []
var labels := {}
var skills: Array = []
var boost_button: Button
var reduce_button: CheckButton
var restart_button: Button
var ending: Panel
var enemy_sprite: Sprite2D
var portrait_buttons: Array = []
var font: Font
var no_save := false
var seed_value := 20261020
var reduced := false
var enemy_bar: Control
var health_bar: Control
var skill_counter := 0

func _ready() -> void:
    no_save = OS.get_cmdline_user_args().has("--no-save")
    font = load("res://assets/NotoSansCJK-Regular.ttc")
    build_screen()
    board = Board.new()
    board.position = Vector2(60,580)
    add_child(board)
    board.settled.connect(on_settled)
    board.settle_failed.connect(on_settle_failed)
    effects = Effects.new()
    effects.z_index = 15
    add_child(effects)
    if not load_game(): start_new(seed_value)

func panel(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
    var node := Panel.new()
    node.position = rect.position
    node.size = rect.size
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1 if border.a else 0)
    style.set_corner_radius_all(18)
    node.add_theme_stylebox_override("panel",style)
    add_child(node)
    return node

func label_node(key: String, text: String, rect: Rect2, size_value: int, color: Color = Color("edf5e8")) -> Label:
    var label := Label.new()
    label.text = text
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_override("font",font)
    label.add_theme_font_size_override("font_size",size_value)
    label.add_theme_color_override("font_color",color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    labels[key] = label
    return label

func button_node(text: String, rect: Rect2) -> Button:
    var button := Button.new()
    button.text = text
    button.position = rect.position
    button.size = rect.size
    button.add_theme_font_override("font",font)
    button.add_theme_font_size_override("font_size",22)
    for pair in [["normal",Color("284d58")],["hover",Color("386570")],["pressed",Color("517570")],["disabled",Color("253b43")]]:
        var style := StyleBoxFlat.new()
        style.bg_color = pair[1]
        style.border_color = Color("7d9c8e") if pair[0] != "disabled" else Color("465b5e")
        style.set_border_width_all(1)
        style.set_corner_radius_all(14)
        button.add_theme_stylebox_override(pair[0],style)
    button.add_theme_color_override("font_color",Color("f4efdb"))
    button.add_theme_color_override("font_disabled_color",Color("91a6a9"))
    add_child(button)
    return button

func make_bar(rect: Rect2, tint: Color, max_value: float) -> Control:
    var bar := HealthBar.new()
    bar.position = rect.position
    bar.size = rect.size
    bar.max_value = max_value
    bar.tint = tint
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bar)
    return bar

func build_screen() -> void:
    var fill := ColorRect.new()
    fill.color = Color("102a35")
    fill.size = Vector2(720,1280)
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fill)
    var backdrop := TextureRect.new()
    backdrop.texture = load("res://assets/background.webp")
    backdrop.position = Vector2.ZERO
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.size = Vector2(720,390)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    panel(Rect2(0,0,720,68),Color("172e35dd"))
    label_node("title","새싹 회랑",Rect2(26,14,390,46),28)
    label_node("turn","1턴",Rect2(602,18,100,40),23)
    enemy_sprite = Sprite2D.new()
    var sheet: Texture2D = load("res://assets/enemy-sheet.png")
    var atlas := AtlasTexture.new()
    atlas.atlas = sheet
    atlas.region = Rect2(0,0,sheet.get_width()/3.0,sheet.get_height())
    enemy_sprite.texture = atlas
    enemy_sprite.position = Vector2(380,214)
    enemy_sprite.scale = Vector2.ONE*(290.0/sheet.get_height())
    add_child(enemy_sprite)
    panel(Rect2(18,322,684,62),Color("183a44ed"))
    label_node("enemy","온실의 수호자  620 / 620",Rect2(34,328,420,30),22)
    label_node("threat","다음 반격 14",Rect2(492,328,194,30),22,Color("ffd5a6"))
    enemy_bar = make_bar(Rect2(34,366,652,6),Color("eaa888"),620)
    for i in range(3):
        var button := button_node("",Rect2(18+i*232,396,220,106))
        button.pressed.connect(use_skill.bind(i))
        button.tooltip_text = SKILL_HINTS[i]+". 탭 소모 없음."
        skills.append(button)
    panel(Rect2(18,510,684,670),Color("143644"),Color("4c7376"))
    label_node("health","체력 180 / 180",Rect2(32,514,350,30),22)
    label_node("taps","남은 선택 3",Rect2(510,514,180,30),22,Color("f6e6b6"))
    health_bar = make_bar(Rect2(34,547,652,4),Color("87d8bb"),180)
    label_node("pending","이번 턴 적립  0 피해 · 0 회복",Rect2(40,564,640,34),19,Color("b1cbc7"))
    label_node("hint","기물이 내려오고 있어요",Rect2(32,1188,656,45),22)
    boost_button = button_node("과충전  0 / 55",Rect2(22,1234,280,40))
    boost_button.add_theme_font_size_override("font_size",19)
    boost_button.pressed.connect(use_boost)
    reduce_button = CheckButton.new()
    reduce_button.text = "움직임 줄이기"
    reduce_button.position = Vector2(316,1234)
    reduce_button.size = Vector2(230,40)
    reduce_button.add_theme_font_override("font",font)
    reduce_button.add_theme_font_size_override("font_size",18)
    reduce_button.toggled.connect(set_reduced)
    add_child(reduce_button)
    restart_button = button_node("다시 시작",Rect2(558,1234,140,40))
    restart_button.add_theme_font_size_override("font_size",19)
    restart_button.pressed.connect(func(): start_new(seed_value))
    ending = panel(Rect2(86,520,548,290),Color("edf3e9"),Color("bdccb6"))
    ending.z_index = 25
    ending.mouse_filter = Control.MOUSE_FILTER_STOP
    var end_title := Label.new()
    end_title.name = "Title"
    end_title.position = Vector2(30,32)
    end_title.size = Vector2(488,70)
    end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_title.add_theme_font_override("font",font)
    end_title.add_theme_font_size_override("font_size",34)
    end_title.add_theme_color_override("font_color",Color("284b50"))
    ending.add_child(end_title)
    var end_desc := Label.new()
    end_desc.name = "Description"
    end_desc.position = Vector2(30,110)
    end_desc.size = Vector2(488,130)
    end_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_desc.add_theme_font_override("font",font)
    end_desc.add_theme_font_size_override("font_size",23)
    end_desc.add_theme_color_override("font_color",Color("456363"))
    ending.add_child(end_desc)
    ending.hide()

func start_new(value: int) -> void:
    seed_value = value
    state = Rules.fresh()
    phase = "SETTLING"
    snapshot.clear()
    preview_plan.clear()
    press_id = -1
    action_log.clear()
    ending.hide()
    board.new_board(value)
    refresh_ui()

func on_settled(value: Array) -> void:
    snapshot = value
    edges = Geometry.graph(snapshot)
    phase = "READY" if state.status == "playing" else "ENDED"
    board.marks(state.echo)
    if not snapshot.is_empty(): keyboard_id = int(snapshot[0].id)
    refresh_ui()
    save_game()
    if phase == "ENDED":
        ending.get_node("Title").text = "온실에 빛이 돌아왔어요" if state.status == "won" else "잠시 숨을 고를까요"
        ending.get_node("Description").text = "%d턴의 선택을 마쳤어요.\n아래 ‘다시 시작’으로 재도전할 수 있어요." % state.turn
        ending.show()

func on_settle_failed(reason: String) -> void:
    phase = "ERROR"
    labels.hint.text = reason
    refresh_ui(false)
    action_log.append({"event":"settle_failed","reason":reason})

func refresh_ui(update_hint: bool = true) -> void:
    labels.turn.text = "%d턴" % state.turn
    labels.enemy.text = "온실의 수호자  %d / 620" % state.enemy_hp
    labels.threat.text = "다음 반격 %d" % (14 if int(state.turn)%2 else 20)
    labels.health.text = "체력 %d / 180%s" % [state.hp," · 보호 18" if state.shield else ""]
    labels.taps.text = "남은 선택 %d" % state.taps
    labels.pending.text = "이번 턴 적립  %d 피해 · %d 회복%s" % [state.pending_damage,state.pending_heal," · 2배" if state.boost else ""]
    enemy_bar.value = state.enemy_hp
    health_bar.value = state.hp
    for i in range(3):
        var ready: bool = phase == "READY" and Rules.can_skill(snapshot,state,i)
        skills[i].disabled = not ready
        var status := "사용 가능 · 탭 유지"
        if phase == "SETTLING": status = "낙하 중"
        elif phase == "RESOLVING": status = "정산 중"
        elif phase != "READY": status = "전투 종료" if phase == "ENDED" else "대기"
        elif state.turn < state.ready[i]: status = "%d턴 후" % (state.ready[i]-state.turn)
        elif not Rules.can_skill(snapshot,state,i): status = "대상 없음"
        skills[i].text = SKILL_NAMES[i]+"\n"+status
        skills[i].accessibility_description = SKILL_HINTS[i]+". "+status
    boost_button.disabled = phase != "READY" or state.gauge < 55 or state.taps != 3 or state.boost
    boost_button.text = "과충전 발동 중" if state.boost else "과충전  %d / 55" % state.gauge
    restart_button.disabled = phase == "RESOLVING"
    if update_hint:
        if phase == "SETTLING": labels.hint.text = "기물이 내려오는 중 · 정착하면 선택할 수 있어요"
        elif phase == "READY": labels.hint.text = "눌러서 예고 · 떼면 확정  |  8개 연결 → 대형 폭탄"
        elif phase == "RESOLVING": labels.hint.text = "연결을 정산하고 있어요"
        elif phase == "ENDED": labels.hint.text = "전투 종료 · 다시 시작할 수 있어요"

func show_preview(id_value: int) -> void:
    if phase != "READY": return
    preview_plan = Rules.preview(snapshot,edges,id_value,state)
    if preview_plan.is_empty(): return
    board.select(preview_plan.removed)
    var reward := ""
    if not preview_plan.special.is_empty(): reward = " → 대형 폭탄" if preview_plan.special.kind == "mega" else " → 차지"
    labels.hint.text = "연결 %d%s · 피해 +%d / 회복 +%d" % [preview_plan.initial.size(),reward,preview_plan.damage,preview_plan.healing]

func _unhandled_input(event: InputEvent) -> void:
    if phase != "READY": return
    if event is InputEventScreenTouch:
        if event.canceled: cancel_preview()
        elif event.pressed: pointer_down(event.position,event.index)
        else: pointer_up(event.position,event.index)
    elif event is InputEventScreenDrag:
        if event.index == press_pointer and event.position.distance_to(press_position)>18: cancel_preview()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed: pointer_down(event.position,-1)
        else: pointer_up(event.position,-1)
    elif event is InputEventMouseMotion and press_pointer == -1 and press_id != -1:
        if event.position.distance_to(press_position)>18: cancel_preview()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE: cancel_preview()
        elif event.keycode in [KEY_ENTER,KEY_SPACE]: commit(keyboard_id)
        elif event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
            var direction: Vector2 = {KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN,KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT}[event.keycode]
            var current := board.by_id(keyboard_id)
            if not current: return
            var score := INF
            for piece in board.pieces:
                var delta: Vector2 = piece.position-current.position
                if delta.dot(direction)<=1: continue
                var next: float = delta.length()+absf(delta.cross(direction))*1.8
                if next<score:
                    score = next
                    keyboard_id = piece.identity
            show_preview(keyboard_id)

func pointer_down(location: Vector2, pointer: int) -> void:
    if press_id != -1: return
    var identity := board.piece_at(location)
    if identity == -1: return
    press_id = identity
    press_pointer = pointer
    press_position = location
    keyboard_id = identity
    show_preview(identity)

func pointer_up(location: Vector2, pointer: int) -> void:
    if pointer != press_pointer: return
    var identity := press_id
    press_id = -1
    press_pointer = -2
    if identity != -1 and location.distance_to(press_position)<18 and board.piece_at(location)==identity: commit(identity)
    else: cancel_preview()

func cancel_preview() -> void:
    press_id = -1
    press_pointer = -2
    preview_plan.clear()
    board.select([])
    refresh_ui()

func commit(id_value: int) -> void:
    if phase != "READY": return
    var plan := Rules.preview(snapshot,edges,id_value,state)
    if plan.is_empty(): return
    phase = "RESOLVING"
    press_id = -1
    press_pointer = -2
    refresh_ui()
    board.select(plan.removed)
    var predicted: Array = plan.removed.duplicate()
    var center := Vector2.ZERO
    var pause_time := 0.012 if plan.removed.size()>12 else 0.018
    for identity in plan.removed:
        var piece := board.by_id(identity)
        if not piece: continue
        center = piece.global_position
        effects.burst(center,Geometry.COLORS[piece.color_index],2 if piece.kind=="mega" else 1)
        if not reduced:
            var tween := create_tween()
            tween.tween_property(piece,"modulate:a",0.15,0.10)
            await get_tree().create_timer(pause_time).timeout
    if not reduced: await get_tree().create_timer(0.12).timeout
    var result := Rules.apply(state,plan)
    action_log.append({"event":"tap","id":id_value,"preview_ids":predicted,"removed_ids":plan.removed.duplicate(),"chain":plan.initial.size(),"damage":plan.damage,"healing":plan.healing,"mega":not plan.special.is_empty() and plan.special.kind=="mega","turn":state.turn,"hp":state.hp,"result":state.status})
    if result.enemy_damage:
        effects.hit(enemy_sprite.position,Color("ffdc8d"))
        if not reduced:
            var tween := create_tween()
            tween.tween_property(enemy_sprite,"modulate",Color(1.5,1.25,1.15),0.08)
            tween.tween_property(enemy_sprite,"modulate",Color.WHITE,0.12)
    if result.attack: effects.hit(Vector2(220,530),Color("ef8c92"))
    phase = "SETTLING"
    board.remove_and_refill(plan.removed,plan.special)
    preview_plan.clear()
    refresh_ui()

func use_skill(skill: int) -> void:
    if phase != "READY" or not Rules.can_skill(snapshot,state,skill): return
    phase = "RESOLVING"
    press_id = -1
    board.select([])
    var ids := Rules.candidates(snapshot,skill)
    var old_taps: int = state.taps
    for identity in ids:
        var piece := board.by_id(identity)
        if skill == 1:
            piece.kind = "bomb"
            piece.queue_redraw()
        else:
            piece.recolor(0 if skill == 0 else 3)
            if skill == 2: state.echo.erase(identity)
        effects.burst(piece.global_position,Geometry.COLORS[0 if skill==0 else 2 if skill==1 else 3])
    Rules.apply_skill(state,skill)
    skill_counter += 1
    action_log.append({"event":"skill","skill":skill,"ids":ids,"taps_before":old_taps,"taps_after":state.taps,"turn":state.turn})
    if skill == 1:
        snapshot = board.capture()
        edges = Geometry.graph(snapshot)
        phase = "READY"
        save_game()
    else:
        phase = "SETTLING"
        board.start_settling()
    refresh_ui()

func use_boost() -> void:
    if phase != "READY" or state.gauge<55 or state.taps!=3 or state.boost: return
    state.gauge = 0
    state.boost = true
    refresh_ui()
    save_game()

func set_reduced(value: bool) -> void:
    reduced = value
    board.reduce_motion = value
    effects.reduced = value
    if value:
        effects.rings.clear()
        effects.pulses.clear()
        for particle in effects.get_children(): particle.queue_free()
    for piece in board.pieces: piece.visible = not value or not board.settling

func save_game() -> void:
    if no_save or phase not in ["READY","ENDED"]: return
    var data := {"version":1,"engine":"4.6.3","state":state,"snapshot":snapshot,"next_id":board.next_id,"rng_state":str(board.rng.state),"seed":seed_value,"reduced":reduced}
    var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file: file.store_string(JSON.stringify(data))

func load_game() -> bool:
    if no_save or not FileAccess.file_exists(SAVE_PATH): return false
    var data := SaveStore.decode(FileAccess.get_file_as_string(SAVE_PATH))
    if data.is_empty(): return false
    state = data.state
    seed_value = int(data.get("seed",20261020))
    for key in ["hp","enemy_hp","turn","taps","pending_damage","pending_heal","gauge","shield"]: state[key] = int(state[key])
    for i in range(3): state.ready[i] = int(state.ready[i])
    for i in range(state.echo.size()): state.echo[i] = int(state.echo[i])
    reduced = bool(data.get("reduced",false))
    reduce_button.set_pressed_no_signal(reduced)
    board.reduce_motion = reduced
    effects.reduced = reduced
    board.restore(data.snapshot,int(data.next_id),int(data.rng_state))
    return true

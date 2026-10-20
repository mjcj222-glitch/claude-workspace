extends Control
## Presentation consumes snapshots/plans; it never calculates combat rewards.
signal skill_requested(character: String)
const Config = preload("res://scripts/v2/config.gd")
const FONT = preload("res://assets/NotoSansCJK-Regular.ttc")
var labels := {}
var enemy_hp_bar: ProgressBar
var hp_bar: ProgressBar
var energy_bar: ProgressBar
var party_keys: Array = []
var board: Node
var destination_row: HBoxContainer
var refund_notice: Dictionary = {}
func _ready() -> void:
    size = Vector2(720,1280)
    theme = Theme.new()
    theme.default_font = FONT
    theme.default_font_size = 20
    _stage()
    get_node("Party").position = Vector2(36,330)
    get_node("Party").add_theme_constant_override("separation",12)
    labels.hp = _label(get_node("Bars"),"",Rect2(38,420,300,28),19)
    labels.energy = _label(get_node("Bars"),"",Rect2(448,420,240,28),19)
    hp_bar = _bar(get_node("Bars"),Rect2(38,453,390,7),Color("83d8ad"),Config.MAX_HP)
    energy_bar = _bar(get_node("Bars"),Rect2(450,453,232,7),Color("e7c47b"),Config.MAX_ENERGY)
    var preview := get_node("PreviewLine") as Label
    preview.position = Vector2(38,480)
    preview.size = Vector2(644,58)
    preview.add_theme_font_size_override("font_size",21)
    preview.add_theme_color_override("font_color",Color("d8e8e6"))
    preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.text = "같은 문양 3개 이상을 눌러 확인"
    get_node("BoardViewport").position = Vector2(40,550)
    get_node("BoardViewport").size = Vector2(640,640)
    labels.footer = _label(get_node("Bars"),"잔향 회로   /   첫 번째 관문",Rect2(40,1210,640,32),18,Color("8c929b"))
    destination_row = HBoxContainer.new()
    destination_row.name = "Destinations"
    destination_row.position = Vector2(270,332)
    destination_row.add_theme_constant_override("separation",8)
    get_node("Bars").add_child(destination_row)
    for color in Config.COLOR_TYPES:
        var button := Button.new()
        button.name = str(color).capitalize()
        button.text = {"red":"● 빨강","yellow":"◆ 노랑","blue":"≈ 파랑"}[color]
        button.custom_minimum_size = Vector2(125,68)
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        destination_row.add_child(button)
    destination_row.hide()
    queue_redraw()
func _stage() -> void:
    var stage := get_node("EnemyStage")
    stage.size = Vector2(720,320)
    stage.clip_contents = true
    var backdrop := TextureRect.new()
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.texture = preload("res://assets/background.webp")
    backdrop.position = Vector2(24,24)
    backdrop.size = Vector2(672,280)
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.modulate = Color(0.6,0.64,0.64,0.4)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(backdrop)
    var enemy := Sprite2D.new()
    enemy.name = "Enemy"
    var atlas := AtlasTexture.new()
    atlas.atlas = preload("res://assets/enemy-sheet.png")
    atlas.region = Rect2(0,0,682,682)
    enemy.texture = atlas
    enemy.position = Vector2(360,158)
    enemy.scale = Vector2.ONE * 0.34
    stage.add_child(enemy)
    labels.title = _label(stage,"01  /  온실의 문턱",Rect2(42,34,400,30),18,Color("b5b9bf"))
    labels.enemy = _label(stage,"",Rect2(40,264,380,32),20)
    labels.intent = _label(stage,"",Rect2(422,264,260,32),20,Color("f0b995"))
    enemy_hp_bar = _bar(stage,Rect2(40,307,640,5),Color("d58d82"),72)
func _label(parent: Node, value: String, rect: Rect2, font_size: int, color: Color = Color("eeeae0")) -> Label:
    var label := Label.new()
    label.text = value
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label
func _bar(parent: Node, rect: Rect2, color: Color, maximum: int) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = rect.position
    bar.max_value = maximum
    bar.show_percentage = false
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    var background := StyleBoxFlat.new()
    background.bg_color = Color("32353e")
    bar.add_theme_stylebox_override("fill",fill)
    bar.add_theme_stylebox_override("background",background)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(bar)
    bar.size = rect.size
    return bar
func bind_board(value: Node) -> void:
    board = value
    get_node("BoardViewport").bind_board(value)
func show_state(state: Dictionary, party: Array) -> void:
    if party_keys != party:
        party_keys = party.duplicate()
        for child in get_node("Party").get_children(): child.free()
        for character in party:
            _portrait(str(character))
    for portrait in get_node("Party").get_children():
        var key := str(portrait.name).to_lower()
        portrait.disabled = state.get("team_skill_used",false) or int(state.get("energy",0)) < int(Config.SKILL_COSTS[key]) or state.get("status","") != "active"
    var enemy_id := str(state.get("enemy_id","hall1"))
    var titles := {"hall1":"01  /  첫 회랑", "hall2_safe":"02  /  안전 회랑", "hall2_risk":"02  /  위험 회랑", "gate":"03  /  관문 수호자"}
    labels.title.text = titles[enemy_id]
    labels.footer.text = refund_text(refund_notice) if not refund_notice.is_empty() else "잔향 회로   /   " + titles[enemy_id] + "   ·   %d턴" % state.get("turn",1)
    var enemy = get_node("EnemyStage/Enemy")
    enemy.texture.region = Rect2({"hall1":0,"hall2_safe":1,"hall2_risk":1,"gate":2}[enemy_id]*724,0,724,724)
    var maximum: int = Config.ENEMIES[enemy_id].hp
    labels.enemy.text = "수호자   %d / %d" % [state.get("enemy_hp",maximum),maximum]
    enemy_hp_bar.max_value = maximum
    enemy_hp_bar.value = state.get("enemy_hp",maximum)
    labels.intent.text = "%s%d(+%d) · %d회" % ["강공격" if state.get("intent",{}).get("kind","") == "strong" else "공격",state.get("intent",{}).get("total_damage",0),state.get("intent",{}).get("pressure",0),state.get("actions_left",3)]
    labels.hp.text = "HP %d/%d  ·  회복 +%d / 피해 +%d" % [state.get("hp",72),Config.MAX_HP,state.get("pending_heal",0),state.get("pending_damage",0)]
    labels.energy.text = "기력   %d / %d" % [state.get("energy",4),Config.MAX_ENERGY]
    hp_bar.value = state.get("hp",72)
    energy_bar.value = state.get("energy",4)
func _portrait(character: String) -> void:
    var button := Button.new()
    button.name = character.capitalize()
    button.custom_minimum_size = Vector2(198,72)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("292d36")
    style.border_color = Color("7faaa4")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    button.add_theme_stylebox_override("normal",style)
    button.add_theme_stylebox_override("hover",style)
    button.add_theme_stylebox_override("pressed",style)
    button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    get_node("Party").add_child(button)
    var portrait := TextureRect.new()
    var atlas := AtlasTexture.new()
    atlas.atlas = preload("res://assets/portraits.webp")
    var index := ["hero","bomber","gardener"].find(character)
    atlas.region = Rect2(maxi(index,0)*682,0,682,682)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.texture = atlas
    portrait.position = Vector2(5,5)
    portrait.size = Vector2(62,62)
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(portrait)
    var names := {"hero":"변환","bomber":"폭약사","gardener":"정원지기"}
    _label(button,str(names.get(character,character)),Rect2(79,6,114,28),20)
    _label(button,"기력 %d" % int(Config.SKILL_COSTS.get(character,0)),Rect2(79,37,114,25),16,Color("b1b9c2"))
func show_selection(snapshot: Dictionary, plan: Dictionary) -> void:
    get_node("BoardViewport").effects.show_selection(snapshot,plan)
    var preview := get_node("PreviewLine") as Label
    if plan.is_empty():
        preview.text = "같은 문양 3개 이상을 눌러 확인"
    else:
        var direct := "폭탄 1" if plan.get("mode","") == "solo_bomb" else "직접 %d" % plan.get("direct_ids",[]).size()
        preview.text = "%s   +   폭발 %d   =   %d개" % [direct,plan.get("extra_ids",[]).size(),plan.get("removed_ids",[]).size()]
func show_plan(snapshot: Dictionary, plan: Dictionary) -> void:
    show_selection(snapshot,plan)
    if plan.is_empty(): return
    var direct := "폭탄 1" if plan.get("mode","") == "solo_bomb" else "직접%d" % plan.get("direct_ids",[]).size()
    var suffix := " · 약화" if plan.get("weaken_intent",false) else ""
    var tier := int(plan.get("refill_tier",0))
    if Config.BOMB_RADIUS_MULTIPLIERS.has(tier):
        suffix += " · 다음 파랑 " + {1:"소형",2:"중형",3:"대형"}[tier]
    get_node("PreviewLine").text = "%s + 추가%d  ·  피해%d+%d=%d\n회복 누적+%d / 실효+%d  ·  기력+%d%s" % [direct,plan.get("extra_ids",[]).size(),plan.get("direct_damage",0),plan.get("blast_damage",0),int(plan.get("direct_damage",0))+int(plan.get("blast_damage",0)),plan.get("healing_raw",0),plan.get("healing_effective",0),plan.get("energy_effective",0),suffix]
    get_node("PreviewLine").add_theme_font_size_override("font_size",17)

static func refund_text(event: Dictionary) -> String:
    if event.is_empty(): return ""
    return "폭약사 환불 · 기력 +%d (지불%d · 상한 적용)" % [event.energy_effective,event.paid_cost]

func show_refund_notice(event: Dictionary) -> void:
    refund_notice = event.duplicate(true)
    labels.footer.text = refund_text(refund_notice)

func _draw() -> void:
    draw_rect(Rect2(0,0,720,1280),Color("14171e"))
    draw_style_box(_frame(),Rect2(34,544,652,652))
    draw_line(Vector2(38,475),Vector2(682,475),Color("303640"),1)
func _frame() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("090b0f")
    style.border_color = Color("4a515d")
    style.set_border_width_all(2)
    style.set_corner_radius_all(6)
    return style

func show_skill_mode(actor: String, destination: String) -> void:
    destination_row.visible = actor == "hero"
    for portrait in get_node("Party").get_children():
        portrait.visible = actor != "hero" or portrait.name == "Hero"
        portrait.modulate = Color("ffe0a0") if portrait.name.to_lower() == actor else Color.WHITE
    if not actor.is_empty():
        get_node("PreviewLine").text = "목적색 선택 → 기물을 누른 채 대상 확인" if actor == "hero" and destination.is_empty() else "기물을 누른 채 변환 대상을 확인하고 놓으세요"
func show_skill_plan(snapshot: Dictionary, plan: Dictionary, state: Dictionary) -> void:
    var ids: Array = plan.changes.keys()
    ids.sort()
    show_selection(snapshot,{"direct_ids":ids})
    if plan.actor_id == "bomber":
        get_node("PreviewLine").text = "기력6 · 남은 리필%d회 파랑→폭탄 · 생성0개면 턴 끝 환불" % state.actions_left
    else:
        get_node("PreviewLine").text = "%d개 → %s  ·  기력%d  ·  놓아서 변환" % [ids.size(),{"red":"빨강","yellow":"노랑","blue":"파랑","heart":"하트"}[plan.destination],plan.cost]
func show_keyboard_focus(snapshot: Dictionary, id: int) -> void:
    show_selection(snapshot,{"direct_ids":[id]})

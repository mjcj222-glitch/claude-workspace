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
    preview.position = Vector2(38,487)
    preview.size = Vector2(644,40)
    preview.add_theme_font_size_override("font_size",21)
    preview.add_theme_color_override("font_color",Color("d8e8e6"))
    preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.text = "같은 문양 3개 이상을 눌러 확인"
    get_node("BoardViewport").position = Vector2(40,550)
    get_node("BoardViewport").size = Vector2(640,640)
    _label(get_node("Bars"),"잔향 회로   /   첫 번째 관문",Rect2(40,1210,640,32),18,Color("8c929b"))
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
    _label(stage,"01  /  온실의 문턱",Rect2(42,34,400,30),18,Color("b5b9bf"))
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
    var enemy_id := str(state.get("enemy_id","hall1"))
    var maximum: int = Config.ENEMIES[enemy_id].hp
    labels.enemy.text = "수호자   %d / %d" % [state.get("enemy_hp",maximum),maximum]
    enemy_hp_bar.max_value = maximum
    enemy_hp_bar.value = state.get("enemy_hp",maximum)
    labels.intent.text = "%s %d  ·  %d회 남음" % ["강공격" if state.get("intent",{}).get("kind","") == "strong" else "공격",state.get("intent",{}).get("total_damage",0),state.get("actions_left",3)]
    labels.hp.text = "HP   %d / %d" % [state.get("hp",72),Config.MAX_HP]
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
    button.pressed.connect(func(): skill_requested.emit(character))
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
        preview.text = "직접 %d   +   폭발 %d   =   %d개" % [plan.get("direct_ids",[]).size(),plan.get("extra_ids",[]).size(),plan.get("removed_ids",[]).size()]
func show_plan(snapshot: Dictionary, plan: Dictionary) -> void:
    show_selection(snapshot,plan)
    if plan.is_empty(): return
    get_node("PreviewLine").text = "피해 +%d   ·   회복 +%d   ·   기력 +%d" % [int(plan.get("direct_damage",0))+int(plan.get("blast_damage",0)),plan.get("healing_effective",0),plan.get("energy_effective",0)]
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

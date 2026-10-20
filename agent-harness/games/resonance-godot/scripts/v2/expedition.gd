extends Node
## Owns one live Battle or one progression screen. Persistence belongs to SaveStore.
const RunV2 = preload("res://scripts/v2/run_rules.gd")
const Config = preload("res://scripts/v2/config.gd")
const BattleScene = preload("res://scenes/v2/battle.tscn")
const FONT = preload("res://assets/NotoSansCJK-Regular.ttc")
@export var seed: int = 41
@export var reduced := false
var run: Dictionary = {}
var battle: Node
var choice_panel: Control
var generation := 0

func _ready() -> void:
    new_run(seed)

func new_run(seed_value: int) -> void:
    generation += 1
    seed = seed_value
    run = RunV2.fresh(seed_value)
    _show_stage()

func _retire_battle() -> void:
    if not is_instance_valid(battle):
        battle = null
        return
    battle.cancel_input()
    battle.set_process_input(false)
    battle.view.hide()
    battle.queue_free()
    battle = null

func _show_stage() -> void:
    _retire_battle()
    if is_instance_valid(choice_panel):
        choice_panel.hide()
        choice_panel.queue_free()
        choice_panel = null
    var context := RunV2.battle_context(run)
    if not context.is_empty():
        generation += 1
        context.reduced = reduced
        battle = BattleScene.instantiate()
        battle.finished.connect(_on_battle_finished.bind(battle,generation,str(run.stage)))
        add_child(battle)
        battle.start_battle(context)
    else:
        _show_choices()

func _on_battle_finished(summary: Dictionary, source: Node, owner_generation: int, owner_stage: String) -> void:
    if not is_instance_valid(source) or source != battle or owner_generation != generation \
        or run.get("stage","") != owner_stage or source.phase != "FINISHED": return
    # finished carries a summary; the current owner's adopted CombatState is authoritative.
    var current: Dictionary = source.state
    for key in ["status","hp","energy","enemy_id"]:
        if not summary.has(key) or summary[key] != current.get(key): return
    var result := RunV2.complete_battle(run,current)
    if not result.ok: return
    run = result.state
    _show_stage()

func _choose(choice: String, expected_revision: int, expected_stage: String, owner_generation: int) -> void:
    if expected_revision != int(run.revision) or expected_stage != run.stage \
        or owner_generation != generation: return
    if choice == "restart" and run.stage in ["completed","lost"]:
        new_run(int(run.seed))
        return
    var result: Dictionary
    if run.stage == "route_choice":
        result = RunV2.choose_route(run,choice)
    elif run.stage == "recruit_choice":
        result = RunV2.choose_recruit(run,choice)
    else:
        return
    if not result.ok: return
    run = result.state
    _show_stage()

func _show_choices() -> void:
    choice_panel = Control.new()
    choice_panel.name = "Progression"
    choice_panel.size = Vector2(720,1280)
    choice_panel.theme = Theme.new()
    choice_panel.theme.default_font = FONT
    choice_panel.theme.default_font_size = 23
    add_child(choice_panel)
    var background := ColorRect.new()
    background.color = Color("14171e")
    background.size = choice_panel.size
    choice_panel.add_child(background)
    var content := VBoxContainer.new()
    content.name = "Choices"
    content.position = Vector2(56,230)
    content.size.x = 608
    content.add_theme_constant_override("separation",24)
    choice_panel.add_child(content)
    var titles := {"route_choice":"첫 회랑 통과 · 경로 선택","recruit_choice":"두 번째 회랑 통과 · 함께 갈 길",
        "completed":"세 번째 관문 통과","lost":"탐험 종료"}
    _label(content,titles.get(run.stage,""),32)
    _label(content,"HP %d/%d · 기력 %d/%d · 변환 한도 %d" % [run.hp,Config.MAX_HP,run.energy,Config.MAX_ENERGY,run.hero_limit],21)
    if run.stage == "route_choice":
        _label(content,"회복을 택하거나, 위험 회랑에서 강화를 얻으세요.",20)
        _button(content,"Safe","안전 경로 · HP +%d" % Config.SAFE_ROUTE_HEAL,"safe")
        _button(content,"Risk","위험 경로 · 승리 시 변환 한도 +%d" % Config.RISK_LIMIT_BONUS,"risk")
    elif run.stage == "recruit_choice":
        _label(content,"동료 한 명을 모집하거나 주인공을 강화하세요.\n기력은 선택한 스킬 비용까지 한 번 보충됩니다.",20)
        _button(content,"Bomber","폭약사 · 다음 파랑 리필을 폭탄으로","bomber")
        _button(content,"Gardener","정원지기 · 가까운 기물을 하트로","gardener")
        _button(content,"Skip","주인공 강화 · 변환 한도 +%d (최대 %d)" % [Config.DECLINE_LIMIT_BONUS,Config.HERO_MAX_LIMIT],"skip")
    elif run.stage in ["completed","lost"]:
        _label(content,"이번 세 전투 검증판을 완료했습니다." if run.stage == "completed" else "새 탐험에서 다시 도전하세요.",22)
        _button(content,"Restart","새 탐험 시작","restart")

func _label(parent: Node, value: String, font_size: int) -> void:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",Color("e6e3da"))
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)

func _button(parent: Node, node_name: String, text_value: String, choice: String) -> void:
    var button := Button.new()
    button.name = node_name
    button.text = text_value
    button.custom_minimum_size = Vector2(608,104)
    button.pressed.connect(_choose.bind(choice,int(run.revision),str(run.stage),generation))
    parent.add_child(button)

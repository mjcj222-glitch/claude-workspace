extends Node
## Owns one live Battle or one progression screen. Persistence belongs to SaveStore.
const RunV2 = preload("res://scripts/v2/run_rules.gd")
const Config = preload("res://scripts/v2/config.gd")
const SaveV2 = preload("res://scripts/v2/save_store.gd")
const BattleScene = preload("res://scenes/v2/battle.tscn")
const FONT = preload("res://assets/NotoSansCJK-Regular.ttc")
@export var seed: int = 41
@export var reduced := false
var run: Dictionary = {}
var battle: Node
var choice_panel: Control
var generation := 0
var save_error := ""
# Ephemeral feedback belongs only to the immediately succeeding screen.
var _refund_notice: Dictionary = {}
var _completed_checkpoint: Dictionary = {}
var _last_good_record: Dictionary = {}
# A completed resume may pause on a choice before its next owner exists.
var _resume_combat_floor := 0
var _resume_board_floor := 0

func _ready() -> void:
    # Do not even probe a real slot when the command line disables saving.
    if "--no-save" in OS.get_cmdline_user_args():
        new_run(seed)
    elif FileAccess.file_exists(Config.SAVE_PATH):
        if not resume_checkpoint(SaveV2.read_checkpoint()): _show_save_error()
    else:
        new_run(seed)

func checkpoint_record() -> Dictionary:
    var checkpoint := {}
    if is_instance_valid(battle):
        checkpoint = battle.export_checkpoint()
        if not checkpoint.is_empty():
            if checkpoint.state.status != "active": return {}
            var synced := RunV2.sync_battle(run,checkpoint.state)
            if not synced.ok: return {}
            run = synced.state
            _completed_checkpoint = {}
        elif battle.phase != "SETTLING" or battle.board.refill_phase != "initial":
            return {}
    if checkpoint.is_empty(): checkpoint = _completed_checkpoint.duplicate(true)
    if checkpoint.is_empty(): return {}
    return SaveV2.validate({"version":2,"ruleset":SaveV2.RULESET,"run":run,
        "battle":checkpoint.state,"board":checkpoint.board,"reduced":reduced})

func last_good_checkpoint() -> Dictionary:
    # Task9 can explicitly resume this record after a physical failure.
    return _last_good_record.duplicate(true)

func save_checkpoint(path: String = Config.SAVE_PATH) -> Error:
    var record := checkpoint_record()
    if record.is_empty(): return ERR_BUSY
    var error := SaveV2.write_checkpoint(path,record)
    if error != OK:
        _set_save_error("저장하지 못했어요. 마지막 정상 저장을 보존했습니다. (%d)" % error)
        return error
    _last_good_record = record.duplicate(true)
    var previous_error := save_error
    save_error = ""
    if not previous_error.is_empty() and is_instance_valid(battle) \
        and battle.view.get_node("PreviewLine").text == previous_error:
        battle.view.show_plan(battle.snapshot,{})
    return OK

func resume_checkpoint(value: Dictionary) -> bool:
    var record := SaveV2.validate(value)
    if record.is_empty():
        _set_save_error("v2 저장을 읽을 수 없어요. 새 탐험을 명시적으로 시작해 주세요.")
        return false
    generation += 1
    _refund_notice = {}
    run = record.run.duplicate(true)
    seed = int(run.seed)
    reduced = record.reduced
    save_error = ""
    _last_good_record = record.duplicate(true)
    _resume_combat_floor = maxi(_resume_combat_floor,int(record.battle.revision))
    _resume_board_floor = maxi(_resume_board_floor,int(record.board.snapshot.version))
    if is_instance_valid(battle):
        _resume_combat_floor = maxi(_resume_combat_floor,int(battle.state.get("revision",0)))
        _resume_board_floor = maxi(_resume_board_floor,int(battle.board.version))
    var checkpoint := {"state":record.battle.duplicate(true),"board":record.board.duplicate(true),"reduced":record.reduced}
    _completed_checkpoint = checkpoint.duplicate(true) if record.battle.status != "active" else {}
    if record.battle.status == "active":
        checkpoint.state.revision = _resume_combat_floor
        checkpoint.board.snapshot.version = _resume_board_floor
    _show_stage(checkpoint if record.battle.status == "active" else {})
    return true

func _on_checkpoint_available(source: Node, owner_generation: int, owner_stage: String) -> void:
    if source != battle or owner_generation != generation or run.stage != owner_stage: return
    save_checkpoint()

func _on_battle_error(_reason: String, source: Node, owner_generation: int, owner_stage: String) -> void:
    if source != battle or owner_generation != generation or run.stage != owner_stage or source.phase != "ERROR": return
    if source.view.get_node_or_null("RecoveryResume") != null or source.view.get_node_or_null("RecoveryRestart") != null: return
    var record := last_good_checkpoint()
    var button := Button.new()
    button.name = "RecoveryResume" if not record.is_empty() else "RecoveryRestart"
    button.text = "마지막 정상 지점 재개" if not record.is_empty() else "새 탐험 시작"
    button.position = Vector2(100,730)
    button.size = Vector2(520,90)
    button.pressed.connect(func():
        if source != battle or owner_generation != generation or run.stage != owner_stage or source.phase != "ERROR": return
        if record.is_empty(): new_run(seed)
        else: resume_checkpoint(record))
    source.view.add_child(button)

func _set_save_error(message: String) -> void:
    save_error = message
    if is_instance_valid(battle): battle.view.get_node("PreviewLine").text = message
    elif is_instance_valid(choice_panel):
        var content := choice_panel.get_node_or_null("Choices")
        if content != null: _label(content,message,20)

func _show_save_error() -> void:
    _retire_battle()
    choice_panel = Control.new()
    choice_panel.name = "SaveError"
    choice_panel.size = Vector2(720,1280)
    choice_panel.theme = Theme.new()
    choice_panel.theme.default_font = FONT
    add_child(choice_panel)
    var content := VBoxContainer.new()
    content.position = Vector2(56,230)
    content.size.x = 608
    choice_panel.add_child(content)
    _label(content,save_error,24)
    var restart := Button.new()
    restart.text = "새 탐험 시작"
    restart.custom_minimum_size = Vector2(608,104)
    restart.pressed.connect(new_run.bind(seed))
    content.add_child(restart)

func new_run(seed_value: int) -> void:
    generation += 1
    _refund_notice = {}
    seed = seed_value
    run = RunV2.fresh(seed_value)
    _completed_checkpoint = {}
    _last_good_record = {}
    _resume_combat_floor = 0
    _resume_board_floor = 0
    save_error = ""
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

func _show_stage(restored: Dictionary = {}) -> void:
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
        battle.recovery_failed.connect(_on_battle_error.bind(battle,generation,str(run.stage)))
        battle.finished.connect(_on_battle_finished.bind(battle,generation,str(run.stage)))
        battle.checkpoint_available.connect(_on_checkpoint_available.bind(battle,generation,str(run.stage)))
        add_child(battle)
        if restored.is_empty():
            # A completed boundary resumes the next fresh context. Carry only
            # version floors; keep its new board, RNG, IDs and combat resources.
            battle.board.version = _resume_board_floor
            battle.start_battle(context)
            battle.state.revision = _resume_combat_floor+1
        else:
            battle.restore_checkpoint(restored)
        _resume_combat_floor = 0
        _resume_board_floor = 0
        if not save_error.is_empty(): _set_save_error(save_error)
    else:
        _show_choices()

func _on_battle_finished(summary: Dictionary, source: Node, owner_generation: int, owner_stage: String) -> void:
    if not is_instance_valid(source) or source != battle or owner_generation != generation \
        or run.get("stage","") != owner_stage or source.phase != "FINISHED": return
    # finished carries a summary; the current owner's adopted CombatState is authoritative.
    var current: Dictionary = source.state
    for key in ["status","hp","energy","enemy_id"]:
        if not summary.has(key) or summary[key] != current.get(key): return
    var completed: Dictionary = source.export_checkpoint()
    if completed.is_empty(): return
    var result := RunV2.complete_battle(run,current)
    if not result.ok: return
    run = result.state
    _refund_notice = source.refund_notice.duplicate(true)
    _completed_checkpoint = completed.duplicate(true)
    # Capture before retirement; this full finished board also supports choices.
    _save_completed_boundary()
    _show_stage()

func _save_completed_boundary() -> void:
    var record := SaveV2.validate({"version":2,"ruleset":SaveV2.RULESET,"run":run,
        "battle":_completed_checkpoint.get("state",{}),"board":_completed_checkpoint.get("board",{}),"reduced":reduced})
    if record.is_empty():
        _set_save_error("완료 지점의 저장 상태가 일치하지 않아요.")
        return
    var error := SaveV2.write_checkpoint(Config.SAVE_PATH,record)
    if error != OK:
        _set_save_error("저장하지 못했어요. 마지막 정상 저장을 보존했습니다. (%d)" % error)
        return
    _last_good_record = record.duplicate(true)
    save_error = ""

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
    _refund_notice = {}
    _save_completed_boundary()
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
    if not _refund_notice.is_empty():
        _label(content,preload("res://scripts/v2/battle_view.gd").refund_text(_refund_notice),21)
    if not save_error.is_empty(): _label(content,save_error,20)
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

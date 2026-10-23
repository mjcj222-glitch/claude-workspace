extends RefCounted
## Strict independent v2 records. A completed battle may accompany the next
## chosen Run until its new physical board settles; rewards are never replayed.
const Config = preload("res://scripts/v2/config.gd")
const Combat = preload("res://scripts/v2/combat_rules.gd")
const RunV2 = preload("res://scripts/v2/run_rules.gd")
const Geometry = preload("res://scripts/v2/geometry.gd")
const Board = preload("res://scripts/v2/board.gd")
const RULESET := "party-puzzle-v2-initial"
# JSON numbers are doubles; only the expedition seed needs signed64 wire text.
const MAX_EXACT := 9007199254740991

static func _keys(value: Variant, names: Array) -> bool:
    if not value is Dictionary or value.size() != names.size(): return false
    for key in names:
        if not value.has(key): return false
    return true

static func _integer(value: Variant, minimum: int, maximum: int = MAX_EXACT) -> bool:
    return typeof(value) == TYPE_INT and value >= minimum and value <= maximum

static func _number(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _int_text(value: Variant) -> bool:
    return value is String and value.is_valid_int() and str(int(value)) == value

static func _normalize(value: Variant) -> Variant:
    if value is Dictionary:
        var result := {}
        for key in value: result[key] = _normalize(value[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value: result.append(_normalize(item))
        return result
    if typeof(value) == TYPE_FLOAT and is_finite(value) and absf(value) <= MAX_EXACT and value == floor(value):
        return int(value)
    return value

static func encode(record: Dictionary) -> String:
    var wire := record.duplicate(true)
    if wire.get("run") is Dictionary and typeof(wire.run.get("seed")) == TYPE_INT:
        wire.run.seed = str(wire.run.seed)
    return JSON.stringify(wire,"",true,true)

static func decode(raw: String) -> Dictionary:
    var parser := JSON.new()
    if parser.parse(raw) != OK or not parser.data is Dictionary: return {}
    return validate(parser.data)

static func validate(value: Dictionary) -> Dictionary:
    var record: Dictionary = _normalize(value)
    if not _keys(record,["version","ruleset","run","battle","board","reduced"]) \
        or record.version != 2 or record.ruleset != RULESET or typeof(record.reduced) != TYPE_BOOL: return {}
    if not record.run is Dictionary or not record.battle is Dictionary or not record.board is Dictionary: return {}
    var run: Dictionary = record.run
    if run.get("seed") is String:
        if not _int_text(run.seed): return {}
        run.seed = int(run.seed)
    if not _run_valid(run) or not _combat_valid(record.battle) or not _board_valid(record.board): return {}
    if not _consistent(run,record.battle,record.board): return {}
    return record

static func _party(value: Variant) -> bool:
    return value is Array and value in [["hero"],["hero","bomber"],["hero","gardener"]]

static func _run_valid(run: Dictionary) -> bool:
    if not _keys(run,["revision","seed","stage","route","party","hero_limit","hp","energy",
        "battle_seeds","applied_choices","completed_battles"]): return false
    if not _integer(run.revision,1) or typeof(run.seed) != TYPE_INT or not _party(run.party) \
        or not _integer(run.hp,0,Config.MAX_HP) or not _integer(run.energy,0,Config.MAX_ENERGY) \
        or not _integer(run.hero_limit,Config.HERO_START_LIMIT,Config.HERO_MAX_LIMIT): return false
    if run.stage not in ["battle1","route_choice","battle2","recruit_choice","battle3","completed","lost"] \
        or run.route not in ["","safe","risk"]: return false
    if not run.battle_seeds is Array or run.battle_seeds.size() != Config.BATTLE_COUNT \
        or not run.applied_choices is Array or not run.completed_battles is Array: return false
    for seed in run.battle_seeds:
        if not _integer(seed,0,4294967295): return false
    if run.battle_seeds != RunV2.fresh(run.seed).battle_seeds: return false
    var n: int = run.completed_battles.size()
    if n > Config.BATTLE_COUNT or run.completed_battles != RunV2.BATTLE_STAGES.slice(0,n): return false
    var choices := []
    if run.route != "": choices.append("route_choice")
    var recruited: bool = run.stage in ["battle3","completed"] or (run.stage == "lost" and n == 3)
    if recruited: choices.append("recruit_choice")
    if run.applied_choices != choices: return false
    if (run.stage in ["battle1","route_choice"] or (run.stage == "lost" and n == 1)) != (run.route == ""): return false
    var expected_n := {"battle1":0,"route_choice":1,"battle2":1,"recruit_choice":2,"battle3":2,"completed":3}
    if run.stage == "lost":
        if n < 1 or run.hp != 0: return false
    elif n != expected_n[run.stage] or run.hp == 0: return false
    if not recruited and run.party != ["hero"]: return false
    # Risk reward requires a hall2 victory, never a hall2 defeat.
    var risk_won: bool = run.route == "risk" and (run.stage in ["recruit_choice","battle3","completed"] or (run.stage == "lost" and n == 3))
    var limit := Config.HERO_START_LIMIT + (Config.RISK_LIMIT_BONUS if risk_won else 0)
    if recruited and run.party == ["hero"]: limit += Config.DECLINE_LIMIT_BONUS
    return run.hero_limit == mini(Config.HERO_MAX_LIMIT,limit)

static func _combat_valid(state: Dictionary) -> bool:
    if not _keys(state,["revision","enemy_id","hp","enemy_hp","turn","actions_left","pending_damage","pending_heal",
        "energy","party","hero_limit","team_skill_used","bomb_buff","intent","refill_pending","status"]): return false
    if not Config.ENEMIES.has(state.enemy_id) or not _party(state.party) \
        or not _integer(state.revision,1) or not _integer(state.turn,1,MAX_EXACT / Config.PRESSURE_PER_TURN) \
        or not _integer(state.hp,0,Config.MAX_HP) or not _integer(state.energy,0,Config.MAX_ENERGY) \
        or not _integer(state.enemy_hp,0,Config.ENEMIES[state.enemy_id].hp) \
        or not _integer(state.hero_limit,Config.HERO_START_LIMIT,Config.HERO_MAX_LIMIT) \
        or typeof(state.team_skill_used) != TYPE_BOOL or typeof(state.refill_pending) != TYPE_BOOL \
        or state.refill_pending or state.status not in ["active","victory","defeat"]: return false
    if not _integer(state.actions_left,0,Config.ACTIONS_PER_TURN): return false
    var performed := Config.ACTIONS_PER_TURN - int(state.actions_left)
    var max_damage := Config.PIECE_COUNT * (Config.DIRECT_DAMAGE_PER_PIECE + Config.BLAST_DAMAGE_PER_PIECE) + int(Config.GROUP_REWARDS[0].damage_bonus)
    if not _integer(state.pending_damage,0,performed*max_damage) \
        or not _integer(state.pending_heal,0,performed*Config.PIECE_COUNT*Config.HEAL_PER_PIECE): return false
    if state.status == "active":
        if state.actions_left < 1 or state.hp == 0 or state.enemy_hp == 0: return false
    else:
        if state.actions_left != 0 or state.pending_damage != 0 or state.pending_heal != 0: return false
        if state.status == "victory" and (state.enemy_hp != 0 or state.hp == 0): return false
        if state.status == "defeat" and (state.hp != 0 or state.enemy_hp == 0): return false
    if not _keys(state.intent,["kind","base_damage","pressure","total_damage","weakened"]) \
        or typeof(state.intent.weakened) != TYPE_BOOL: return false
    for key in ["base_damage","pressure","total_damage"]:
        if not _integer(state.intent[key],0): return false
    if state.intent != Combat.intent(state.enemy_id,state.turn,state.intent.weakened): return false
    var buff: Variant = state.bomb_buff
    if not _keys(buff,["active","paid_cost","generated_count","refunded"]) \
        or typeof(buff.active) != TYPE_BOOL or typeof(buff.refunded) != TYPE_BOOL \
        or not _integer(buff.generated_count,0,Config.PIECE_COUNT*Config.ACTIONS_PER_TURN) \
        or not _integer(buff.paid_cost,0,Config.SKILL_COSTS.bomber): return false
    if buff.paid_cost == 0:
        return not buff.active and not buff.refunded and buff.generated_count == 0
    if buff.paid_cost != Config.SKILL_COSTS.bomber or not "bomber" in state.party: return false
    if buff.active:
        return state.status == "active" and state.team_skill_used and not buff.refunded \
            and buff.generated_count <= performed*Config.PIECE_COUNT
    return (buff.refunded and buff.generated_count == 0) or (not buff.refunded and buff.generated_count > 0)

static func _board_valid(board: Dictionary) -> bool:
    if not _keys(board,["snapshot","next_id","rng_seed","rng_state"]) \
        or not _int_text(board.rng_seed) or not _int_text(board.rng_state) \
        or not _integer(board.next_id,1) or not _keys(board.snapshot,["version","pieces"]): return false
    var snapshot: Dictionary = board.snapshot
    if not _integer(snapshot.version,1) or not snapshot.pieces is Array or snapshot.pieces.size() != Config.PIECE_COUNT: return false
    var previous := 0
    var polygons: Array = []
    for item in snapshot.pieces:
        if not _keys(item,["id","hull_id","match_type","size","x","y","angle","bomb_tier"]): return false
        if not _integer(item.id,previous+1,board.next_id-1) or not _integer(item.hull_id,0,Config.HULL_COUNT-1) \
            or item.match_type not in Config.TYPES or not _integer(item.bomb_tier,0,Config.BOMB_RADIUS_MULTIPLIERS.size()) \
            or (item.bomb_tier > 0 and item.match_type != "blue"): return false
        previous = item.id
        for key in ["size","x","y","angle"]:
            if not _number(item[key]): return false
        if item.size < Config.SIZE_MIN or item.size > Config.SIZE_MAX \
            or absf(item.angle) > TAU * MAX_EXACT or absf(item.x) > Config.BOARD_WIDTH \
            or absf(item.y) > Config.BOARD_HEIGHT: return false
        var polygon := Geometry.transformed(Geometry.polygon(item.hull_id,item.size),Vector2(item.x,item.y),item.angle)
        for prior in polygons:
            for overlap in Geometry2D.intersect_polygons(polygon,prior):
                # Accepted native physics permits only its shallow contact slop.
                if Geometry.area(overlap) >= 32.0: return false
        polygons.append(polygon)
    var probe := Board.new()
    var supported := probe.supported(snapshot)
    probe.free()
    return supported

static func _consistent(run: Dictionary, state: Dictionary, board: Dictionary) -> bool:
    var index := 0 if state.enemy_id == "hall1" else (2 if state.enemy_id == "gate" else 1)
    if board.rng_seed != str(run.battle_seeds[index]): return false
    if state.status == "active":
        var context := RunV2.battle_context(run)
        return not context.is_empty() and context.enemy_id == state.enemy_id \
            and run.hp == state.hp and run.energy == state.energy \
            and run.party == state.party and run.hero_limit == state.hero_limit
    # Reconstruct precisely the last completion, then only already-recorded
    # guarded choices. This permits safe healing, risk reward and recruitment
    # deltas while refusing duplicate rewards or a mismatched completed board.
    if run.completed_battles.is_empty() or run.completed_battles.back() != RunV2.BATTLE_STAGES[index]: return false
    var predecessor := RunV2.fresh(run.seed)
    predecessor.stage = RunV2.BATTLE_STAGES[index]
    predecessor.route = "" if index == 0 else run.route
    predecessor.completed_battles = RunV2.BATTLE_STAGES.slice(0,index)
    predecessor.applied_choices = [] if index == 0 else ["route_choice"]
    if index == 2: predecessor.applied_choices.append("recruit_choice")
    predecessor.party = state.party.duplicate()
    predecessor.hero_limit = state.hero_limit
    predecessor.hp = state.hp
    predecessor.energy = state.energy
    if not _run_valid(predecessor):
        # A defeat's HP becomes zero only upon completion.
        predecessor.hp = Config.START_HP
        if not _run_valid(predecessor): return false
        predecessor.hp = state.hp
    var result := RunV2.complete_battle(predecessor,state)
    if not result.ok: return false
    var expected: Dictionary = result.state
    if index == 0 and run.stage == "battle2":
        result = RunV2.choose_route(expected,run.route)
        if not result.ok: return false
        expected = result.state
    elif index == 1 and run.stage == "battle3":
        var recruit: String = "skip" if run.party == ["hero"] else str(run.party[1])
        result = RunV2.choose_recruit(expected,recruit)
        if not result.ok: return false
        expected = result.state
    for key in run:
        if key != "revision" and run[key] != expected[key]: return false
    return true

static func _fixture_path(path: String) -> bool:
    var root := OS.get_environment("XDG_DATA_HOME").simplify_path()
    var clean := path.simplify_path()
    return root.is_absolute_path() and clean.is_absolute_path() and clean.begins_with(root+"/") \
        and clean.get_file().begins_with("fixture-") and clean.ends_with(".json")

static func _bypass(path: String) -> bool:
    return "--no-save" in OS.get_cmdline_user_args() and not _fixture_path(path)

static func read_checkpoint(path: String = Config.SAVE_PATH) -> Dictionary:
    if _bypass(path): return {}
    if path.get_file() in ["resonance_godot.json","resonance_godot_v1.json"] or not FileAccess.file_exists(path): return {}
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null: return {}
    return decode(file.get_as_text())

static func write_checkpoint(path: String, record: Dictionary) -> Error:
    if _bypass(path): return OK
    if path.get_file() in ["resonance_godot.json","resonance_godot_v1.json"] or validate(record).is_empty(): return ERR_INVALID_DATA
    var temporary := path+".tmp"
    var file := FileAccess.open(temporary,FileAccess.WRITE)
    if file == null: return FileAccess.get_open_error()
    file.store_string(encode(record))
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK: return error
    # Rename in the same directory is the sole slot mutation. Never remove the
    # existing slot first; a failed replacement leaves the last good bytes.
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))

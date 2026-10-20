extends RefCounted
## Numeric source of truth for the independent v2 expedition.

const BOARD_WIDTH := 600.0
const BOARD_HEIGHT := 600.0
const PIECE_COUNT := 42
const CONTACT_EPS := 1.0
# Total hull-edge gap for visible matching/skills; physical support stays1.0.
const MATCH_CONTACT_EPS := 1.75
const BASE_HULL_SCALE := 1.08
const SIZE_MIN := 0.96
const SIZE_MAX := 1.04
const SETTLE_SPEED := 2.0
const SETTLE_ANGULAR_SPEED := 0.045
const SETTLE_QUIET_TICKS := 28
const SETTLE_TIMEOUT := 12.0
const BOUNDARY_SLOP := 0.8
const SPAWN_LANES := 6
const SPAWN_X := 50.0
const SPAWN_SPACING := 100.0
const SPAWN_Y := -60.0
const SPAWN_ROW_SPACING := 110.0
const SPAWN_JITTER := 3.0
const WALL_THICKNESS := 25.0
const WALL_TOP := -1200.0
const PIECE_MASS := 1.0
const LINEAR_DAMP := 0.7
const ANGULAR_DAMP := 1.4
const FRICTION := 0.18
const BOUNCE := 0.04
const MAX_CONTACTS := 24

# Hull IDs are independent from surface types: circle, rounded square, star, leaf.
const HULL_COUNT := 4
const TYPES := ["red", "yellow", "blue", "heart"]
const COLOR_TYPES := ["red", "yellow", "blue"]
const TYPE_WEIGHTS := {"red": 30, "yellow": 30, "blue": 30, "heart": 10}
const TYPE_WEIGHT_TOTAL := 100
const TYPE_HULLS := {"red": 0, "yellow": 2, "blue": 1, "heart": 3}
const TYPE_COLORS := {"red": Color("f45c38"), "yellow": Color("ffc735"),
    "blue": Color("24bce5"), "heart": Color("f67bb1")}

const MIN_GROUP := 3
const MAX_HP := 72
const START_HP := 72
const HEAL_PER_PIECE := 3
const ACTIONS_PER_TURN := 3
const MAX_ENERGY := 10
const START_ENERGY := 4
const SKILL_COSTS := {"hero": 4, "bomber": 6, "gardener": 4}
const HERO_START_LIMIT := 3
const HERO_MAX_LIMIT := 5
const GARDENER_LIMIT := 2
const HERO_SHOW_SECONDS := 0.7
# The first matching threshold determines the direct color-group reward.
const GROUP_REWARDS := [
    {"minimum": 12, "damage_bonus": 36, "energy": 6},
    {"minimum": 8, "damage_bonus": 18, "energy": 4},
    {"minimum": 5, "damage_bonus": 6, "energy": 2},
    {"minimum": 3, "damage_bonus": 0, "energy": 1}]
const DIRECT_DAMAGE_PER_PIECE := 2
const BLAST_DAMAGE_PER_PIECE := 1
const PRESSURE_PER_TURN := 4
const PRESSURE_START_TURN := 3
const BOMB_RADIUS_MULTIPLIERS := {1: 1.0, 2: 1.6, 3: 2.2}
const ENEMIES := {
    "hall1": {"hp": 72, "normal": 8, "strong": 0, "strong_every": 0},
    "hall2_safe": {"hp": 108, "normal": 12, "strong": 20, "strong_every": 3},
    "hall2_risk": {"hp": 132, "normal": 16, "strong": 26, "strong_every": 3},
    "gate": {"hp": 168, "normal": 16, "strong": 28, "strong_every": 2}}
const SAFE_ROUTE_HEAL := 18
const RISK_LIMIT_BONUS := 1
const DECLINE_LIMIT_BONUS := 1
const RECOVERY_ATTEMPTS := 8
const BATTLE_COUNT := 3
const SAVE_PATH := "user://resonance_godot_v2.json"

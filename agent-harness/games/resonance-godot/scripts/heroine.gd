extends Node2D

signal pose_changed(pose: String)
signal strike
const TEXTURES := {
    "idle": preload("res://assets/heroine/heroine-base-idle-v1.png"),
    "windup": preload("res://assets/heroine/heroine-attack-windup-v1.png"),
    "strike": preload("res://assets/heroine/heroine-attack-strike-v1.png")
}
# Measured on the original alpha >=128 silhouette: the planted left sole.
var anchors := {"idle":Vector2(408.3,1206),"windup":Vector2(400.5,1209),"strike":Vector2(399.1,1215)}
var body_heights := {"idle":1141.0,"windup":1144.0,"strike":1163.0}
var display_body_height := 234.0
var sprite: Sprite2D
var ghost: Sprite2D
var pose := "idle"
var reduced := false
var busy := false
var blend: Tween

func _ready() -> void:
    ghost = Sprite2D.new()
    ghost.centered = false
    ghost.modulate.a = 0
    add_child(ghost)
    sprite = Sprite2D.new()
    sprite.centered = false
    add_child(sprite)
    set_pose("idle")

func set_pose(value: String) -> void:
    if blend and blend.is_running(): blend.kill()
    if sprite.texture and not reduced:
        ghost.texture = sprite.texture
        ghost.position = sprite.position
        ghost.scale = sprite.scale
        ghost.modulate = Color(1,1,1,0.30)
        blend = create_tween()
        blend.tween_property(ghost,"modulate:a",0.0,0.06)
    else: ghost.modulate.a = 0
    pose = value
    var source := "idle" if value == "recover" else value
    sprite.texture = TEXTURES[source]
    sprite.scale = Vector2.ONE * (display_body_height/body_heights[source])
    sprite.position = -anchors[source]*sprite.scale
    pose_changed.emit(value)

func attack() -> void:
    if reduced:
        strike.emit()
        return
    busy = true
    set_pose("windup")
    await get_tree().create_timer(0.14).timeout
    if not reduced: set_pose("strike")
    strike.emit()
    await get_tree().create_timer(0.10).timeout
    if not reduced: set_pose("recover")
    await get_tree().create_timer(0.18).timeout
    if not reduced: set_pose("idle")
    busy = false

func set_reduced(value: bool) -> void:
    reduced = value
    if value:
        set_pose("idle")
        ghost.modulate.a = 0

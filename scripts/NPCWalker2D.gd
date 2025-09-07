class_name NPCWalker2D
extends Node2D

@export var start_position: Vector2
@export var end_position: Vector2
@export var animation_name: StringName = &"walk_east"

@onready var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
var _ratio: float = 0.0

func _ready() -> void:
    add_child(sprite)
    sprite.z_index = 20
    global_position = start_position
    _play_anim_if_available(animation_name, [&"walk_east", &"walk"]) # prefer east, fallback to generic walk
    sprite.flip_h = false

func set_sprite_frames(frames: SpriteFrames, anim: StringName = &"walk") -> void:
    if frames == null:
        return
    sprite.sprite_frames = frames
    animation_name = anim
    _play_anim_if_available(animation_name, [animation_name])

func set_progress_ratio(ratio: float) -> void:
    _ratio = clamp(ratio, 0.0, 1.0)
    global_position = start_position.lerp(end_position, _ratio)
    # Update animation based on arrival
    if is_equal_approx(_ratio, 1.0):
        _play_anim_if_available(&"walk_north", [&"walk_north", &"walk"])  # arrival pose
    else:
        _play_anim_if_available(&"walk_east", [&"walk_east", &"walk"])   # moving east

func _play_anim_if_available(preferred: StringName, fallbacks: Array) -> void:
    if sprite == null or sprite.sprite_frames == null:
        return
    var to_play: StringName = preferred
    if not sprite.sprite_frames.has_animation(to_play):
        for f in fallbacks:
            if sprite.sprite_frames.has_animation(f):
                to_play = f
                break
    if sprite.animation != to_play:
        sprite.play(to_play)

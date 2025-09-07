extends Node2D

signal performed_action(cell: Vector2i, action: String)

@export var grid_size: Vector2i = Vector2i(8, 8)
@export var tile: int = 32

var cursor: Vector2i = Vector2i(0, 0)
var current_action: String = "mow"
var facing_dir: String = "south"

@onready var anim: LPCAnimatedSprite2D = $LPCAnimatedSprite2D

# Tweened movement config
var moving: bool = false
@export var step_time: float = 0.24
var _move_tween: Tween

func _ready() -> void:
    _sync_position()
    queue_redraw()
    _update_idle_animation()

func _sync_position() -> void:
    position = Vector2(cursor.x * tile, cursor.y * tile)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_up"):
        _try_start_step(Vector2i(0, -1))
    elif event.is_action_pressed("move_down"):
        _try_start_step(Vector2i(0, 1))
    elif event.is_action_pressed("move_left"):
        _try_start_step(Vector2i(-1, 0))
    elif event.is_action_pressed("move_right"):
        _try_start_step(Vector2i(1, 0))
    elif event.is_action_pressed("action"):
        emit_signal("performed_action", cursor, current_action)
    elif event.is_action_pressed("toggle_action"):
        current_action = ("pull" if current_action == "mow" else "mow")
        # If switching into mow, immediately act on the current tile
        if current_action == "mow":
            emit_signal("performed_action", cursor, current_action)

func _try_start_step(delta: Vector2i) -> void:
    if moving:
        return
    var nx: int = clamp(cursor.x + delta.x, 0, grid_size.x - 1)
    var ny: int = clamp(cursor.y + delta.y, 0, grid_size.y - 1)
    var target: Vector2i = Vector2i(nx, ny)
    if target == cursor:
        # Face the attempted direction but don't move
        var dir := _vec_to_dir(delta)
        if dir != "":
            facing_dir = dir
            _update_idle_animation()
        return

    # Update logical cursor immediately; tween the visual position
    var dir2 := _vec_to_dir(delta)
    if dir2 != "":
        facing_dir = dir2
    var from_pos := position
    cursor = target
    var to_pos := Vector2(cursor.x * tile, cursor.y * tile)
    queue_redraw()

    moving = true
    _play_walk_animation()

    if _move_tween and _move_tween.is_running():
        _move_tween.kill()
    _move_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
    _move_tween.tween_property(self, "position", to_pos, step_time)
    _move_tween.finished.connect(_on_step_finished)

func _draw() -> void:
    var size := Vector2(tile, tile)
    var rect := Rect2(Vector2.ZERO, size)
    draw_rect(rect, Color(1, 1, 0, 0.12), true)
    draw_rect(rect, Color(1, 1, 0, 0.9), false, 2.0)

func configure(grid: Vector2i, tile_size: int) -> void:
    grid_size = grid
    tile = tile_size
    _sync_position()
    queue_redraw()

func _process(_delta: float) -> void:
    if moving:
        return
    # If stationary, face held direction; otherwise idle
    var v := _read_input_vector()
    if v == Vector2i.ZERO:
        _update_idle_animation()
    else:
        var dir := _vec_to_dir(v)
        if dir != "":
            facing_dir = dir
            _update_idle_animation()

func _play_walk_animation() -> void:
    if not anim:
        return
    var name := "walk_" + facing_dir
    if anim.animation != name:
        anim.play(name)
    # One loop per step
    anim.speed_scale = 1.0 / max(step_time, 0.01)

func _update_idle_animation() -> void:
    if not anim:
        return
    var name := "idle_" + facing_dir
    if anim.animation != name:
        anim.play(name)
    anim.speed_scale = 1.0

func _vec_to_dir(v: Vector2i) -> String:
    if abs(v.x) >= abs(v.y):
        if v.x > 0:
            return "east"
        elif v.x < 0:
            return "west"
    # prefer vertical when x == 0 or smaller magnitude
    if v.y > 0:
        return "south"
    elif v.y < 0:
        return "north"
    return ""

func _read_input_vector() -> Vector2i:
    var v := Vector2i.ZERO
    if Input.is_action_pressed("move_left"):
        v.x -= 1
    if Input.is_action_pressed("move_right"):
        v.x += 1
    if Input.is_action_pressed("move_up"):
        v.y -= 1
    if Input.is_action_pressed("move_down"):
        v.y += 1
    return v

func _on_step_finished() -> void:
    moving = false
    _update_idle_animation()
    # Auto-act when arriving on a tile in mow mode
    if current_action == "mow":
        emit_signal("performed_action", cursor, current_action)
    # If a direction is still held, chain the next step
    var v := _read_input_vector()
    if v != Vector2i.ZERO:
        _try_start_step(_dominant_axis(v))

func _dominant_axis(v: Vector2i) -> Vector2i:
    # Collapse to a single axis step based on dominant component
    if abs(v.x) >= abs(v.y):
        return Vector2i(signi(v.x), 0)
    else:
        return Vector2i(0, signi(v.y))

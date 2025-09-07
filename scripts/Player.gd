extends Node2D

signal performed_action(cell: Vector2i, action: String)

@export var grid_size: Vector2i = Vector2i(8, 8)
@export var tile: int = 32

var cursor: Vector2i = Vector2i(0, 0)
var current_action: String = "mow"
var facing_dir: String = "south"

@onready var anim: LPCAnimatedSprite2D = $LPCAnimatedSprite2D

func _ready() -> void:
    _sync_position()
    queue_redraw()
    _update_idle_animation()

func _sync_position() -> void:
    position = Vector2(cursor.x * tile, cursor.y * tile)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_up"):
        move_cursor(Vector2i(0, -1))
    elif event.is_action_pressed("move_down"):
        move_cursor(Vector2i(0, 1))
    elif event.is_action_pressed("move_left"):
        move_cursor(Vector2i(-1, 0))
    elif event.is_action_pressed("move_right"):
        move_cursor(Vector2i(1, 0))
    elif event.is_action_pressed("action"):
        emit_signal("performed_action", cursor, current_action)
    elif event.is_action_pressed("toggle_action"):
        current_action = ("pull" if current_action == "mow" else "mow")
        # If switching into mow, immediately act on the current tile
        if current_action == "mow":
            emit_signal("performed_action", cursor, current_action)

func move_cursor(delta: Vector2i) -> void:
    var nx: int = clamp(cursor.x + delta.x, 0, grid_size.x - 1)
    var ny: int = clamp(cursor.y + delta.y, 0, grid_size.y - 1)
    cursor = Vector2i(nx, ny)
    _sync_position()
    queue_redraw()
    _update_walk_animation(delta)
    # Auto-act when in mow mode so movement mows without pressing Space
    if current_action == "mow":
        emit_signal("performed_action", cursor, current_action)

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
    var v := Vector2i(0, 0)
    if Input.is_action_pressed("move_left"):
        v.x -= 1
    if Input.is_action_pressed("move_right"):
        v.x += 1
    if Input.is_action_pressed("move_up"):
        v.y -= 1
    if Input.is_action_pressed("move_down"):
        v.y += 1
    if v == Vector2i.ZERO:
        _update_idle_animation()
    else:
        _update_walk_animation(v)

func _update_walk_animation(v: Vector2i) -> void:
    if not anim:
        return
    var dir := _vec_to_dir(v)
    if dir != "":
        facing_dir = dir
        anim.play("walk_" + dir)

func _update_idle_animation() -> void:
    if not anim:
        return
    anim.play("idle_" + facing_dir)

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

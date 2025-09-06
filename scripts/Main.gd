extends Node2D

@onready var board: TileMap = $Board
@onready var player: Node2D = $Cursor
@onready var ui: CanvasLayer = $UI
@onready var turn_timer: Timer = $TurnTimer

var total_time: float = 180.0
var time_remaining: float = 180.0
var threshold: int = 5
var game_over: bool = false

func _ready() -> void:
	_ensure_input_map()
	if player.has_signal("performed_action"):
		player.connect("performed_action", Callable(self, "_on_player_action"))
	if board.has_signal("score_changed"):
		board.connect("score_changed", Callable(self, "_on_score_changed"))
	if ui.has_signal("restart_pressed"):
		ui.connect("restart_pressed", Callable(self, "_on_restart"))
	# Ensure player uses Board's grid/tile sizes
	if player.has_method("configure"):
		player.configure(board.GRID_SIZE, board.TILE)
	reset_game()

func reset_game() -> void:
	game_over = false
	time_remaining = total_time
	if board.has_method("randomize_start"):
		board.randomize_start()
	_update_score_ui()
	_update_time_ui()
	if ui.has_method("show_game_over"):
		ui.show_game_over(false, false)

func _on_player_action(cell: Vector2i, action: String) -> void:
	if game_over:
		return
	var changed := false
	if board.has_method("apply_player_action"):
		changed = board.apply_player_action(cell, action)
	if changed and board.has_method("apply_weed_rules"):
		board.apply_weed_rules()
	_update_score_ui()
	_tick_time()
	_check_game_over()
	if ui.has_method("set_turn_text"):
		ui.set_turn_text(action.capitalize())

func _tick_time() -> void:
	time_remaining = max(0.0, time_remaining - 1.0)
	_update_time_ui()

func _check_game_over() -> void:
	if time_remaining <= 0.0:
		var win := _current_score() >= threshold
		game_over = true
		if ui.has_method("show_game_over"):
			ui.show_game_over(true, win)

func _update_score_ui() -> void:
	if ui and ui.has_method("set_score"):
		ui.set_score(_current_score())

func _update_time_ui() -> void:
	if ui and ui.has_method("set_time_ratio"):
		var ratio := (time_remaining / total_time) if total_time > 0.0 else 0.0
		ui.set_time_ratio(ratio)

func _current_score() -> int:
	if board and board.has_method("calc_score"):
		return board.calc_score()
	return 0

func _on_score_changed(_value: int) -> void:
	_update_score_ui()

func _on_restart() -> void:
	reset_game()

# --- Input Map helpers ---

func _ensure_input_map() -> void:
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("action", [KEY_SPACE])
	_ensure_action("toggle_action", [KEY_TAB])

func _ensure_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	# Add keys if not present
	var existing := InputMap.action_get_events(action_name)
	for key in keys:
		var already := false
		for ev in existing:
			if ev is InputEventKey and ev.physical_keycode == key:
				already = true
				break
		if not already:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action_name, e)

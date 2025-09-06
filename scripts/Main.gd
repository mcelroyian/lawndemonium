extends Node2D

@onready var board: TileMapLayer = $Board
@onready var player: Node2D = $Cursor
@onready var ui: CanvasLayer = $UI
@onready var turn_timer: Timer = $TurnTimer

var total_time: float = 180.0
var time_remaining: float = 180.0
var threshold: int = 5
var game_over: bool = false

# Debug overlay state
var debug_enabled: bool = false
var _debug_accum: float = 0.0

# Spawn rates are now driven by LevelConfig via Board auto-ticking.

func _ready() -> void:
	_ensure_input_map()
	# Drive the timer by time, not actions
	if turn_timer and not turn_timer.timeout.is_connected(_on_turn_timer_timeout):
		turn_timer.timeout.connect(_on_turn_timer_timeout)
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
	set_process(true)

func reset_game() -> void:
	game_over = false
	time_remaining = total_time
	# Configure and start the ticking timer
	if turn_timer:
		turn_timer.stop()
		# 0.25s ticks for smoother/faster updates (4x rate)
		turn_timer.wait_time = 0.25
		turn_timer.one_shot = false
		turn_timer.start()
	if board.has_method("randomize_start"):
		board.randomize_start()
	_update_score_ui()
	_update_time_ui()
	if ui.has_method("show_game_over"):
		ui.show_game_over(false, false)
	if ui.has_method("set_debug_visible"):
		ui.set_debug_visible(debug_enabled)

func _on_player_action(cell: Vector2i, action: String) -> void:
	if game_over:
		return
	if board.has_method("apply_player_action"):
		board.apply_player_action(cell, action)
	_update_score_ui()
	# Timer now advances with real time via TurnTimer
	_check_game_over()
	if ui.has_method("set_turn_text"):
		ui.set_turn_text(action.capitalize())

func _tick_time(amount: float) -> void:
	# Decrease remaining time by a given amount (seconds)
	time_remaining = max(0.0, time_remaining - amount)
	_update_time_ui()

func _check_game_over() -> void:
	if time_remaining <= 0.0:
		var win: bool = _current_score() >= threshold
		game_over = true
		if turn_timer:
			turn_timer.stop()
		if ui.has_method("show_game_over"):
			ui.show_game_over(true, win)

func _update_score_ui() -> void:
	if ui and ui.has_method("set_score"):
		ui.set_score(_current_score())

func _update_time_ui() -> void:
	if ui and ui.has_method("set_time_ratio"):
		var ratio: float = (time_remaining / total_time) if total_time > 0.0 else 0.0
		ui.set_time_ratio(ratio)

func _current_score() -> int:
	if board and board.has_method("calc_score"):
		return board.calc_score()
	return 0

func _on_score_changed(_value: int) -> void:
	_update_score_ui()

func _on_restart() -> void:
	reset_game()

func _on_turn_timer_timeout() -> void:
	if game_over:
		return
	# Tick down based on the timer's configured interval
	var amount: float = 1.0
	if turn_timer:
		# Make countdown 4x faster than before
		amount = 10.0 * turn_timer.wait_time
	_tick_time(amount)
	_check_game_over()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Toggle debug overlay with Ctrl
		if event.keycode == KEY_CTRL:
			debug_enabled = not debug_enabled
			if ui.has_method("set_debug_visible"):
				ui.set_debug_visible(debug_enabled)

func _process(delta: float) -> void:
	# Periodically refresh debug overlay
	if not debug_enabled:
		return
	_debug_accum += delta
	if _debug_accum >= 0.5:
		_debug_accum = 0.0
		_update_debug_overlay()

func _update_debug_overlay() -> void:
	if ui == null or not ui.has_method("set_debug_text"):
		return
	var lm := get_node_or_null("/root/LevelMgr")
	var level_idx: int = -1
	var cfg: LevelConfig = null
	if lm:
		if lm.has_method("get_config"):
			cfg = lm.call("get_config")
		if lm.has_method("get"):
			level_idx = int(lm.get("current"))

	var level_str := ("%d" % (level_idx + 1)) if level_idx >= 0 else "?"

	var weeds_per_sec := 0.0
	var grass_per_sec := 0.0
	if cfg and board:
		# Weed spawns per second (expected)
		var eligible: int = 0
		if board.has_method("count_eligible_weed_tiles"):
			eligible = board.count_eligible_weed_tiles()
		var spawn_per_tick := 0.0
		if cfg.weed_spawn_mode == "ratio":
			spawn_per_tick = float(ceil(float(eligible) * max(0.0, cfg.weed_spawn_ratio)))
		else:
			var chance := 0.0
			if cfg.weed_spawn_mode == "absolute":
				chance = max(0.0, cfg.weed_spawn_chance)
			elif cfg.weed_spawn_mode == "multiplier":
				chance = max(0.0, board.global_base_spawn_chance * cfg.weed_spawn_multiplier)
			spawn_per_tick = float(eligible) * chance
		weeds_per_sec = spawn_per_tick / max(0.001, cfg.weed_tick_interval_sec)

		# Grass changes per second (expected decay)
		var good_count := 0
		var ok_count := 0
		var gs: Vector2i = board.GRID_SIZE
		for y in range(gs.y):
			for x in range(gs.x):
				var id: int = board.get_tile(Vector2i(x, y))
				if id == board.GOOD:
					good_count += 1
				elif id == board.OK:
					ok_count += 1
		var change_per_tick: float = float(good_count) * clamp(cfg.p_good_to_ok, 0.0, 1.0) + float(ok_count) * clamp(cfg.p_ok_to_bad, 0.0, 1.0)
		grass_per_sec = change_per_tick / max(0.001, cfg.grass_tick_interval_sec)

	var text := "Level: %s\nWeeds/s: %.2f\nGrass/s: %.2f" % [level_str, weeds_per_sec, grass_per_sec]
	ui.set_debug_text(text)

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
	var existing: Array = InputMap.action_get_events(action_name)
	for key in keys:
		var already: bool = false
		for ev in existing:
			if ev is InputEventKey and ev.physical_keycode == key:
				already = true
				break
		if not already:
			var e: InputEventKey = InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action_name, e)

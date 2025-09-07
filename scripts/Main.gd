extends Node2D

@onready var playfield: Node2D = $Playfield
@onready var board: TileMapLayer = $Playfield/Board
@onready var player: Node2D = $Playfield/Cursor
@onready var ui: CanvasLayer = $UI
@onready var turn_timer: Timer = $TurnTimer

var total_time: float = 180.0
var time_remaining: float = 180.0
var threshold: int = 5
var game_over: bool = false
var _paused: bool = false

# Optional background image shown behind the playfield.
@export var background_texture_path: String = "res://assets/bd-background.png"
@export_range(0.0, 1.0, 0.01) var background_align_x: float = 0.0 # 0=left, 0.5=center, 1=right
@export_range(0.0, 1.0, 0.01) var background_align_y: float = 0.0 # 0=top, 0.5=center, 1=bottom
var _bg_layer: CanvasLayer
var _bg_sprite: Sprite2D

# Playfield layout
@export var playfield_auto_layout: bool = true
@export var playfield_margin_top: int = 16
@export var playfield_margin_right: int = 16

# Debug overlay state
var debug_enabled: bool = false
var _debug_accum: float = 0.0

# Spawn rates are now driven by LevelConfig via Board auto-ticking.

func _ready() -> void:
	_ensure_input_map()
	# Create a fullscreen background layer behind gameplay/UI if texture exists
	_ensure_background()
	# Ensure this node still processes input while tree is paused (Godot 4)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Children should pause normally even if parent is ALWAYS
	if board:
		board.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player:
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
	if turn_timer:
		turn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if ui:
		ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Drive the timer by time, not actions
	if turn_timer and not turn_timer.timeout.is_connected(_on_turn_timer_timeout):
		turn_timer.timeout.connect(_on_turn_timer_timeout)
	if player.has_signal("performed_action"):
		player.connect("performed_action", Callable(self, "_on_player_action"))
	if player.has_signal("action_changed"):
		player.connect("action_changed", Callable(self, "_on_player_action_changed"))
	if board.has_signal("score_changed"):
		board.connect("score_changed", Callable(self, "_on_score_changed"))
	if ui.has_signal("restart_pressed"):
		ui.connect("restart_pressed", Callable(self, "_on_restart"))
	# UI action buttons -> player action
	if ui.has_signal("action_selected"):
		ui.connect("action_selected", Callable(self, "_on_ui_action_selected"))
	# Reset timer whenever the level changes
	var lm := get_node_or_null("/root/LevelMgr")
	if lm and lm.has_signal("level_changed") and not lm.level_changed.is_connected(_on_level_changed):
		lm.level_changed.connect(_on_level_changed)
	# Ensure player uses Board's grid/tile sizes
	if player.has_method("configure"):
		player.configure(board.GRID_SIZE, board.TILE)
	# Auto-place playfield in top-right with margins
	_layout_playfield()
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_resized)
	reset_game()
	set_process(true)

func reset_game() -> void:
	game_over = false
	_set_paused(false)
	time_remaining = total_time
	# Configure and start the ticking timer
	if turn_timer:
		turn_timer.stop()
		# 0.25s ticks for smoother/faster updates (4x rate)
		turn_timer.wait_time = 0.25
		turn_timer.one_shot = false
		turn_timer.start()
	if board and board.has_method("set_auto_tick_enabled"):
		board.call("set_auto_tick_enabled", true)
	if board.has_method("randomize_start"):
		board.randomize_start()
	_update_score_ui()
	_update_time_ui()
	if ui.has_method("show_game_over"):
		ui.show_game_over(false, false)
	if ui.has_method("set_debug_visible"):
		ui.set_debug_visible(debug_enabled)
	# Ensure action UI starts in Mow
	if ui.has_method("set_active_action"):
		ui.set_active_action("mow")

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
	if ui.has_method("set_active_action"):
		ui.set_active_action(action)

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
		if board and board.has_method("set_auto_tick_enabled"):
			board.call("set_auto_tick_enabled", false)
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

func _on_ui_action_selected(action: String) -> void:
	if player and player.has_method("set_action"):
		player.call("set_action", action)
	if ui.has_method("set_turn_text"):
		ui.set_turn_text(action.capitalize())
	if ui.has_method("set_active_action"):
		ui.set_active_action(action)

func _on_level_changed(_index: int, _cfg: LevelConfig) -> void:
	# When a new level loads, give the player a fresh timer.
	game_over = false
	time_remaining = total_time
	_update_time_ui()
	if board and board.has_method("set_auto_tick_enabled"):
		board.call("set_auto_tick_enabled", true)
	if ui.has_method("show_game_over"):
		ui.show_game_over(false, false)

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
		# Pause/unpause with Escape
		if event.keycode == KEY_ESCAPE:
			_set_paused(not _paused)
			return
		# Toggle debug overlay with Ctrl
		if event.keycode == KEY_CTRL:
			debug_enabled = not debug_enabled
			if ui.has_method("set_debug_visible"):
				ui.set_debug_visible(debug_enabled)
	# If paused, ignore other processing triggers here

func _process(delta: float) -> void:
	# Periodically refresh debug overlay
	if _paused or not debug_enabled:
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

func _on_player_action_changed(action: String) -> void:
	# Keep UI highlight in sync when action changes via keyboard/UI
	if ui:
		if ui.has_method("set_turn_text"):
			ui.set_turn_text(action.capitalize())
		if ui.has_method("set_active_action"):
			ui.set_active_action(action)

func _set_paused(v: bool) -> void:
	_paused = v
	get_tree().paused = v
	if ui and ui.has_method("show_paused"):
		ui.show_paused(v)

# --- Background helper ---
func _ensure_background() -> void:
	if _bg_layer == null:
		_bg_layer = CanvasLayer.new()
		_bg_layer.layer = -100  # draw behind everything else
		add_child(_bg_layer)
	# Clean up older TextureRect variant if present
	var old: Node = _bg_layer.get_node_or_null("Background")
	if old:
		old.queue_free()
	if _bg_sprite != null:
		return
	if background_texture_path == "" or not ResourceLoader.exists(background_texture_path):
		return
	var tex: Texture2D = load(background_texture_path)
	if tex == null:
		return
	_bg_sprite = Sprite2D.new()
	_bg_sprite.name = "BackgroundSprite"
	_bg_sprite.texture = tex
	_bg_sprite.centered = false
	_bg_layer.add_child(_bg_sprite)
	_layout_background()

func _layout_background() -> void:
	if _bg_sprite == null or _bg_sprite.texture == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vs: Vector2 = Vector2(vp.get_visible_rect().size)
	var ts: Vector2 = _bg_sprite.texture.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var scale_factor: float = max(vs.x / ts.x, vs.y / ts.y)
	_bg_sprite.scale = Vector2(scale_factor, scale_factor)
	var scaled: Vector2 = ts * scale_factor
	var pos_x: float = (vs.x - scaled.x) * clamp(background_align_x, 0.0, 1.0)
	var pos_y: float = (vs.y - scaled.y) * clamp(background_align_y, 0.0, 1.0)
	_bg_sprite.position = Vector2(pos_x, pos_y)

# --- Layout helper ---
func _layout_playfield() -> void:
	if not playfield_auto_layout or playfield == null or board == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var size: Vector2i = vp.get_visible_rect().size
	var width: int = board.GRID_SIZE.x * board.TILE
	var height: int = board.GRID_SIZE.y * board.TILE
	var x: int = size.x - width - playfield_margin_right
	var y: int = playfield_margin_top
	playfield.position = Vector2(x, y)

func _on_viewport_resized() -> void:
	_layout_playfield()
	_layout_background()

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

extends CanvasLayer

signal restart_pressed
signal action_selected(action: String)
signal level_select_pressed
signal next_level_pressed

@onready var score_label: Label = $ScoreLabel
@onready var timer_bar: ProgressBar = $TimerBar
@onready var turn_label: Label = $TurnLabel
@onready var restart_button: Button = $RestartButton
@onready var debug_label: Label = $DebugLabel
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var game_over_overlay: ColorRect = $GameOverOverlay
@onready var mow_button: Button = $ActionButtons/MowButton
@onready var weed_button: Button = $ActionButtons/WeedButton
@onready var go_message_label: Label = $GameOverOverlay/Panel/VBox/MessageLabel
@onready var go_score_label: Label = $GameOverOverlay/Panel/VBox/ScoreLabel
@onready var go_restart_button: Button = $GameOverOverlay/Panel/VBox/Buttons/RestartButton
@onready var go_level_select_button: Button = $GameOverOverlay/Panel/VBox/Buttons/LevelSelectButton
@onready var go_next_level_button: Button = $GameOverOverlay/Panel/VBox/Buttons/NextLevelButton

func _ready() -> void:
    restart_button.pressed.connect(_on_restart)
    # Configure action buttons (square, toggled highlight, no art needed)
    if mow_button:
        mow_button.toggle_mode = true
        mow_button.custom_minimum_size = Vector2(48, 48)
        mow_button.pressed.connect(func(): _select_action("mow"))
    if weed_button:
        weed_button.toggle_mode = true
        weed_button.custom_minimum_size = Vector2(48, 48)
        weed_button.pressed.connect(func(): _select_action("pull"))
    set_score(0)
    set_time_ratio(1.0)
    show_game_over(false, false)
    if debug_label:
        debug_label.visible = false
    if pause_overlay:
        pause_overlay.visible = false
    if game_over_overlay:
        game_over_overlay.visible = false
    # Default selection
    set_active_action("mow")

func set_score(v: int) -> void:
    score_label.text = "Score: %d" % v

func set_time_ratio(ratio: float) -> void:
    timer_bar.value = clamp(ratio, 0.0, 1.0) * 100.0

func set_turn_text(t: String) -> void:
    turn_label.text = t

func set_active_action(action: String) -> void:
    # Highlight the active action by pressing its toggle button
    if mow_button:
        mow_button.button_pressed = (action == "mow")
        # Subtle color modulate for clarity
        mow_button.self_modulate = Color(1, 1, 1, 1) if mow_button.button_pressed else Color(1, 1, 1, 0.85)
    if weed_button:
        weed_button.button_pressed = (action == "pull")
        weed_button.self_modulate = Color(1, 1, 1, 1) if weed_button.button_pressed else Color(1, 1, 1, 0.85)

func show_game_over(visible: bool, won: bool) -> void:
    # New overlay similar to pause overlay with options
    if game_over_overlay:
        game_over_overlay.visible = visible
        if visible:
            # hook up buttons lazily
            if go_restart_button and not go_restart_button.pressed.is_connected(_on_restart):
                go_restart_button.pressed.connect(_on_restart)
            if go_level_select_button and not go_level_select_button.pressed.is_connected(_on_level_select):
                go_level_select_button.pressed.connect(_on_level_select)
            if go_next_level_button and not go_next_level_button.pressed.is_connected(_on_next_level):
                go_next_level_button.pressed.connect(_on_next_level)
    # Back-compat: keep old restart button hidden during overlay usage
    if restart_button:
        restart_button.visible = false
    # Set the message on the main turn label for visibility, too
    if visible:
        turn_label.text = ("You kept it tidy!" if won else "HOA is not amused…")

func _on_restart() -> void:
    emit_signal("restart_pressed")

func _on_level_select() -> void:
    emit_signal("level_select_pressed")

func _on_next_level() -> void:
    emit_signal("next_level_pressed")

func _select_action(action: String) -> void:
    set_active_action(action)
    emit_signal("action_selected", action)

func set_debug_visible(v: bool) -> void:
    if debug_label:
        debug_label.visible = v

func set_debug_text(t: String) -> void:
    if debug_label:
        debug_label.text = t

func show_paused(v: bool) -> void:
    if pause_overlay:
        pause_overlay.visible = v

func set_game_over_score(score: int) -> void:
    # Update overlay labels: message + score-dependent text
    if go_score_label:
        go_score_label.text = "Score: %d" % score
    if go_message_label:
        if score >= 0:
            go_message_label.text = "You beat the HOA inspector!"
        else:
            go_message_label.text = "You are being fined!"

extends CanvasLayer

signal restart_pressed
signal action_selected(action: String)

@onready var score_label: Label = $ScoreLabel
@onready var timer_bar: ProgressBar = $TimerBar
@onready var turn_label: Label = $TurnLabel
@onready var restart_button: Button = $RestartButton
@onready var debug_label: Label = $DebugLabel
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var mow_button: Button = $ActionButtons/MowButton
@onready var weed_button: Button = $ActionButtons/WeedButton

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
    restart_button.visible = visible
    if visible:
        turn_label.text = ("You kept it tidy!" if won else "HOA is not amused…")

func _on_restart() -> void:
    emit_signal("restart_pressed")

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

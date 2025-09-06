extends CanvasLayer

signal restart_pressed

@onready var score_label: Label = $ScoreLabel
@onready var timer_bar: ProgressBar = $TimerBar
@onready var turn_label: Label = $TurnLabel
@onready var restart_button: Button = $RestartButton
@onready var debug_label: Label = $DebugLabel

func _ready() -> void:
    restart_button.pressed.connect(_on_restart)
    set_score(0)
    set_time_ratio(1.0)
    show_game_over(false, false)
    if debug_label:
        debug_label.visible = false

func set_score(v: int) -> void:
    score_label.text = "Score: %d" % v

func set_time_ratio(ratio: float) -> void:
    timer_bar.value = clamp(ratio, 0.0, 1.0) * 100.0

func set_turn_text(t: String) -> void:
    turn_label.text = t

func show_game_over(visible: bool, won: bool) -> void:
    restart_button.visible = visible
    if visible:
        turn_label.text = ("You kept it tidy!" if won else "HOA is not amused…")

func _on_restart() -> void:
    emit_signal("restart_pressed")

func set_debug_visible(v: bool) -> void:
    if debug_label:
        debug_label.visible = v

func set_debug_text(t: String) -> void:
    if debug_label:
        debug_label.text = t

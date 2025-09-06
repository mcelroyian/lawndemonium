extends Control

@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton

func _ready() -> void:
    if start_button and not start_button.pressed.is_connected(_on_start):
        start_button.pressed.connect(_on_start)
    if quit_button and not quit_button.pressed.is_connected(_on_quit):
        quit_button.pressed.connect(_on_quit)

func _on_start() -> void:
    var lm := get_node_or_null("/root/LevelMgr")
    if lm and lm.has_method("set_level"):
        lm.call("set_level", 0)
    var err := get_tree().change_scene_to_file("res://scenes/Main.tscn")
    if err != OK:
        push_warning("Failed to load Main.tscn: %s" % str(err))

func _on_quit() -> void:
    get_tree().quit()


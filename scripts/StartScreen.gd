extends Control

@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var level_select: OptionButton = $Center/VBox/LevelRow/LevelSelect

var _selected_level: int = 0

func _ready() -> void:
    if start_button and not start_button.pressed.is_connected(_on_start):
        start_button.pressed.connect(_on_start)
    if quit_button and not quit_button.pressed.is_connected(_on_quit):
        quit_button.pressed.connect(_on_quit)
    _populate_levels()
    if level_select and not level_select.item_selected.is_connected(_on_level_selected):
        level_select.item_selected.connect(_on_level_selected)

func _on_start() -> void:
    var lm := get_node_or_null("/root/LevelMgr")
    if lm and lm.has_method("set_level"):
        lm.call("set_level", _selected_level)
    var err := get_tree().change_scene_to_file("res://scenes/Main.tscn")
    if err != OK:
        push_warning("Failed to load Main.tscn: %s" % str(err))

func _on_quit() -> void:
    get_tree().quit()

func _populate_levels() -> void:
    if level_select == null:
        return
    level_select.clear()
    _selected_level = 0
    var lm := get_node_or_null("/root/LevelMgr")
    var added: int = 0
    if lm:
        # Try to read the exported Array[LevelConfig]
        var count := 0
        if lm.has_method("get"):
            # In Godot 4, exported arrays can be accessed as properties
            var arr = lm.get("levels")
            if typeof(arr) == TYPE_ARRAY:
                count = arr.size()
                for i in range(count):
                    var cfg = arr[i]
                    var label := _level_label_from_config(cfg, i)
                    level_select.add_item(label, i)
                    added += 1
    # Fallback if no levels found
    if added == 0:
        for i in range(3):
            level_select.add_item("Level %d" % (i + 1), i)
            added += 1
    level_select.select(clamp(_selected_level, 0, max(0, added - 1)))

func _level_label_from_config(cfg, idx: int) -> String:
    # Prefer an explicit display_name if user adds it later
    if cfg and cfg.has_method("get") and cfg.get("display_name") != null and String(cfg.get("display_name")).length() > 0:
        return String(cfg.get("display_name"))
    # Derive from resource path if available; else default to index
    var base := "Level %d" % (idx + 1)
    if cfg and cfg.has_method("get"):
        var p = cfg.get("resource_path") if cfg.get("resource_path") != null else ""
        if typeof(p) == TYPE_STRING and String(p).length() > 0:
            var s: String = String(p)
            var file := s.get_file()
            var name := file.get_basename()
            if name.length() > 0:
                return name
    return base

func _on_level_selected(index: int) -> void:
    _selected_level = index

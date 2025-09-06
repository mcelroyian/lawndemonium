class_name LevelManager
extends Node

signal level_changed(index: int, config: LevelConfig)

@export var levels: Array[LevelConfig] = [] as Array[LevelConfig]
var current: int = 0

func _ready() -> void:
	# If no levels assigned in the editor, try to load defaults.
	if levels.is_empty():
		var defaults := [
			"res://levels/Level1Easy.tres",
			"res://levels/Level2Medium.tres",
			"res://levels/Level3AllBadNoWeeds.tres",
		]
		for p in defaults:
			var cfg := load(p)
			if cfg is LevelConfig:
				levels.append(cfg)

func get_config() -> LevelConfig:
	if current >= 0 and current < levels.size():
		return levels[current]
	# Fallback: return a default config so the game runs even if not set
	return LevelConfig.new()

func set_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	current = index
	emit_signal("level_changed", current, get_config())

func advance_level() -> void:
	if levels.is_empty():
		return
	var next: int = clamp(current + 1, 0, levels.size() - 1)
	if next != current:
		current = next
		emit_signal("level_changed", current, get_config())

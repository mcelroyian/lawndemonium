class_name LevelConfig
extends Resource

@export_enum("absolute", "multiplier", "ratio") var weed_spawn_mode: String = "absolute"

# When mode == "absolute": used directly as per-tile chance each weed tick
@export var weed_spawn_chance: float = 0.10

# When mode == "multiplier": final = global_base_spawn_chance * weed_spawn_multiplier
@export var weed_spawn_multiplier: float = 1.0

# When mode == "ratio": spawn ceil(eligible * weed_spawn_ratio) weeds each tick
@export var weed_spawn_ratio: float = 0.0

# Ticks and cooldowns
@export var weed_tick_interval_sec: float = 2.0
@export var weed_respawn_cooldown_sec: float = 6.0
@export var grass_tick_interval_sec: float = 3.0

# Grass decay probabilities per grass tick
@export var p_good_to_ok: float = 0.05
@export var p_ok_to_bad: float = 0.03

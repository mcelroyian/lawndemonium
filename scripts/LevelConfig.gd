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

# Grass regrowth probability per grass tick (mown -> grown)
@export var p_mown_to_grown: float = 0.05

# Initial board state overrides
# If true, start with every tile as BAD and no weeds
@export var start_all_bad: bool = false
# If >= 0, overrides initial weeds placed by Board.randomize_start()
@export var start_weed_count: int = -1
# If >= 0, overrides initial BAD tiles placed by Board.randomize_start()
@export var start_bad_count: int = -1

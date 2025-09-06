extends TileMapLayer

signal tile_changed(position: Vector2i, tile_id: int)
signal score_changed(score: int)

const GRID_SIZE: Vector2i = Vector2i(8, 8)
const TILE: int = 64

const BAD := 0
const OK := 1
const GOOD := 2
const WEED := 3 # kept for atlas lookup, not stored in ground tiles
const DIRT := 4

const SCORE_BAD := -1
const SCORE_OK := 0
const SCORE_GOOD := 1
const SCORE_WEED := -2

var tiles: Array = []
var _atlas_source_id: int = -1
var weed_mask: Array = [] # 2D bool array matching GRID_SIZE; true if weed present
var weed_block_until: Array = [] # 2D float array; timestamp until which weeds cannot respawn

# Timers for autonomous ticks
var _weed_timer := 0.0
var _grass_timer := 0.0
var _now := 0.0
var _was_perfect := false

@export var auto_tick_enabled: bool = true
@export var global_base_spawn_chance: float = 0.10

# Optional level configuration
@export var level_config: LevelConfig
var _active_config: LevelConfig
var _level_manager: Node

@export var weeds_layer_path: NodePath
@onready var weeds_layer: TileMapLayer = get_node_or_null(weeds_layer_path) as TileMapLayer
@export var weed_atlas_position: Vector2i = Vector2i(11, 7)

# Mapping from our logical tile ids -> atlas coordinates.
# Defaults to first 5 tiles on the top row. Configure in Inspector if desired.
@export var tile_atlas_positions: Array[Vector2i] = [
	Vector2i(0, 9), # BAD
	Vector2i(13, 11), # OK (unchanged; specify if different)
	Vector2i(0, 3), # GOOD
	Vector2i(0, 5), # WEED
	Vector2i(0, 0)  # DIRT
]

func _ready() -> void:
	_ensure_tileset()
	_init_grid()
	_redraw_all()
	_wire_level_config()
	set_process(auto_tick_enabled)

func set_auto_tick_enabled(v: bool) -> void:
	auto_tick_enabled = v
	set_process(v)

func _process(delta: float) -> void:
	if not auto_tick_enabled:
		return
	_now += delta
	var cfg: LevelConfig = _get_config()
	# Accumulate timers
	_weed_timer += delta
	_grass_timer += delta
	if _weed_timer >= cfg.weed_tick_interval_sec:
		_weed_timer = 0.0
		_tick_weeds(cfg)
	if _grass_timer >= cfg.grass_tick_interval_sec:
		_grass_timer = 0.0
		_tick_grass(cfg)

func _init_grid() -> void:
	tiles.resize(GRID_SIZE.y)
	for y in range(tiles.size()):
		tiles[y] = []
		tiles[y].resize(GRID_SIZE.x)
		for x in range(tiles[y].size()):
			tiles[y][x] = OK
	weed_mask.resize(GRID_SIZE.y)
	for y in range(weed_mask.size()):
		weed_mask[y] = []
		weed_mask[y].resize(GRID_SIZE.x)
		for x in range(GRID_SIZE.x):
			weed_mask[y][x] = false
	weed_block_until.resize(GRID_SIZE.y)
	for y in range(weed_block_until.size()):
		weed_block_until[y] = []
		weed_block_until[y].resize(GRID_SIZE.x)
		for x in range(GRID_SIZE.x):
			weed_block_until[y][x] = 0.0

func randomize_start(weed_count: int = 6, bad_count: int = 6) -> void:
	_init_grid()
	var cfg: LevelConfig = _get_config()

	# If level config requests a specific initial state, honor it.
	if cfg is LevelConfig:
		if cfg.start_all_bad:
			# All tiles BAD, no weeds
			for y in range(GRID_SIZE.y):
				for x in range(GRID_SIZE.x):
					set_tile(Vector2i(x, y), BAD)
					_set_weed(Vector2i(x, y), false)
			emit_signal("score_changed", calc_score())
			_redraw_all()
			_was_perfect = false
			return

		# Override counts if provided by config
		if cfg.start_weed_count >= 0:
			weed_count = cfg.start_weed_count
		if cfg.start_bad_count >= 0:
			bad_count = cfg.start_bad_count

	# Default/randomized start
	var coords: Array[Vector2i] = []
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			coords.append(Vector2i(x, y))
	coords.shuffle()
	for i in range(weed_count):
		if coords.is_empty():
			break
		var p: Vector2i = coords.pop_back()
		_set_weed(p, true)
	for i in range(bad_count):
		if coords.is_empty():
			break
		var p2: Vector2i = coords.pop_back()
		set_tile(p2, BAD)
	emit_signal("score_changed", calc_score())
	_redraw_all()
	_was_perfect = false
	
func grid_to_local(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE, p.y * TILE)

func is_in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < GRID_SIZE.x and p.y < GRID_SIZE.y

func get_tile(p: Vector2i) -> int:
	if not is_in_bounds(p):
		return -1
	return tiles[p.y][p.x]

func set_tile(p: Vector2i, id: int) -> void:
	if not is_in_bounds(p):
		return
	tiles[p.y][p.x] = id
	if _atlas_source_id != -1:
		var coord := tile_atlas_positions[id] if id >= 0 and id < tile_atlas_positions.size() else Vector2i(id, 0)
		set_cell(p, _atlas_source_id, coord)
	emit_signal("tile_changed", p, id)

func apply_player_action(p: Vector2i, action: String) -> bool:
	if not is_in_bounds(p):
		return false
	var t := get_tile(p)
	var changed := false
	if action == "pull":
		if weed_mask[p.y][p.x]:
			_set_weed(p, false)
			# Start a cooldown to prevent immediate re-spawn
			var cfg: LevelConfig = _get_config()
			weed_block_until[p.y][p.x] = _now + cfg.weed_respawn_cooldown_sec
			changed = true
	else:
		if t == BAD:
			set_tile(p, OK)
			changed = true
		elif t == OK:
			set_tile(p, GOOD)
			changed = true
	_check_advance_on_perfect()
	return changed

func apply_weed_rules(spawn_chance: float = 0.10) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p := Vector2i(x, y)
			var t := get_tile(p)
			if (t == BAD or t == OK) and not weed_mask[y][x]:
				# Respect cooldown
				if _now < weed_block_until[y][x]:
					continue
				if rng.randf() < spawn_chance:
					_set_weed(p, true)

func apply_weed_rules_ratio(ratio: float) -> void:
	# Spawn ceil(eligible * ratio) weeds by choosing random eligible positions.
	var eligible: Array[Vector2i] = []
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p := Vector2i(x, y)
			var t := get_tile(p)
			if (t == BAD or t == OK) and not weed_mask[y][x]:
				if _now >= weed_block_until[y][x]:
					eligible.append(p)
	if eligible.is_empty():
		return
	var spawn_count: int = int(ceil(float(eligible.size()) * max(0.0, ratio)))
	if spawn_count <= 0:
		return
	eligible.shuffle()
	for i in range(min(spawn_count, eligible.size())):
		_set_weed(eligible[i], true)

func apply_grass_decay(p_good_to_ok: float, p_ok_to_bad: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p := Vector2i(x, y)
			var t := get_tile(p)
			if t == GOOD and rng.randf() < clamp(p_good_to_ok, 0.0, 1.0):
				set_tile(p, OK)
			elif t == OK and rng.randf() < clamp(p_ok_to_bad, 0.0, 1.0):
				set_tile(p, BAD)

func calc_score() -> int:
	var s: int = 0
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			match tiles[y][x]:
				GOOD:
					s += SCORE_GOOD
				OK:
					s += SCORE_OK
				BAD:
					s += SCORE_BAD
			if weed_mask[y][x]:
				s += SCORE_WEED
	return s

func is_perfect() -> bool:
	# Consider the board "perfect enough" to advance when:
	#  - There are no weeds anywhere, and
	#  - There are no BAD tiles (OK and GOOD are allowed)
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if weed_mask[y][x]:
				return false
			if tiles[y][x] == BAD:
				return false
	return true

func _check_advance_on_perfect() -> void:
	var perfect := is_perfect()
	if perfect and not _was_perfect:
		_was_perfect = true
		if _level_manager and _level_manager.has_method("advance_level"):
			_level_manager.call("advance_level")
	elif not perfect:
		_was_perfect = false

func count_eligible_weed_tiles() -> int:
	# Eligible tiles are those that can become weeds per rules: BAD or OK
	var c: int = 0
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var t: int = tiles[y][x]
			if (t == BAD or t == OK) and not weed_mask[y][x]:
				c += 1
	return c

# --- Rendering helpers ---

func _ensure_tileset() -> void:
	# Prefer any TileSet assigned via the scene (Inspector).
	if tile_set != null:
		# Find the first atlas source and cache its id.
		var count := tile_set.get_source_count()
		for i in range(count):
			var sid := tile_set.get_source_id(i)
			var src := tile_set.get_source(sid)
			if src is TileSetAtlasSource:
				_atlas_source_id = sid
				break
	# If not found, fall back to a minimal generated tileset so the game still runs.
	if _atlas_source_id == -1:
		var colors: Array = [
			Color(0.55, 0.20, 0.20), # BAD - dull red/brown
			Color(0.30, 0.60, 0.30), # OK - green
			Color(0.10, 0.80, 0.10), # GOOD - bright green
			Color(0.45, 0.10, 0.55), # WEED - purple
			Color(0.45, 0.35, 0.25)  # DIRT - brown
		]
		var tile_count := colors.size()
		var atlas_img := Image.create(TILE * tile_count, TILE, false, Image.FORMAT_RGBA8)
		atlas_img.fill(Color(0,0,0,0))
		for i in range(tile_count):
			var tile_img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
			tile_img.fill(colors[i])
			atlas_img.blit_rect(tile_img, Rect2i(Vector2i.ZERO, Vector2i(TILE, TILE)), Vector2i(i * TILE, 0))
		var tex := ImageTexture.create_from_image(atlas_img)

		var atlas := TileSetAtlasSource.new()
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(TILE, TILE)
		for i in range(tile_count):
			atlas.create_tile(Vector2i(i, 0))

		var ts := TileSet.new()
		ts.tile_size = Vector2i(TILE, TILE)
		_atlas_source_id = ts.add_source(atlas)
		tile_set = ts

	# Ensure the weeds layer shares this tileset so atlas coords match
	if weeds_layer:
		if weeds_layer.tile_set == null:
			weeds_layer.tile_set = tile_set
		# In case weeds layer had a different tileset, replace to keep atlas ids aligned
		elif weeds_layer.tile_set != tile_set:
			weeds_layer.tile_set = tile_set

func _redraw_all() -> void:
	if _atlas_source_id == -1:
		return
	clear()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var id: int = tiles[y][x]
			var coord := tile_atlas_positions[id] if id >= 0 and id < tile_atlas_positions.size() else Vector2i(id, 0)
			set_cell(Vector2i(x, y), _atlas_source_id, coord)
	if weeds_layer:
		weeds_layer.clear()
		for y in range(GRID_SIZE.y):
			for x in range(GRID_SIZE.x):
				if weed_mask[y][x]:
					weeds_layer.set_cell(Vector2i(x, y), _atlas_source_id, weed_atlas_position)

func _set_weed(p: Vector2i, present: bool) -> void:
	if not is_in_bounds(p):
		return
	weed_mask[p.y][p.x] = present
	if weeds_layer and _atlas_source_id != -1:
		if present:
			weeds_layer.set_cell(p, _atlas_source_id, weed_atlas_position)
		else:
			weeds_layer.erase_cell(p)
	emit_signal("score_changed", calc_score())

# --- Level + ticking helpers ---

func _wire_level_config() -> void:
	# Prefer explicit export if set
	_active_config = level_config if level_config is LevelConfig else null
	# Try to obtain LevelManager from autoload if available
	_level_manager = get_node_or_null("/root/LevelMgr")
	if _level_manager and _level_manager.has_method("get_config"):
		_active_config = _level_manager.call("get_config")
		if _level_manager.has_signal("level_changed"):
			_level_manager.connect("level_changed", Callable(self, "_on_level_changed"))
	# Fallback to default
	if _active_config == null:
		_active_config = LevelConfig.new()

func _on_level_changed(_index: int, cfg: LevelConfig) -> void:
	_active_config = cfg
	_was_perfect = false

func _get_config() -> LevelConfig:
	return _active_config

func _compute_spawn_chance(cfg: LevelConfig) -> float:
	var mode := cfg.weed_spawn_mode
	if mode == "absolute":
		return max(0.0, cfg.weed_spawn_chance)
	elif mode == "multiplier":
		return max(0.0, global_base_spawn_chance * cfg.weed_spawn_multiplier)
	else:
		# ratio mode handled separately
		return 0.0

func _tick_weeds(cfg: LevelConfig) -> void:
	if cfg.weed_spawn_mode == "ratio":
		apply_weed_rules_ratio(cfg.weed_spawn_ratio)
	else:
		var chance := _compute_spawn_chance(cfg)
		apply_weed_rules(chance)

func _tick_grass(cfg: LevelConfig) -> void:
	apply_grass_decay(cfg.p_good_to_ok, cfg.p_ok_to_bad)

extends TileMapLayer

signal tile_changed(position: Vector2i, tile_id: int)
signal score_changed(score: int)

const GRID_SIZE: Vector2i = Vector2i(8, 8)
const TILE: int = 64

const GROWN := 0
const MOWN := 1
const WEED := 2 # kept for atlas lookup, not stored in ground tiles
const DIRT := 3

# Temporary aliases for transition period (can be removed once UI/text fully updated)
const BAD := GROWN
const GOOD := MOWN

const SCORE_BAD := -5
const SCORE_GOOD := 1
const SCORE_WEED := -5

var tiles: Array = []
var _atlas_source_id: int = -1
var _atlas_source_ids: Array[int] = [] # Ordered list of atlas source IDs (by source index)
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
	Vector2i(0, 0), # GROWN (grass-grown)
	Vector2i(0, 0), # MOWN  (grass-mown)
	Vector2i(0, 5), # WEED
	Vector2i(0, 0)  # DIRT
]

# Optional per-tile source selection (index into TileSet sources order).
# 0 = first atlas source, 1 = second, etc.
# Configure to use: source 2 = grass-grown, source 1 = grass-mown
@export var tile_atlas_sources: Array[int] = [
	2, # GROWN -> grass-grown (third atlas source)
	1, # MOWN  -> grass-mown  (second atlas source)
	0, # WEED
	0  # DIRT
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
			tiles[y][x] = GROWN
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
		if cfg.start_all_mown or cfg.start_all_bad:
			var make_mown := cfg.start_all_mown
			# Initialize uniform ground state, clear weeds
			for y in range(GRID_SIZE.y):
				for x in range(GRID_SIZE.x):
					set_tile(Vector2i(x, y), MOWN if make_mown else GROWN)
					_set_weed(Vector2i(x, y), false)
			# Place initial weeds if requested
			if cfg.start_weed_count >= 0:
				var eligible: Array[Vector2i] = []
				for y2 in range(GRID_SIZE.y):
					for x2 in range(GRID_SIZE.x):
						var p2 := Vector2i(x2, y2)
						if not weed_mask[y2][x2]:
							eligible.append(p2)
				eligible.shuffle()
				for i in range(min(cfg.start_weed_count, eligible.size())):
					_set_weed(eligible[i], true)
			emit_signal("score_changed", calc_score())
			_redraw_all()
			_was_perfect = false
			return

		# Override counts if provided by config (exact placements)
		var want_weed := cfg.start_weed_count
		var want_bad := cfg.start_bad_count
		var want_mown := cfg.start_mown_count

		if want_weed >= 0 or want_bad >= 0 or want_mown >= 0:
			# Start from a clean slate (all grown, no weeds), then place exact amounts
			for y in range(GRID_SIZE.y):
				for x in range(GRID_SIZE.x):
					set_tile(Vector2i(x, y), GROWN)
					_set_weed(Vector2i(x, y), false)
			var coords: Array[Vector2i] = []
			for y in range(GRID_SIZE.y):
				for x in range(GRID_SIZE.x):
					coords.append(Vector2i(x, y))
			coords.shuffle()

			# Place MOWN tiles
			if want_mown >= 0:
				for i in range(min(want_mown, coords.size())):
					var p: Vector2i = coords.pop_back()
					set_tile(p, MOWN)

			# Optionally place additional BAD tiles (kept as grown)
			if want_bad >= 0:
				# Ensure exactly want_bad GROWN tiles. Since default is all grown,
				# we only need to flip excess MOWN back or ensure count via flip order.
				# Simpler: if want_bad < total, ensure only (total - want_bad) are MOWN
				var total: int = GRID_SIZE.x * GRID_SIZE.y
				var target_mown: int = max(0, total - want_bad)
				# Adjust current mown count to target by flipping tiles
				var to_flip := 0
				# Count current MOWN
				var current_mown := 0
				for y2 in range(GRID_SIZE.y):
					for x2 in range(GRID_SIZE.x):
						if tiles[y2][x2] == MOWN:
							current_mown += 1
				if current_mown > target_mown:
					to_flip = current_mown - target_mown
					# Flip arbitrary MOWN back to GROWN
					for y2 in range(GRID_SIZE.y):
						for x2 in range(GRID_SIZE.x):
							if to_flip <= 0:
								break
							if tiles[y2][x2] == MOWN:
								set_tile(Vector2i(x2, y2), GROWN)
								to_flip -= 1
						if to_flip <= 0:
							break
				elif current_mown < target_mown:
					to_flip = target_mown - current_mown
					# Flip arbitrary GROWN to MOWN
					for y2 in range(GRID_SIZE.y):
						for x2 in range(GRID_SIZE.x):
							if to_flip <= 0:
								break
							if tiles[y2][x2] == GROWN:
								set_tile(Vector2i(x2, y2), MOWN)
								to_flip -= 1
						if to_flip <= 0:
							break

			# Place weeds last on eligible tiles without weeds
			if want_weed >= 0:
				var eligible: Array[Vector2i] = []
				for y2 in range(GRID_SIZE.y):
					for x2 in range(GRID_SIZE.x):
						var p2 := Vector2i(x2, y2)
						if not weed_mask[y2][x2]:
							eligible.append(p2)
				eligible.shuffle()
				for i in range(min(want_weed, eligible.size())):
					_set_weed(eligible[i], true)

			emit_signal("score_changed", calc_score())
			_redraw_all()
			_was_perfect = false
			return

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
		set_tile(p2, GROWN)
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
		var src_index: int = 0
		if id >= 0 and id < tile_atlas_sources.size():
			src_index = max(0, tile_atlas_sources[id])
		var src_id: int = _atlas_source_id
		if src_index >= 0 and src_index < _atlas_source_ids.size():
			src_id = _atlas_source_ids[src_index]
		set_cell(p, src_id, coord)
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
		# Mow once: GROWN -> MOWN; MOWN is no-op
		if t == GROWN:
			set_tile(p, MOWN)
			changed = true
	_check_advance_on_perfect()
	return changed

func apply_weed_rules(spawn_chance: float = 0.10) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cfg := _get_config()
	var eligible: Array[Vector2i] = []
	var any_weeds := false
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if weed_mask[y][x]:
				any_weeds = true
				break
		if any_weeds:
			break
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p: Vector2i = Vector2i(x, y)
			var t := get_tile(p)
			if not ((t == GROWN) or (t == MOWN)):
				continue
			if weed_mask[y][x]:
				continue
			if _now < weed_block_until[y][x]:
				continue
			var ok := true
			if cfg.weed_requires_adjacency:
				if any_weeds:
					ok = _has_adjacent_weed(p)
				else:
					ok = cfg.weed_seed_when_empty
			if ok:
				eligible.append(p)
	for p in eligible:
		if rng.randf() < spawn_chance:
			_set_weed(p, true)

func apply_weed_rules_ratio(ratio: float) -> void:
	# Spawn ceil(eligible * ratio) weeds by choosing random eligible positions.
	var eligible: Array[Vector2i] = []
	var cfg := _get_config()
	var any_weeds := false
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if weed_mask[y][x]:
				any_weeds = true
				break
		if any_weeds:
			break
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p: Vector2i = Vector2i(x, y)
			var t := get_tile(p)
			if not ((t == GROWN) or (t == MOWN)):
				continue
			if weed_mask[y][x]:
				continue
			if _now < weed_block_until[y][x]:
				continue
			var ok := true
			if cfg.weed_requires_adjacency:
				if any_weeds:
					ok = _has_adjacent_weed(p)
				else:
					ok = cfg.weed_seed_when_empty
			if ok:
				eligible.append(p)
	if eligible.is_empty():
		return
	var spawn_count: int = int(ceil(float(eligible.size()) * max(0.0, ratio)))
	if spawn_count <= 0:
		return
	eligible.shuffle()
	for i in range(min(spawn_count, eligible.size())):
		_set_weed(eligible[i], true)

func apply_grass_decay(p_mown_to_grown: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p := Vector2i(x, y)
			var t := get_tile(p)
			if t == MOWN and rng.randf() < clamp(p_mown_to_grown, 0.0, 1.0):
				set_tile(p, GROWN)

func calc_score() -> int:
	var s: int = 0
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			match tiles[y][x]:
				MOWN:
					s += SCORE_GOOD
				GROWN:
					s += SCORE_BAD
			if weed_mask[y][x]:
				s += SCORE_WEED
	return s

func is_perfect() -> bool:
	# Consider the board "perfect enough" to advance when:
	#  - There are no weeds anywhere, and
	#  - There are no GROWN tiles
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if weed_mask[y][x]:
				return false
			if tiles[y][x] == GROWN:
				return false
	return true

func _check_advance_on_perfect() -> void:
	var perfect := is_perfect()
	if perfect and not _was_perfect:
		_was_perfect = true
		# Instead of jumping levels immediately, signal the main flow to end the level now
		# by fast-forwarding the timer to 0. Main.gd handles NPC/overlay consistently.
		var main := get_tree().get_first_node_in_group("MainRoot")
		if main == null:
			var current := get_tree().current_scene
			if current:
				main = current.get_node_or_null("Main")
			if main == null:
				main = get_node_or_null("/root/Main")
		if main and main.has_method("force_end_now"):
			main.call("force_end_now")
		else:
			# Fallback: advance level directly if no handler is present
			if _level_manager and _level_manager.has_method("advance_level"):
				_level_manager.call("advance_level")
	elif not perfect:
		_was_perfect = false

func count_eligible_weed_tiles() -> int:
	# Eligible tiles are those that can become weeds under current config
	var cfg := _get_config()
	var any_weeds := false
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if weed_mask[y][x]:
				any_weeds = true
				break
		if any_weeds:
			break
	var c: int = 0
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p: Vector2i = Vector2i(x, y)
			var t: int = tiles[y][x]
			if not ((t == GROWN) or (t == MOWN)):
				continue
			if weed_mask[y][x]:
				continue
			if _now < weed_block_until[y][x]:
				continue
			var ok := true
			if cfg.weed_requires_adjacency:
				if any_weeds:
					ok = _has_adjacent_weed(p)
				else:
					ok = cfg.weed_seed_when_empty
			if ok:
				c += 1
	return c

func _has_adjacent_weed(p: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var q: Vector2i = p + d
		if is_in_bounds(q) and weed_mask[q.y][q.x]:
			return true
	return false

# --- Rendering helpers ---

func _ensure_tileset() -> void:
	# Prefer any TileSet assigned via the scene (Inspector).
	if tile_set != null:
		# Find the first atlas source and cache its id.
		var count := tile_set.get_source_count()
		_atlas_source_ids.clear()
		for i in range(count):
			var sid := tile_set.get_source_id(i)
			var src := tile_set.get_source(sid)
			if src is TileSetAtlasSource:
				_atlas_source_ids.append(sid)
		if _atlas_source_ids.size() > 0:
			_atlas_source_id = _atlas_source_ids[0]
	# If not found, fall back to a minimal generated tileset so the game still runs.
	if _atlas_source_id == -1:
		var colors: Array = [
			Color(0.30, 0.60, 0.30), # GROWN - green
			Color(0.10, 0.80, 0.10), # MOWN  - bright green
			Color(0.45, 0.10, 0.55), # WEED  - purple
			Color(0.45, 0.35, 0.25)  # DIRT  - brown
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
		_atlas_source_ids = [_atlas_source_id]
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
			var src_index: int = 0
			if id >= 0 and id < tile_atlas_sources.size():
				src_index = max(0, tile_atlas_sources[id])
			var src_id: int = _atlas_source_id
			if src_index >= 0 and src_index < _atlas_source_ids.size():
				src_id = _atlas_source_ids[src_index]
			set_cell(Vector2i(x, y), src_id, coord)
	if weeds_layer:
		weeds_layer.clear()
		for y in range(GRID_SIZE.y):
			for x in range(GRID_SIZE.x):
				if weed_mask[y][x]:
					var weed_src_index: int = 0
					if WEED >= 0 and WEED < tile_atlas_sources.size():
						weed_src_index = max(0, tile_atlas_sources[WEED])
					var weed_src_id: int = _atlas_source_id
					if weed_src_index >= 0 and weed_src_index < _atlas_source_ids.size():
						weed_src_id = _atlas_source_ids[weed_src_index]
					weeds_layer.set_cell(Vector2i(x, y), weed_src_id, weed_atlas_position)

func _set_weed(p: Vector2i, present: bool) -> void:
	if not is_in_bounds(p):
		return
	weed_mask[p.y][p.x] = present
	if weeds_layer and _atlas_source_id != -1:
		if present:
			var weed_src_index: int = 0
			if WEED >= 0 and WEED < tile_atlas_sources.size():
				weed_src_index = max(0, tile_atlas_sources[WEED])
			var weed_src_id: int = _atlas_source_id
			if weed_src_index >= 0 and weed_src_index < _atlas_source_ids.size():
				weed_src_id = _atlas_source_ids[weed_src_index]
			weeds_layer.set_cell(p, weed_src_id, weed_atlas_position)
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
	apply_grass_decay(cfg.p_mown_to_grown)

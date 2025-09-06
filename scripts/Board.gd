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

func randomize_start(weed_count: int = 6, bad_count: int = 6) -> void:
	_init_grid()
	var coords: Array[Vector2i] = []
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			coords.append(Vector2i(x, y))
	coords.shuffle()
	for i in range(weed_count):
		var p: Vector2i = coords.pop_back()
		_set_weed(p, true)
	for i in range(bad_count):
		var p2: Vector2i = coords.pop_back()
		set_tile(p2, BAD)
	emit_signal("score_changed", calc_score())
	_redraw_all()
	
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
			changed = true
	else:
		if t == BAD:
			set_tile(p, OK)
			changed = true
		elif t == OK:
			set_tile(p, GOOD)
			changed = true
	return changed

func apply_weed_rules(spawn_chance: float = 0.10) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var p := Vector2i(x, y)
			var t := get_tile(p)
			if (t == BAD or t == OK) and not weed_mask[y][x]:
				if rng.randf() < spawn_chance:
					_set_weed(p, true)

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

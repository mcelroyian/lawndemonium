# Leaf It to Thumb — Project Docs

## Overview
- Goal: 2D, turn-based, 8×8 lawn-care game shipped for web.
- Engine: Godot 4.x (GDScript). Main scene is `scenes/Main.tscn`.
- Visuals: Placeholder runtime-generated tiles; minimal UI.

## Layout
- `project.godot`: Godot project settings (main scene points to `scenes/Main.tscn`).
- `scenes/Main.tscn`: Root scene containing gameplay nodes.
- `scripts/`
  - `Main.gd`: Orchestration, input map bootstrap, timer, win/lose.
  - `Board.gd`: Grid state, rules, scoring, runtime TileSet + drawing.
  - `Player.gd`: Cursor movement + action dispatch; draws selection box.
  - `UI.gd`: Score/timer/restart UI utilities.
- `assets/`: Placeholder notes and space for art.

## Node Tree (at runtime)
- `Main (Node2D)`
  - `Board (TileMapLayer)` — 8×8 grid, draws tiles
  - `Cursor (Node2D)` — visible yellow selection box
  - `UI (CanvasLayer)` — `ScoreLabel`, `TimerBar`, `TurnLabel`, `RestartButton`
  - `SFX (AudioStreamPlayer)` — reserved
  - `TurnTimer (Timer)` — reserved

## Key Mechanics
- Grid size: `Vector2i(8,8)`; tile size: `TILE = 64` (see `scripts/Board.gd:7`).
- Actions: mow/pull (Space to act, Tab to toggle label text only; action auto-contextual).
- Turn flow: action → weed rules → score update → time tick → win/lose check.
- Scoring: GOOD=+1, OK=0, BAD=-1, WEED=-2 (see `Board.gd`).
- Timer: decremented by 1 per action; win if `score >= threshold` when time reaches 0.

## Rendering Strategy
- No external TileSet resource yet. `Board.gd` generates a simple colored atlas at runtime:
  - BAD (dull red), OK (green), GOOD (bright green), WEED (purple), DIRT (brown).
  - Calls `TileMapLayer.set_cell(pos, atlas_source, atlas_coords)` on tile updates.
- The `Cursor` draws a yellow rectangle using `_draw()` so the active cell is visible.

## Input Mapping (programmatic)
- `Main.gd` bootstraps the Input Map on startup so the game works without manual editor setup.
- Actions defined:
  - `move_up` (W, Up), `move_down` (S, Down), `move_left` (A, Left), `move_right` (D, Right)
  - `action` (Space), `toggle_action` (Tab)
- If you want to add controller input, extend `_ensure_input_map()` in `scripts/Main.gd:83`.

## Configuration Touchpoints
- `scripts/Board.gd`
  - `GRID_SIZE`, `TILE`, score constants, weed spawn chance in `apply_weed_rules()`.
  - `randomize_start(weed_count, bad_count)` controls initial layout.
- `scripts/Main.gd`
  - `total_time`, `threshold` for win condition.
  - `_ensure_input_map()` to add bindings.
- `scripts/Player.gd`
  - `configure(grid, tile)` keeps cursor size in sync with board.

## Run/Debug
1. Open Godot 4 and load the project folder.
2. Press Play to run `scenes/Main.tscn`.
3. Controls: WASD/Arrows to move, Space to act, Tab to toggle action label.

## Known Issues & Resolutions
- Node warning: "TileMap is deprecated; use TileMapLayer"
  - Cause: Godot 4.3 deprecates `TileMap` in favor of `TileMapLayer` nodes.
  - Fix: Scene changed to `TileMapLayer` and `Board.gd` now extends `TileMapLayer` and uses the 3‑argument `set_cell()` (no layer index).
- Parse error: “Expected parameter name” (Main.gd)
  - Cause: Using `_` as a discarded parameter with strict typing.
  - Fix: Name it `_value` (see `scripts/Main.gd:75`).
- Variant inference warnings treated as errors (Player.gd, Board.gd)
  - Cause: Untyped Arrays lead to Variant values; `:=` could not infer static type.
  - Fixes:
    - Typed locals explicitly, e.g., `var nx: int`, `var id: int`.
    - Replaced integer iteration like `for i in count` with `for i in range(count)`.
- Mixed tabs/spaces indentation (Main.gd)
  - Symptom: “Used tab character for indentation instead of space as used before.”
  - Fix: Convert file to spaces-only.
- Blank board at runtime
  - Cause: No TileSet assigned to TileMap.
  - Fix: `Board.gd` now generates a runtime TileSet and draws all cells in `_redraw_all()`.
- WASD didn’t work initially
  - Cause: No Input Map actions defined.
  - Fix: `_ensure_input_map()` adds actions and keys on startup.

## Suggested Next Steps
- Center the board and use a fixed 640×640 window for a tighter presentation.
- Save the generated TileSet as a `.tres` resource so visuals are editable in-editor.
- Add UI label for current action mode and a simple tutorial overlay.
- Web export: add an HTML5 preset and test on itch.io; avoid threads/shaders.
- Type the grid fully as `Array[Array[int]]` for stronger static checks and fewer Variant issues.

## Quick File Pointers
- scenes/Main.tscn:1
- scripts/Main.gd:1
- scripts/Board.gd:1
- scripts/Player.gd:1
- scripts/UI.gd:1

---
If you need more detail on any subsystem, check the script headers above. The code is intentionally lean to keep the 24‑hour scope tight.

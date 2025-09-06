# Leaf It to Thumb — Agents Guide

A minimal overview of the project structure and runtime architecture to help quickly orient contributors and tools.

## What This Is
- 2D, turn-based, 8×8 lawn-care game targeting web.
- Engine: Godot 4.x (GDScript). Main scene: `scenes/Main.tscn`.
- Visuals: runtime-generated tiles; minimal UI, no external TileSet yet.

## Architecture At A Glance
- Scene-first architecture with a thin orchestrator (`Main.gd`) delegating to focused scripts.
- Board-centric gameplay: `Board.gd` owns grid state, rules, scoring, and rendering.
- Player input decoupled via a cursor node (`Player.gd`) emitting actions/signals.
- UI (`UI.gd`) pulls state via simple setters; no game logic inside UI.
- Timing via a `Timer` node; gameplay advances on timer ticks rather than per-input.

## Runtime Node Tree
- `Main (Node2D)`
  - `Board (TileMapLayer)` — owns 8×8 grid; draws tiles; applies rules
  - `Cursor (Node2D)` — selection box; emits `performed_action(cell, action)`
  - `UI (CanvasLayer)` — Score/Timer/Turn/Restart + optional debug overlay
  - `SFX (AudioStreamPlayer)` — reserved
  - `TurnTimer (Timer)` — drives real-time tick

## Core Scripts & Responsibilities
- `scripts/Main.gd` — bootstraps input map, wires signals, manages timer, win/lose, and restarts.
- `scripts/Board.gd` — grid data, runtime TileSet generation, weed/grass rules, scoring, drawing.
- `scripts/Player.gd` — cursor movement (WASD/Arrows), action toggle (mow/pull), emits actions.
- `scripts/UI.gd` — score/time/turn label updates, restart button, optional debug text.
- `scripts/LevelConfig.gd` — tunable spawn/decay settings; used by `Board.gd`.

## Game/Turn Loop (High-Level)
1. `TurnTimer` timeout fires at a fixed interval.
2. `Main.gd` decreases remaining time and checks win/lose against `threshold`.
3. `Board.gd` advances rules (weed spawn, grass decay) based on `LevelConfig` timing.
4. Player input triggers contextual action at the cursor (mow/pull) via `Board.gd`.
5. UI updates score/time each tick or on score change.

## Rendering
- `Board.gd` builds a simple colored atlas at runtime and uses `TileMapLayer.set_cell()`.
- Tile categories: BAD, OK, GOOD, WEED, DIRT (scoring weights in `Board.gd`).
- Cursor draws a yellow rectangle via `_draw()` for active cell highlighting.

## Input (Programmatic)
- Bootstrapped in `Main.gd` to avoid editor-side setup.
- Actions: `move_up/down/left/right` (WASD/Arrows), `action` (Space), `toggle_action` (Tab).

## Configuration Touchpoints
- Board: `GRID_SIZE`, `TILE`, score constants; `randomize_start()` for initial layout.
- Level Tuning: `scripts/LevelConfig.gd` + `levels/*.tres` control spawn/decay:
  - `weed_spawn_mode` (e.g., "absolute"), `weed_spawn_chance`, `weed_tick_interval_sec`,
    `weed_respawn_cooldown_sec`, `grass_tick_interval_sec`, `p_good_to_ok`, `p_ok_to_bad`.
- Main: `total_time`, `threshold` for win condition; `_ensure_input_map()` for bindings.
- Player: `configure(grid, tile)` keeps cursor sizing in sync with board.

## Run/Debug
1. Open the folder in Godot 4 and run `scenes/Main.tscn` (Project → Play).
2. Controls: WASD/Arrows to move, Space to act, Tab to toggle action label.
3. Debug overlay: toggle with Ctrl (shows level and expected spawn/change rates).

## Notes & Gotchas
- Use `TileMapLayer`, not `TileMap` (Godot 4.3 deprecation).
- Types: prefer typed arrays/locals to avoid Variant inference issues.
- Timer-driven flow: gameplay advances with real time via `TurnTimer` ticks.

## Type Hygiene (GDScript)
- Prefer explicit local types when inference is ambiguous. Example fixes from recent errors:
  - `var id: int = board.get_tile(Vector2i(x, y))`
  - `var change_per_tick: float = float(good_count) * clamp(cfg.p_good_to_ok, 0.0, 1.0) + float(ok_count) * clamp(cfg.p_ok_to_bad, 0.0, 1.0)`
- Use typed arrays and containers: `var eligible: Array[Vector2i] = []`, `var tiles: Array[Array[int]]`.
- Avoid `:=` when the right-hand side isn’t statically typed. Either:
  - Declare the variable type explicitly: `var v: float = some_calc()`; or
  - Cast the value: `var v := float(some_calc())` when the function returns Variant.
- Give parameters and returns explicit types in functions and signals.
- Don’t use a bare `_` as a parameter name in strict typing; prefer `_value: int` or similar.

## Indentation Discipline
- Use a single style consistently: tabs OR 4 spaces across all `.gd` files. This project currently uses tabs.
- Keep block levels consistent; mismatched indents cause parser errors like “Unindent doesn't match the previous indentation level” or “Unexpected identifier … in class body”.
- Avoid mixing tabs and spaces in the same file. If you copy code, normalize indentation (Editor → Convert Indentations to Tabs/Spaces).
- After nested loops/ifs, ensure dedent aligns back to the parent block before continuing statements.
- Editor settings (recommended): set indent type to Tabs, indent size 4, show invisible characters, and enable “Convert indentation on save”.

## Quick File Pointers
- `scenes/Main.tscn`
- `scripts/Main.gd`
- `scripts/Board.gd`
- `scripts/Player.gd`
- `scripts/UI.gd`
- `scripts/LevelConfig.gd`

For deeper details, see `projectDocs.md`.

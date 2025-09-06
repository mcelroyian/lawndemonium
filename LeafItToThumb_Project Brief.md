# Product Requirements Document — *Leaf It to Thumb*

## 1) Overview
**Elevator pitch:**  
*“Be a harried, time-crunched homeowner desperately trying to tame a rebellious yard before the HOA cracks down.”*  

**Theme:** *Plants with attitude: Leaf It to Thumb*  

**Tone & fantasy:**  
The player is stressed and scrambling, wrestling against fast-growing weeds and the looming HOA deadline. The experience is humorous but urgent — lighthearted visuals with pressure baked in.  

---

## 2) Goals & Non-Goals
**Goals:**  
- Create a playable 2D grid-based lawn-care game shippable in 24 hours.  
- Deliver a tight loop (mow, pull weeds) with clear HOA pressure.  
- Ensure sessions last 2–4 minutes and end cleanly with win/lose feedback.  

**Non-Goals:**  
- Multiple levels, saves, or complex progression.  
- Advanced visuals or audio beyond placeholders.  
- Complex plant AI or inspector pathfinding.  

---

## 3) Target & Tech
- **Platform:** Web (itch.io)  
- **Engine:** Godot 4.x  
- **Language:** GDScript  
- **Performance targets:** Single screen (8×8 grid), ≤200 nodes.  
- **Dependencies:** None outside stock Godot.  

---

## 4) Core Loop & Progression
**Core Loop (1 sentence):**  
*“On each turn, the player mows or pulls weeds to improve the lawn while the timer ticks down; survive until time runs out.”*  

**Turn structure:**  
1. Player moves cursor and acts (mow or pull).  
2. Weeds may spawn/spread.  
3. Score recalculated.  
4. Timer ticks down.  
5. Check win/lose conditions.  

**Win condition:** Maintain score above threshold until timer ends.  
**Lose condition:** Score below threshold when timer expires.  
**Session length target:** 2–4 minutes.  

---

## 5) Mechanics (Minimal Set)
- **Player actions (2):** Mow, Pull Weed.  
- **Tile states:** 0–2 (bad, ok, good).  
- **Plants (1):** Punk Weed (spawns quickly, easy to remove).  
- **HOA pressure:** Timer bar with inspector icon advancing.  
- **Randomness:** Small chance of weed spawn each turn.  

---

## 6) Content Budget
**Must-Haves:**  
- Tileset (6–10): grass (bad/ok/good), weed, dirt, boundary, cursor, UI icon.  
- Sprites: player cursor, HOA inspector icon, punk weed.  
- UI: score label, HOA timer bar, restart button.  
- Text: title + one-screen tutorial (3 lines).  

**Nice-to-Haves:**  
- Basic sprites for lawn/weed instead of flat tiles.  
- Simple inspector patrol animation.  

**Cut Order:**  
1. Extra weed types  
2. Polish/juice (particles, animations, screen shake)  
3. Cutscenes  
4. Audio (SFX, music)  

---

## 7) UX & UI
- **Controls:** Keyboard only (WASD/arrows to move, Space = action, Tab to toggle if needed).  
- **HUD:** Score label, timer bar (with inspector icon), restart button.  
- **Tutorial:** One screen, 3 lines max (e.g., “Arrows move. Space acts. Keep lawn nice until timer ends.”).  

---

## 8) Level & Balancing
- **Grid size:** 8×8, 32px tiles.  
- **Start configuration:** Mostly ok tiles, a few weeds.  
- **Threshold:** Player must maintain score ≥N (tuned in balancing).  
- **Weed spawn:** ~10% chance per turn.  
- **Timer:** 2–4 minutes total.  

---

## 9) Technical Plan (Godot)
**Node Tree:**  
- Main (Node2D)  
  - Board (TileMap)  
  - Cursor (Node2D + Sprite2D)  
  - UI (CanvasLayer) → ScoreLabel, TimerBar, TurnLabel, RestartButton  
  - SFX (AudioStreamPlayer, unused initially)  
  - TurnTimer (Timer)  

**Scripts:**  
- Game.gd — state, score, timer, win/lose.  
- Board.gd — grid, tiles, apply weed rules.  
- Player.gd — cursor movement, action.  
- UI.gd — labels, timer bar, restart.  
- Main.gd — orchestrates reset, connects signals.  

**Signals:**  
- `tile_changed`, `weed_changed`, `score_changed`, `time_changed`, `game_over`.  

**Pseudocode:**  
- On action: update tile, apply rules, recalc score, decrement timer, check win/lose.  

---

## 10) Schedule (≤24h)
**Locked Schedule (23.5h):**  
1. Project setup — 0.5h  
2. Placeholder tileset & TileMap — 0.5h  
3. Core mechanics pass — 4h  
4. HUD pass — 1h  
5. Balance baseline — 1h  
6. Bugfix pass #1 — 1.5h  
7. Playtest loop #1 — 0.5h  
8. Visual clarity polish — 0.5h  
9. Bugfix pass #2 — 1h  
10. Web export pipeline — 1.5h  
11. Stretch buffer (sprite or extra weed) — 2h  
12. Polish & playtesting — 4h  
13. Submission prep (screenshots, copy) — 1.5h  
14. Contingency buffer — 4h  

---

## 11) Assets & Submission
- **Placeholders:** flat color tiles, simple rectangles.  
- **Stretch:** basic sprite art for weeds/lawn/inspector.  
- **Export:** HTML5 build → itch.io page.  
- **Page assets:** title, screenshots, short description, controls list.  

---

## 12) Stretch Goals (safe cuts)
1. Extra weed types (vine, stinkweed, dandelion).  
2. Visual polish/juice.  
3. Intro/outro cutscenes.  
4. Audio (SFX + loop).  

---

## Acceptance Criteria
- Playable build.  
- Finishable in ≤4 minutes.  
- No crashes on restart.  
- Tutorial text present.  
- HOA pressure (timer bar with inspector icon) visible.  

---

## Cutline Recap
If time slips: cut (1) extra weed types → (2) polish/juice → (3) cutscenes → (4) audio.  

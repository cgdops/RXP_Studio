# Changelog

## [1.0.1] - 2026-10-20

### Added
- **Live Recorder HUD Close Button (`[X]`)**:
  - Added a top-right `[X]` close button on the Live Recorder HUD window (`RXPStudioLiveHUD`) so players who aren't actively recording or writing a guide can dismiss the HUD (and automatically pause background event capture) with a single click.

### Fixed
- **Live RXPGuides Objective Progress Tracking (`.complete`)**:
  - Fixed a bug in `RXPCompiler.lua` where `.complete` lines were compiled with a literal `>>7/7 Objective` display override (`element.rawtext`), which caused `RXPGuides` to display static completed counts (`7/7`, `10/10`) instead of live quest log progress (`0/7`, `1/7`, etc.).
  - Updated `RXPCompiler.lua` to emit standard `.complete <questId>,<objIndex> --<objText>` syntax so `RXPGuides` dynamically reads and updates live `GetQuestLogLeaderBoard` counters as items are looted or mobs are slain.
  - Updated `RXPBridge.lua` to normalize pre-registered `RXPCData.questObjectivesCache` entries to `0/<max>` (`numFulfilled = 0`, `finished = false`) so unaccepted or previewed quests never display baked-in completion numbers.

## [1.0.0] - 2026-10-20

### Added
- **3-Column Visual Guide Studio (`/rxpstudio` / `/rxps`)**:
  - **Left Column (Visual Step Timeline)**: Scrollable step cards with one-click `[Up]`, `[Down]`, `[Merge Down]`, `[Split]`, `[Del]`, and `[Auto-Fix]` controls, plus batch `[Auto-Merge All]` and `[Auto-Fix All Issues]`.
  - **Center Column (Card Inspector)**: Visual action row builder supporting `accept`, `turnin`, `complete`, `trainer`, `vendor`, `hs`, `home`, `fly`, `fp`, `deathskip`, `xp`, `use`, and `note` actions, plus `[Sticky]`, `[Loop]`, coordinate capture (`[Use My Pos]`), target capture (`[+Target]`), and raw RXP syntax mode.
  - **Right Column (Zone Map Preview)**: Interactive 2D route canvas plotting all waypoints in the selected zone with numbered pins, path connectors, and click-to-reposition coordinate editing.
- **Compact Live Recorder HUD (`/rxprec` / `/rxprecorder`)**:
  - Real-time 3-card feed displaying recorded steps as you play, with quick-action buttons (`[+Note]`, `[Grind XP]`, `[Hearth/Bind]`, `[Deathskip]`, `[Pin Pos]`) and instant `[Sticky]` / `[Split]` toggles.
- **Smart Auto-Merger & Route Linter**:
  - Automatically coalesces consecutive actions at the same NPC or within proximity thresholds into unified RXP steps.
  - Validates quest lifecycle ordering (orphaned turn-ins, missing accepts, duplicate steps, out-of-bounds coordinates) with one-click auto-remediation.
- **Bi-Directional RXPCompiler & Live RXPGuides Bridge**:
  - Compiles structured visual cards into 100% compliant RestedXP syntax (`.accept`, `.turnin`, `.complete`, `.goto`, `.target`, `.hs`, `.home`, `.fly`, `.fp`, `.trainer`, `.vendor`, `.xp`, `.use`, `#sticky`, `#loop`).
  - Parses existing `RXPGuides.RegisterGuide([[...]])` scripts back into visual cards.
  - Hot-reloads guides directly into `RXPGuides` in-game via `[Test Live in RXP]` without requiring a `/reload` or external text editor.
- **Legacy `RXP_RecorderDB` Migration**:
  - Seamless one-click import of recorded runs from `RXP_RecorderDB`.

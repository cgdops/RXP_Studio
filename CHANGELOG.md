# Changelog

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

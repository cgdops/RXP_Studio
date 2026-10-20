<p align="center">
  <img src="icon.png" width="160" alt="RXP Guide Studio Icon" />
</p>

<h1 align="center">RXP Guide Studio</h1>

<p align="center">
  <strong>In-game visual speed-leveling guide recorder, card editor, route linter, and live RestedXP (RXPGuides) bridge for World of Warcraft.</strong>
</p>

---

## ✨ Overview

**RXP Guide Studio** (`RXP_Studio`) is a complete in-game IDE for creating, recording, editing, validating, and live-testing **RestedXP (`RXPGuides`)** leveling guides without ever leaving World of Warcraft or writing raw syntax by hand.

As you play through your leveling route, the **Live Recorder HUD** captures quest accepts, objective completions, turn-ins, NPC targets, coordinates, flight paths, trainers, vendors, hearthstones, and deathskips—automatically merging nearby interactions into clean step cards. Open the **3-Column Visual Studio** at any time to reorder steps, inspect and edit actions, preview your 2D route map, auto-fix route issues, and hot-sync directly into **RXPGuides** for instant in-game arrow and step testing.

---

## 🚀 Key Features

- **🎥 Live Flight Recorder HUD (`/rxprec`)**:
  - Real-time 3-card live feed showing your most recent recorded steps as you play.
  - One-click quick-action bar: **`[+Note]`**, **`[Grind XP]`**, **`[Hearth/Bind]`**, **`[Deathskip]`**, and **`[Pin Pos]`**.
  - Instant **`[Sticky]`** and **`[Split]`** controls directly on live feed cards.
- **🖥️ 3-Column Visual Guide Studio (`/rxpstudio`)**:
  - **Left Column — Visual Step Timeline**: Browse all steps in your guide with color-coded action badges (`[ACCEPT]`, `[TURN IN]`, `[COMPLETE]`, `[TRAINER]`, `[FLY]`, etc.), route lint warnings, and instant **`[Up]`**, **`[Down]`**, **`[Merge Down]`**, **`[Split]`**, and **`[Del]`** controls.
  - **Center Column — Card Inspector**: Edit step coordinates (`[Use My Pos]`), NPC targets (`[+Target]`), flags (`[Sticky]`, `[Loop]`), and individual actions using clean dropdown pills and inputs—or toggle **`[Raw Syntax: ON]`** to edit raw RXP directives directly.
  - **Right Column — Interactive 2D Zone Map Preview**: Visualizes your entire zone route with connected waypoint pins, step numbers, and click-to-reposition coordinate editing.
- **🧠 Smart Auto-Merger**:
  - Automatically coalesces consecutive quest accepts, turn-ins, and objectives at the same NPC or within proximity thresholds into unified multi-action RXP steps.
- **🛡️ Route Linter & Auto-Fix Engine**:
  - Detects orphaned turn-ins (turning in a quest before accepting it), duplicate quest actions, missing coordinates, and invalid zone data—with one-click **`[Auto-Fix]`** remediation.
- **⚡ Live RXPGuides Hot-Reload Bridge (`[Test Live in RXP]`)**:
  - Compiles your visual guide and injects it directly into `RXPGuides` in real time, jumping the active RXP window and waypoint arrow to your currently selected step.
- **🔄 Bi-Directional Import / Export**:
  - Export clean, production-ready `RXPGuides.RegisterGuide([[...]])` Lua scripts, paste existing RXP guides to decompile them into visual cards, or one-click import legacy `RXP_RecorderDB` runs.

---

## ⌨️ Slash Commands

| Command | Description |
| :--- | :--- |
| `/rxpstudio` or `/rxps` | Toggle the 3-column **RXP Guide Studio** editor window. |
| `/rxprec` or `/rxprecorder` | Toggle the compact **Live Recorder HUD**. |
| `/rxprec start` | Resume live event recording. |
| `/rxprec stop` or `/rxprec pause` | Pause live event recording. |
| `/rxpstudio test` | Compile and sync the active guide to `RXPGuides` at the selected step. |
| `/rxpstudio import` | Import recorded guide runs from legacy `RXP_RecorderDB`. |

---

## 📦 Installation & Usage

1. Copy `RXP_Studio` into your `World of Warcraft\_classic_\Interface\AddOns\` directory (or install via CurseForge).
2. *(Optional)* Enable **RestedXP Guides (`RXPGuides`)** alongside **RXP Guide Studio** if you want to use `[Test Live in RXP]` hot-reloading in-game.
3. Log in and use the **Live Recorder HUD** (`/rxprec`) while playing, or type `/rxpstudio` to open the full visual editor.

---

## 📄 License

Licensed under the [MIT License](LICENSE.txt).

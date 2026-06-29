# PartyMembersMarker — Technical Overview

## Purpose

PartyMembersMarker reworks **friendly** nameplates (friendly players and
friendly NPCs) into a clean "name-only" look that mimics the native
"nameplates off" appearance, while leaving **enemy** nameplates completely
untouched. On top of that it adds two pieces of extra information:

- a **second text line** under the name — the player's **guild** or the NPC's
  **occupation/title** (e.g. `<Innkeeper>`);
- a circular **class icon badge** above the name for friendly **players**
  (optionally scoped to party/raid members).

Files:

```
PartyMembersMarker/
├── PartyMembersMarker.toc   # Interface 50504, SavedVariables: PartyMembersMarkerDB
├── PartyMembersMarker.lua   # entire addon (single file)
└── docs/project-overview.md # this document
```

Saved variables: `PartyMembersMarkerDB`. Slash command: `/pmm` (debug) /
`/pmm config` (open settings).

Target client: **MoP Classic 5.5.4** (interface `50504`), which runs on the
modern engine. See `Compatibility / porting notes` for other Classic flavors.

---

## End-user behavior

For every nameplate the addon decides friendly vs. enemy via `IsFriendlyUnit`
(not attackable **and** `UnitIsFriend`).

**Enemy / attackable units:** nothing is changed (and any previously applied
changes are reverted if a pooled plate is reused for an enemy).

**Friendly units (players and NPCs):**

1. The native bar regions are hidden: `healthBar`, `castBar`, `LevelFrame`,
   `ClassificationFrame`, `RaidTargetFrame`.
2. The native **name** FontString is hidden; the addon draws its **own** name
   text instead (so it controls font/size/position/color and can append a
   status prefix).
3. Name text = `UnitPVPName` (includes player title) with an `<Away>`/`<Busy>`
   AFK/DND prefix when applicable. Color: **class color** for players, **green**
   for friendly NPCs, **yellow** for neutral, white fallback.
4. A **second line** under the name: `<Guild>` for players, `<Occupation>` for
   NPCs (read from a hidden scanning tooltip).
5. For friendly **players in scope** (`ICON_SCOPE`): a circular **class icon**
   with a class-colored ring above the name.

---

## Architecture

The addon is one file, organized as: tunables → helpers → per-plate text/icon
builder → apply/restore → event wiring → secure hooks → debug slash command.

### State tables (`PMM`)

- `PMM.hidden[plate] = true` — we have hidden this plate's bar regions.
- `PMM.text[plate] = { name, sub, icon, border }` — our created widgets for the
  plate (cached; built lazily, reused as plates are recycled from the pool).

### SavedVariables (`PartyMembersMarkerDB`)

```lua
PartyMembersMarkerDB = {
    iconSize  = 48,        -- class icon diameter in px (ICON_SIZE_MIN..ICON_SIZE_MAX)
    iconScope = "party",   -- who gets the class icon: "all" | "party" | "raid"
}
```

Initialized on `PLAYER_LOGIN` (defaulting `iconSize` to `ICON_SIZE` and
`iconScope` to `ICON_SCOPE`). Both are read through accessors so the rest of the
code never touches the globals directly:

- `GetIconSize()` — DB value, else the `ICON_SIZE` default. `RefreshIconSizes()`
  resizes the icon + ring on all live plates after a change (masks track their
  textures via `SetAllPoints`, so they follow automatically).
- `GetIconScope()` — DB value, else the `ICON_SCOPE` default; used by
  `PlayerInIconScope`. Changing it offers a UI reload to apply cleanly.

Plates are keyed directly by the Blizzard nameplate frame returned from
`C_NamePlate`. Nameplate frames are pooled and persistent, so caching widgets
per plate frame is safe across unit changes.

### Rendering layer (important design decision)

All our widgets live on a **per-plate holder frame** parented to the nameplate
base frame:

```lua
local holder = CreateFrame("Frame", nil, plate)
holder:SetAllPoints(plate)
holder:SetIgnoreParentAlpha(true)
```

Rationale (this went through several iterations):

- **Parenting to the nameplate** (not `UIParent`) keeps our text on the
  nameplate draw layer, so it interleaves correctly with other nameplates
  (closer plates draw over farther ones) and stays **below** `UIParent`
  raid/party frames (nameplates live on `WorldFrame`, which is under
  `UIParent`).
- **`SetIgnoreParentAlpha(true)`** prevents our text from dimming when Blizzard
  applies the non-target alpha fade (`nameplateNotSelectedAlpha`) to unselected
  plates. This was the key fix that let us avoid the earlier `UIParent`
  workaround (which caused our text to draw over all nameplates and over
  raid frames).

### Text labels and the faux colored outline

WoW's `SetFont` `OUTLINE` flag is **always black** and cannot be recolored. A
`label` abstraction (`MakeLabel`) supports an optional faux colored outline:

- Normal case (`OUTLINE_COLOR == nil`): one FontString with the configured
  `NAME_OUTLINE` flag and an engine-style drop shadow.
- Colored outline (`OUTLINE_COLOR` set): the main FontString plus 8 offset
  copies behind it (in `OUTLINE_DIRS` directions, `OUTLINE_WIDTH` px) tinted to
  the outline color. Currently `OUTLINE_COLOR` is `nil` (we ship plain black
  `OUTLINE` + shadow); the machinery remains for future use.

Label helpers operate on both the main string and its copies:
`LabelSetText`, `LabelSetColor` (main only — copies keep outline color),
`LabelShow`, `LabelHide`.

### Class icon badge

Two stacked, circle-masked textures above the name:

- `border` — a solid white square (`Interface\Buttons\WHITE8X8`), sized
  `ICON_SIZE + 2*ICON_BORDER`, tinted to the class color → shows as a
  class-colored **ring**.
- `icon` — the class emblem from `Interface\TargetingFrame\UI-Classes-Circles`,
  cropped per class via `CLASS_ICON_TCOORDS[class]`.

Both get a `CircleMaskScalable` mask (`AddMaskTexture`) for smooth,
anti-aliased circular edges. (Solid-white-plus-mask is used because tinting the
class-circles atlas directly produced a black ring — its background is dark.)

### NPC occupation via tooltip scan

There's no direct API for an NPC's `<Occupation>` subtitle, so a hidden
`GameTooltip` (`PMMScanTooltip`, owner `WorldFrame`/`ANCHOR_NONE`) is used:
`GetUnitOccupation` does `SetUnit(unit)` then reads `PMMScanTooltipTextLeftN`
(lines 2–4), preferring a line already wrapped in `<...>`, else falling back to
line 2 if it isn't a level/numeric line.

---

## Settings panel

Reachable via **ESC → Options → AddOns → PartyMembersMarker** or `/pmm config`.

- Built once in `SetupOptions()`, called from `PLAYER_LOGIN` wrapped in `pcall`
  so any UI/API mismatch can't break the rest of the addon. Guarded by
  `if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end`.
- Registered with the modern **Settings canvas API**
  (`Settings.RegisterCanvasLayoutCategory` + `RegisterAddOnCategory`); the
  category handle is kept in `optionsCategory`. `OpenOptions()` opens it via
  `Settings.OpenToCategory(optionsCategory:GetID())`. (This mirrors the sibling
  EnemyTotemMarker addon; MoP Classic 5.5.4 has the Settings API, so no legacy
  `InterfaceOptions` fallback is needed.)
- Layout: title; the **Icon size** slider (`OptionsSliderTemplate`,
  `ICON_SIZE_MIN..ICON_SIZE_MAX`) with `±` arrow steppers (`MakeStepper`, using
  the spellbook page-turn arrow textures) and a **live preview** badge to the
  right of it (the player's own class icon + class-colored ring); then a
  **"Show class icon for:"** radio group (`UIRadioButtonTemplate`) with **All
  players** / **Party members** / **Raid members**.
- Icon size: on change the slider writes `PartyMembersMarkerDB.iconSize`, calls
  `RefreshIconSizes()` (live update of all plates) and `UpdatePreview()`.
- Icon scope: clicking a radio writes `PartyMembersMarkerDB.iconScope`,
  re-syncs the radios (`SyncScopeButtons`), and shows the **`PMM_RELOAD`**
  `StaticPopup` offering a `ReloadUI()`. The reload applies the scope cleanly —
  a live refresh lagged while class data streamed in (and could leave stale
  icons), so a reload is preferred for this option.
- `OnShow` syncs the slider, preview, and radio selection to the saved values.

Adding more settings later: extend `PartyMembersMarkerDB`, add widgets in
`SetupOptions`, and either refresh live (`RefreshIconSizes` /
`UpdateAllNameplates`) or prompt a reload for options that don't apply cleanly.

---

## Key functions

| Function | Role |
|---|---|
| `IsFriendlyUnit(unit)` | not `UnitCanAttack` and `UnitIsFriend` → we manage it |
| `PlayerInIconScope(unit)` | gates the class icon by `ICON_SCOPE` (all/party/raid) |
| `GetDisplayName(unit)` | `UnitPVPName`/`UnitName` + AFK/DND prefix |
| `GetSubText(unit)` | player guild or NPC occupation, as `<...>` |
| `GetNameColor(unit)` | class color / green (friendly) / yellow (neutral) |
| `GetUnitOccupation(unit)` | scans the hidden tooltip for the `<Occupation>` line |
| `SetRegionsShown(plate,b)` | show/hide the `BAR_REGIONS` of a plate's UnitFrame |
| `GetText(plate)` | lazily builds the holder + name/sub labels + icon/border (cached) |
| `ApplyFriendly(plate,unit)` | hide native bits, draw name/sub/icon |
| `RestorePlate(plate)` | un-hide native bits, hide our widgets |
| `UpdateNameplate(unit)` | route to Apply/Restore by friendliness |
| `UpdateAllNameplates()` | re-run `UpdateNameplate` for all visible plates |
| `GetIconSize()` | current icon size (DB value, else `ICON_SIZE`) |
| `GetIconScope()` | current icon scope (DB value, else `ICON_SCOPE`) |
| `RefreshIconSizes()` | resize icon + ring on all live plates after a settings change |
| `SetupOptions()` / `OpenOptions()` | build / open the settings panel |

## Events and hooks

Event frame:

- `PLAYER_LOGIN` — init `PartyMembersMarkerDB`, `pcall(SetupOptions)`, print
  loaded message.
- `NAME_PLATE_UNIT_ADDED` — `UpdateNameplate(unit)`.
- `NAME_PLATE_UNIT_REMOVED` — `RestorePlate(plate)` (clean the pooled plate).
- `PLAYER_FLAGS_CHANGED` / `GROUP_ROSTER_UPDATE` — `UpdateAllNameplates()`
  (refresh AFK/DND prefix and party/raid icon scope live).
- `UNIT_NAME_UPDATE` — refresh that unit's plate so the class icon appears once
  the class finally streams in.

`UpdateAllNameplates()` wraps each plate update in `pcall` so one failing plate
can't abort the whole refresh.

Secure hooks (`hooksecurefunc`):

- **`CompactUnitFrame_UpdateName`** (global) — Blizzard re-shows the native name
  on every update (incl. mouseover); we re-hide `uf.name` for friendly
  nameplate units so our own text never doubles.
- **`RaidTargetFrame:Show`** (per plate, once, guarded by `rt.pmmHooked`) — the
  native raid marker is re-shown by `uf:UpdateRaidTarget()` when the marker
  changes; we re-hide it for friendly units. (There is **no** global
  `CompactUnitFrame_UpdateRaidTargetIcon` on this client — the field is
  `uf.RaidTargetFrame`, confirmed via `/pmm`.)

---

## Configuration (tunables at top of file)

Plain locals; most are intended to be backed by saved settings later.
`ICON_SIZE` is **already** DB-backed: it is the default, and the live value
comes from `PartyMembersMarkerDB.iconSize` via `GetIconSize()` (slider range
`ICON_SIZE_MIN`=16 .. `ICON_SIZE_MAX`=96).

| Tunable | Default | Meaning |
|---|---|---|
| `FONT_FILE` | `nil` | `nil` = clone native plate font (Friz Quadrata `FRIZQT__`); or a path. Must contain Cyrillic for RU names. |
| `NAME_SIZE` | `nil` | `nil` = native size; or an explicit px size |
| `NAME_OUTLINE` | `"OUTLINE"` | `""` / `"OUTLINE"` / `"THICKOUTLINE"` |
| `OUTLINE_COLOR` | `nil` | `nil` = black `OUTLINE`; `{r,g,b}` = faux colored outline via copies |
| `OUTLINE_WIDTH` | `1` | faux-outline offset, px |
| `SHADOW` | `true` | engine-style drop shadow (when not using colored outline) |
| `SUB_SIZE_DELTA` | `-2` | sub line size relative to name |
| `VERTICAL_OFFSET` | `-10` | name vertical nudge (+ up / − down) |
| `SHOW_CLASS_ICON` | `true` | class icon above friendly player names |
| `ICON_SCOPE` | `"party"` | `"all"` / `"party"` / `"raid"` — **default** for the DB-backed `iconScope` (configurable via the settings radio group) |
| `ICON_SIZE` | `48` | class icon diameter, px — **default** for the DB-backed `iconSize` (configurable in the settings panel) |
| `ICON_GAP` | `8` | gap between icon bottom and name top, px |
| `ICON_BORDER` | `4` | class-colored ring thickness, px |

### Icon scope mapping

The scope is configurable in the settings panel (radio group), persisted as
`PartyMembersMarkerDB.iconScope`, and read via `GetIconScope()` →
`PlayerInIconScope`:

- **All players** → `"all"`
- **Party members** → `"party"`
- **Raid members** → `"raid"`

---

## Slash commands

- **`/pmm config`** — opens the settings panel (`OpenOptions`).
- **`/pmm`** (target a unit first) — debug dump:
  - the unit's tooltip lines 1–6 (to inspect the occupation line format);
  - the native name font (file/size/flags);
  - any UnitFrame fields whose name contains `raid`/`target` (to confirm region
    names per client).

---

## Compatibility / porting notes

This addon relies on **modern-engine** APIs that exist on Classic flavors built
on the modern client (MoP/Cata/Wrath/TBC Classic), but would **not** exist on
true vanilla-era clients:

- `C_NamePlate.*`, `NAME_PLATE_UNIT_ADDED/REMOVED`
- `SetIgnoreParentAlpha`, `CreateMaskTexture` / `AddMaskTexture`
- `UnitPVPName`, `CLASS_ICON_TCOORDS`
- `Settings.*` canvas API (panel registration / `OpenToCategory`) and the
  `OptionsSliderTemplate` slider template
- `CompactUnitFrame_UpdateName` hook target; per-build the raid-marker field is
  `uf.RaidTargetFrame` (verify with `/pmm` on each client).

When porting to another branch (e.g. **TBC Classic**), re-verify:

1. `## Interface:` number in the `.toc`.
2. The nameplate `UnitFrame` field names (`healthBar`, `castBar`, `name`,
   `LevelFrame`, `ClassificationFrame`, `RaidTargetFrame`) — names can differ
   between client versions; `/pmm` helps confirm.
3. That `CompactUnitFrame_UpdateName` is still the function that re-shows the
   name, and that `uf:UpdateRaidTarget` / `RaidTargetFrame` is still how the
   marker is shown.
4. `CHAT_FLAG_AFK` / `CHAT_FLAG_DND` localized strings exist (fallbacks provided).

See also the repo-wide knowledge file
`MoP-Classic-AddOn-Porting-Notes.md` for general MoP Classic API gotchas.

---

## Known issues / follow-ups

- A stray player **level number ("90")** was observed once leaking onto a plate
  but was not reproducible; if it returns, identify which UnitFrame region shows
  it (likely a player-specific level region not in `BAR_REGIONS`).
- `KNameplateColor` coexists safely: it operates on friendly regions we hide
  (so its friendly changes are invisible) and on enemy plates we don't touch.
  Its previously-seen friendly-NPC PvP/shield icon is injected into the native
  name text, which we hide — so it no longer appears.

# PartyMembersMarker — Technical Overview

## Purpose

PartyMembersMarker makes it easy to keep track of where your **party/raid
members** are — especially in PvP — by marking each ally with their **class
icon** above their nameplate, without cluttering the screen with full friendly
nameplates or relying on manually-set raid markers.

It also reworks **friendly** nameplates (players and NPCs) into a clean
name-only look (like the native "nameplates off" view), while leaving **enemy**
nameplates completely untouched.

Files:

```
PartyMembersMarker/
├── PartyMembersMarker.toc   # Interface 50504, SavedVariables: PartyMembersMarkerDB
├── PartyMembersMarker.lua   # entire addon (single file)
├── README.md                # CurseForge/GitHub readme
├── icon.png                 # project avatar (export-ignored from the release zip)
└── docs/project-overview.md # this document
```

Target client: **MoP Classic 5.5.4** (interface `50504`), modern engine.
Saved variables: `PartyMembersMarkerDB`. Slash: `/pmm` (debug) / `/pmm config`.

---

## End-user behavior

Each nameplate is classified via `IsFriendlyUnit` (not attackable **and**
`UnitIsFriend`).

**Enemy / attackable units:** untouched (and reverted if a pooled plate is
reused for an enemy).

**Friendly units (players and NPCs):**

1. Native bar regions hidden: `healthBar`, `castBar`, `LevelFrame`,
   `ClassificationFrame`, `RaidTargetFrame`.
2. Native **name** hidden; the addon draws its own name (controls
   font/size/outline/position/color and adds a status prefix).
3. Name text = `UnitPVPName` (player title included) + `<Away>`/`<Busy>` AFK/DND
   prefix. Color:
   - **players** → class color;
   - **NPCs** → by your **reputation standing** with the NPC's faction
     (≤3 red, 4 yellow, 5+ green), falling back to `UnitReaction`.
4. **Second line** under the name: `<Guild>` for players, `<Occupation>` for
   NPCs (read from a hidden scanning tooltip).
5. For friendly **players in scope** (`all` / `party` / `raid`): a circular
   **class-icon badge** with a class-colored ring above the name.
6. The native **raid target marker** is hidden on friendly plates.

---

## Architecture

One file: tunables/accessors → helpers → per-plate builder → apply/restore →
refresh helpers → settings panel → events → secure hooks → slash command.

### State tables (`PMM`)

- `PMM.hidden[plate] = true` — bar regions hidden for this plate.
- `PMM.text[plate] = { name, sub, icon, border }` — our widgets (cached, built
  lazily, reused as plates recycle).
- `PMM.factionStanding[name] = standingID` — your standing per faction, for NPC
  reputation coloring.

### Rendering layer

All widgets live on a **per-plate holder** parented to the nameplate base
frame, with `SetIgnoreParentAlpha(true)`:

- Parenting to the nameplate (not `UIParent`) keeps text on the nameplate layer
  — it interleaves with other plates and stays below `UIParent` raid/party
  frames (nameplates are on `WorldFrame`, under `UIParent`).
- `SetIgnoreParentAlpha(true)` stops the non-target alpha fade from dimming our
  text. (Known trade-off: it also ignores the occlusion fade, so friendly names
  can show through walls — accepted for now.)

### Text labels and the faux colored outline

`MakeLabel` builds the main `FontString` plus, when `OUTLINE_COLOR` is set, a
ring of offset copies (faux colored outline). Currently `OUTLINE_COLOR` is
`nil` (plain `OUTLINE` flag + drop shadow). Helpers: `LabelSetText`,
`LabelSetColor`, `LabelShow`, `LabelHide`, and `ApplyLabelFonts` (font/size/
outline for the name + sub + copies).

Font/size/outline are resolved per unit and applied in `ApplyFriendly` (plates
are pooled across unit types), so players and NPCs can differ.

### Class-icon badge

Two circle-masked textures above the name:

- `border` — solid white (`WHITE8X8`) tinted to the class color → class ring.
- `icon` — class emblem from `UI-Classes-Circles`, cropped via
  `CLASS_ICON_TCOORDS[class]`.

Both get a `CircleMaskScalable` mask for smooth edges. (White + tint + mask is
used because tinting the class-circles atlas directly produced a black ring.)

### NPC occupation + reputation

- `GetUnitOccupation` scans a hidden tooltip (`PMMScanTooltip`) for the NPC's
  `<Occupation>` line.
- `BuildFactionStanding` caches `factionName -> standingID` from
  `GetFactionInfo` (expanding collapsed headers so all factions enumerate).
  `GetNPCFactionStanding` reads the NPC's faction line from the same tooltip and
  returns your standing, used by `GetNameColor`.

---

## Key functions

| Function | Role |
|---|---|
| `IsFriendlyUnit(unit)` | not `UnitCanAttack` and `UnitIsFriend` → we manage it |
| `PlayerInIconScope(unit)` | gates the class icon by scope (all/party/raid) |
| `GetDisplayName(unit)` | `UnitPVPName`/`UnitName` + AFK/DND prefix |
| `GetSubText(unit)` | player guild or NPC occupation, as `<...>` |
| `GetNameColor(unit)` | class color (player) / reputation- or reaction-based (NPC) |
| `GetNPCFactionStanding(unit)` | your standing with the NPC's faction (tooltip) |
| `GetFontFile` / `GetNameSizeFor` / `GetOutlineFor` | resolve text styling (per unit where relevant) |
| `GetText(plate)` | lazily builds holder + name/sub labels + icon/border (cached) |
| `ApplyFriendly(plate,unit)` | hide native bits, draw name/sub/icon |
| `RestorePlate(plate)` | restore native bits, hide our widgets |
| `UpdateNameplate(unit)` / `UpdateAllNameplates()` | route / refresh all |
| `RefreshIconSizes` / `RefreshFonts` | live-apply icon-size / font settings |
| `BuildFactionStanding()` | rebuild the faction→standing cache |
| `SetupOptions()` / `OpenOptions()` | build / open the settings panel |

## Events and hooks

Event frame:

- `PLAYER_LOGIN` — init `PartyMembersMarkerDB`, `BuildFactionStanding`,
  `pcall(SetupOptions)`.
- `NAME_PLATE_UNIT_ADDED` → `UpdateNameplate`; `NAME_PLATE_UNIT_REMOVED` →
  `RestorePlate`.
- `PLAYER_FLAGS_CHANGED` / `GROUP_ROSTER_UPDATE` → `UpdateAllNameplates`
  (AFK/DND prefix, party/raid icon scope).
- `UNIT_NAME_UPDATE` → refresh that unit (class icon appears once class loads).
- `UPDATE_FACTION` → rebuild standing cache + recolor plates.

`UpdateAllNameplates` wraps each plate in `pcall` so one bad plate can't abort
the refresh.

Secure hooks:

- **`CompactUnitFrame_UpdateName`** — re-hide `uf.name` for friendly nameplate
  units (Blizzard re-shows it on every update, incl. mouseover) so our text
  never doubles.
- **`RaidTargetFrame:Show`** (per plate, once) — re-hide the native raid marker
  for friendly units (re-shown by `uf:UpdateRaidTarget`). Field confirmed as
  `uf.RaidTargetFrame` via `/pmm`.

---

## Configuration

### SavedVariables (`PartyMembersMarkerDB`)

```lua
PartyMembersMarkerDB = {
    iconSize         = 48,        -- class badge diameter (ICON_SIZE_MIN..MAX)
    iconScope        = "party",   -- "all" | "party" | "raid"
    fontKey          = "DEFAULT", -- DEFAULT | ARIALN | MORPHEUS | SKURRI
    nameSizePlayer   = 10,        -- player name font size (NAME_SIZE_MIN..MAX)
    nameSizeNPC      = 10,        -- NPC name font size
    nameOutlinePlayer = true,     -- outline on player names
    nameOutlineNPC    = true,     -- outline on NPC names
}
```

Initialized on `PLAYER_LOGIN`; read through accessors so code never touches the
globals directly. Changing icon size / fonts applies live (`RefreshIconSizes` /
`RefreshFonts`); changing the icon scope prompts a UI reload (`PMM_RELOAD`
popup) because a live refresh lags while class data streams in.

### Tunables (defaults, top of file)

`FONT_FILE` (default `STANDARD_TEXT_FONT`), `NAME_SIZE`, `NAME_OUTLINE`,
`OUTLINE_COLOR` (nil), `OUTLINE_WIDTH`, `SHADOW`, `SUB_SIZE_DELTA`,
`VERTICAL_OFFSET`, `SHOW_CLASS_ICON`, `ICON_SCOPE`, `ICON_SIZE`, `ICON_GAP`,
`ICON_BORDER`; ranges `ICON_SIZE_MIN/MAX` (16/96), `NAME_SIZE_MIN/MAX` (8/24);
the `FONTS` list (standard client fonts with Cyrillic).

### Settings panel (ESC → Options → AddOns, or `/pmm config`)

Built once in `SetupOptions()` under `pcall`, registered via the modern
`Settings` canvas API. Layout:

- **Icon size** slider (with steppers) + a live class-badge **preview** to its
  right.
- **Show class icon for** radio group: All players / Party members / Raid
  members (prompts reload).
- **Name text** section: **Font** dropdown (`UIDropDownMenu`); **Player name
  size** and **NPC name size** sliders, each with an **Outline** checkbox to its
  right (per unit type).

---

## Slash commands

- **`/pmm config`** — open the settings panel.
- **`/pmm`** (target a unit) — debug dump: tooltip lines, native name font, and
  UnitFrame fields matching raid/target.

---

## Compatibility / porting notes

Relies on modern-engine APIs present on Classic flavors built on the modern
client (would not exist on true vanilla):

- `C_NamePlate.*`, `NAME_PLATE_UNIT_ADDED/REMOVED`
- `SetIgnoreParentAlpha`, `CreateMaskTexture` / `AddMaskTexture`
- `UnitPVPName`, `CLASS_ICON_TCOORDS`, `FACTION` standing via `GetFactionInfo`
- `Settings.*` canvas API, `OptionsSliderTemplate`, `UIDropDownMenu*`

When porting to another branch, re-verify: the `.toc` interface number; the
nameplate `UnitFrame` field names (`/pmm` helps); that
`CompactUnitFrame_UpdateName` and `RaidTargetFrame` are still how the name /
marker are shown; and that `CHAT_FLAG_AFK`/`CHAT_FLAG_DND` exist. See the
repo-wide `MoP-Classic-AddOn-Porting-Notes.md` for general gotchas.

---

## Known issues / follow-ups

- **Names show through walls.** `SetIgnoreParentAlpha` ignores the occlusion
  fade. Tried an alpha-threshold re-hide; reverted as unreliable.
- **Spec icons (instead of class icons)** were prototyped via combat-log
  detection and reverted — unreliable until the player casts a signature spell.
- Building the faction cache expands the reputation pane's collapsed headers (a
  minor visible side effect).
- `KNameplateColor` coexists: its friendly-plate work lands on regions we hide;
  it handles enemy plates we don't touch.

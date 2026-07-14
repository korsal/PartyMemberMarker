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
  `pcall(SetupOptions)`. On the **first run** (DB was `nil`) it also enables the
  friendly-nameplate CVars (`FRIENDLY_NP_CVARS` → `"1"`) so the addon works out
  of the box; only on first run, so a later choice to hide them isn't overridden.
- `NAME_PLATE_UNIT_ADDED` → `UpdateNameplate`; `NAME_PLATE_UNIT_REMOVED` →
  `RestorePlate`.
- `PLAYER_FLAGS_CHANGED` / `GROUP_ROSTER_UPDATE` → `UpdateAllNameplates`
  (AFK/DND prefix, party/raid icon scope).
- `UNIT_NAME_UPDATE` → refresh that unit (class icon appears once class loads).
- `UPDATE_FACTION` → rebuild standing cache + recolor plates.
- `UNIT_FACTION` → a unit's attackability/reaction changed (duel start/end, PvP
  flagging); re-classifies visible plates through the safe `ReclassifyPlate`
  (immediate reaction). It's a nudge — the reliable driver is the reconcile
  ticker below, since `UNIT_FACTION` can fire before `UnitCanAttack` settles.

`UpdateAllNameplates` wraps each plate in `pcall` so one bad plate can't abort
the refresh.

### Duel / attackability transitions

A duel (or PvP flag) flips a unit's attackability **without** recreating the
nameplate, so `NAME_PLATE_UNIT_ADDED` never fires and the plate would keep the
wrong skin. `ReclassifyPlate(plate, unit)` flips a single plate between our
friendly skin and a normal plate, and only acts on the actual transition:

- un-skin (`RestorePlate`) is gated on the **positive** `UnitCanAttack` signal,
  not "not friendly" — the check can run before a plate's unit data is loaded
  (both `UnitCanAttack` and `UnitIsFriend` read false), and treating that
  transient as hostile would permanently un-skin a genuinely friendly plate;
- re-skin (`ApplyFriendly`) only when the unit reads friendly again.

It's driven by a light **`C_Timer.NewTicker(0.3, …)`** reconcile over the
visible plates (plus the `UNIT_FACTION` nudge). The timer is the robust
catch-all: event timing for the flip is unreliable here, but the ticker always
converges within ~0.3s. Steady state is just a couple of cheap checks per plate.

Secure hooks:

- **`CompactUnitFrame_UpdateName`** — re-hide `uf.name` for friendly nameplate
  units (Blizzard re-shows it on every update, incl. mouseover) so our text
  never doubles.
- **`healthBar` / `castBar` / `LevelFrame` / `RaidTargetFrame` `Show`** (per
  plate, once) — Blizzard re-shows every region it owns on updates, so a
  one-time hide leaks back (a health bar over a friendly plate). Each is
  re-hidden for friendly units on its `Show`. Enemies/duel opponents keep them.
- **Raid marker special case.** `RaidTargetFrame` is **not** in the bulk
  `BAR_REGIONS` force-show: showing it without an assigned marker reveals its
  untextured icon atlas (all 8 markers, tiny) on a duel opponent. It's hidden
  explicitly on friendly plates + via the `Show` hook, and `RestorePlate` lets
  Blizzard (`uf:UpdateRaidTarget`) set the real marker for enemies.

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
    hideFriendlyInInstance = true,  -- turn friendly nameplates off in PvE instances (default on)
    -- runtime bookkeeping for the above (persist across /reload):
    hidFriendly      = false,     -- we currently have friendly plates turned off
    savedShowFriends = {          -- per-CVar values to restore on exit (a table:
        nameplateShowFriendlyPlayers = "1", -- MoP 5.5.4 has no combined
        nameplateShowFriendlyNPCs    = "1", -- `nameplateShowFriends`, so we
    },                            -- save/restore the two split CVars)
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
- **Auto-disable friendly nameplates when the client blocks marking them with the
  class icon** checkbox (`hideFriendlyInInstance`, on by default).

### Auto-disable friendly nameplates in instances

Since friendly nameplates are **forbidden** in PvE instances (see Known issues),
the addon can't clean them up there — they just clutter. Opt-in feature
(`hideFriendlyInInstance`) to turn them off in that case.

**Which CVars.** MoP Classic 5.5.4 has **no** combined `nameplateShowFriends`
(`GetCVar` returns `nil` — confirmed via the `/pmm config` probe). Friendly
visibility is split into `nameplateShowFriendlyPlayers` and
`nameplateShowFriendlyNPCs`, so the addon drives **both** (see the module-level
`FRIENDLY_NP_CVARS` list). This was the root cause of the feature never working:
the earlier code wrote to the non-existent `nameplateShowFriends`.

**Single source of truth: `ApplyInstanceNameplateState()`.** One reconcile
function decides the whole state — hide when the option is on **and**
`IsInInstance()` reports a `party`/`raid` instance; restore otherwise. On the
first hide it saves each CVar's current value into `savedShowFriends` (a per-CVar
table) and sets `hidFriendly`, then sets every `FRIENDLY_NP_CVARS` entry to
`"0"`; `RestoreFriendlyNameplates()` puts each saved value back and clears
`hidFriendly`. Both flags live in the DB so a `/reload` inside the instance can't
lose or overwrite the saved values. Making one function own both directions is
what fixed the second bug where hide-on-enter and restore-on-exit lived on two
separate code paths that could disagree.

It's driven from three places:

- **`PLAYER_ENTERING_WORLD` (primary).** Runs the reconcile immediately **and**
  again after `C_Timer.After(1.5, …)`, because `IsInInstance()` can lag right at
  the event (both on enter and on exit). The immediate pass handles the common
  case; the delayed pass corrects a stale `IsInInstance()`.
- **Forbidden-plate hook (backup trigger).** The global
  `CompactUnitFrame_UpdateName` hook fires for forbidden plates; when it sees one
  and we haven't hidden yet (`option on and not hidFriendly`), it kicks the
  reconcile once. Guarded so it never re-runs `SetCVar` on every `UpdateName`.
- **Options checkbox.** Toggling the setting calls the reconcile directly, so it
  hides immediately if you're already in an instance, or restores if you just
  turned it off.

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

- **Names show through walls (unresolved).** Because our text holder uses
  `SetIgnoreParentAlpha(true)` (to avoid the non-target dimming), it also
  ignores the engine's occlusion fade — so friendly names render through walls.
  Two fixes were attempted and reverted:
  1. An `OnUpdate` on NPC holders that hid them when the plate's effective alpha
     dropped below the expected selection alpha (i.e. occlusion kicked in),
     keeping players visible through walls. This relies on the engine actually
     fading occluded plates.
  2. Forcing `nameplateOccludedAlphaMult` below 1 on login so that fade exists.
     `/pmm` revealed it defaults to **1.0** on this client (occlusion fade off),
     so without this the detection never triggers; names persist until the
     nameplate is removed (a large angle).
  Both were reverted: enabling occlusion is a global CVar change that also fades
  **enemy** plates behind walls (undesirable for PvP awareness, which is exactly
  why a PvP user keeps `occludedMult = 1`), and the nameplate occlusion angle is
  coarser than the native "nameplates off" name occlusion anyway. Net: friendly
  names (players and NPCs) currently show through walls; left as-is. Note the
  test left the CVar at `0.9` in SavedVariables — restore with
  `/console nameplateOccludedAlphaMult 1` if needed.
- **Spec icon instead of class icon (prototyped, reverted).** Goal: show a
  teammate's specialization icon, useful in arena/BG for reading roles
  (healer/tank/dps). Another player's spec can't be read synchronously, so two
  sources were considered:
  - **Inspect** (`NotifyInspect` → `INSPECT_READY` → `GetInspectSpecialization`
    → `GetSpecializationInfoByID`) — async, one unit at a time, range-limited,
    unreliable in combat; only practical during an arena/BG prep phase.
  - **Passive combat-log detection** — the approach we prototyped, borrowed from
    the `BattlegroundTargets` addon: a static `SPEC_BY_SPELL` map of signature
    spell IDs → specID. On `COMBAT_LOG_EVENT_UNFILTERED` (`SPELL_CAST_SUCCESS` /
    `SPELL_AURA_APPLIED` from a player), cache `specByGUID[guid] = specID`; when
    drawing a friendly player, use the spec icon (`GetSpecializationInfoByID`
    icon, circle-masked) if known, else fall back to the class icon. Refresh the
    plate on first detection; wired to a **"Detect specialization"** checkbox
    (`detectSpec`), refreshed on `UNIT_NAME_UPDATE`/`RAID_TARGET_UPDATE`, cache
    cleared on `PLAYER_ENTERING_WORLD`.
  - **Why reverted:** detection only lands once the player casts a *signature*
    spell (works on a busy BG, but laggy/unreliable elsewhere and never for
    someone who hasn't cast); the spell→spec table is large and patch-specific
    (and copying it from another addon is a licensing question). The class icon
    is always known instantly, so it stays the default. Could return as a hybrid
    (class icon + inspect during prep + optional combat-log upgrade).
- **Forbidden plates in instances (client limitation).** In some instances
  (e.g. random dungeons) the client creates friendly nameplates as **forbidden**
  (`uf:IsForbidden()`) to stop addons from turning them into unit frames
  (anti-automation). Addons can't touch those — `NAME_PLATE_UNIT_ADDED` doesn't
  fire and `GetNamePlateForUnit` returns nil for them, and the global
  `CompactUnitFrame_UpdateName` hook must early-out on `IsForbidden()` or it
  errors with *"calling 'Hide' on bad self"*. Net: party markers don't appear in
  those instances; nothing an addon can do. Works in the open world and PvP.
  Mitigation: the opt-in **auto-disable friendly nameplates in instances** feature
  (above) removes the resulting clutter.
- Building the faction cache expands the reputation pane's collapsed headers (a
  minor visible side effect).
- `KNameplateColor` coexists: its friendly-plate work lands on regions we hide;
  it handles enemy plates we don't touch.

<p align="center">
  <img src="icon.png" width="128" alt="PartyMembersMarker icon">
</p>

<h1 align="center">PartyMembersMarker</h1>

<p align="center">
  Turns friendly nameplates into a clean name-only look and marks your group
  members with a class-colored icon badge.
</p>

<!--
  Badge block — enable once the CurseForge project exists (replace PROJECT_ID):

  <p align="center">
    <a href="https://www.curseforge.com/wow/addons/PROJECT_SLUG">
      <img src="https://img.shields.io/curseforge/dt/PROJECT_ID?logo=curseforge&label=CurseForge"></a>
    <a href="https://www.curseforge.com/wow/addons/PROJECT_SLUG/files">
      <img src="https://img.shields.io/curseforge/v/PROJECT_ID?logo=curseforge&label=version"></a>
    <img src="https://img.shields.io/curseforge/game-versions/PROJECT_ID?label=game%20version">
  </p>
-->

---

PartyMembersMarker hides the health bars on **friendly** players and NPCs so
their nameplates collapse to a clean floating name (like the native
"nameplates off" look), while leaving **enemy** nameplates untouched. It adds
the player's guild or the NPC's occupation under the name, colors player names
by class, and puts a circular class-icon badge above your group members.

Built for **Mists of Pandaria Classic (5.5.4, interface `50504`)**.

## Features

- **Name-only friendly plates** — health/cast/level bars hidden on friendly
  players and NPCs; only the name remains.
- **Second line** — `<Guild>` for players, `<Occupation>` for NPCs
  (Innkeeper, Vendor, …).
- **Class-colored names** with AFK/DND status prefix; friendly NPCs in green.
- **Class-icon badge** above friendly players — a circular class icon with a
  class-colored ring, shown for **all / party / raid** members (your choice).
- **Native raid marker hidden** on friendly plates for a cleaner look.
- **In-game options** — icon size (with live preview) and icon scope.

## Installation

- **Manual:** download the latest release and extract the `PartyMembersMarker`
  folder into `World of Warcraft/_classic_/Interface/AddOns/`.
- **CurseForge:** _(coming soon)_ install via the CurseForge page or your addon
  manager.

## How to use

1. Install and log in. Friendly nameplates become name-only automatically.
2. Make sure nameplates are on (key **V**, or `/console nameplateShowAll 1`),
   with friendly nameplates enabled.
3. Open the options panel: **ESC → Options → AddOns → PartyMembersMarker**, or
   type `/pmm config`.

## Options panel

- **Icon size** — class-icon diameter, with a live class-badge preview.
- **Show class icon for** — All players / Party members / Raid members
  (changing this prompts a quick UI reload to apply cleanly).

## Slash commands

| Command | Description |
|---|---|
| `/pmm config` | Open the options panel. |
| `/pmm` | Debug: dump the current target's tooltip lines, native name font, and raid/target-related nameplate fields. |

## Documentation

A detailed technical overview of the architecture and rendering decisions is in
[docs/project-overview.md](docs/project-overview.md).

## Feedback

Bug reports and suggestions are welcome in the CurseForge comments _(project
link coming soon)_.

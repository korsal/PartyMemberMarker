<p align="center">
  <img src="icon.png" width="128" alt="PartyMembersMarker icon">
</p>

<h1 align="center">PartyMembersMarker</h1>

<p align="center">
  Track your party and raid members at a glance with a class icon above their
  nameplate — no screen clutter, no raid markers.
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

PartyMembersMarker makes it easy to keep track of where your party members are
— especially in **arena and battlegrounds**. Each ally is marked with their
**class icon** above their nameplate, so you can spot your teammates at a glance
— without cluttering the screen with full friendly nameplates, and without
asking everyone to set raid markers.

It also keeps things tidy: **friendly** nameplates are stripped down to a clean,
name-only look (like the native "nameplates off" view), while **enemy**
nameplates are left completely untouched.

Built for **Mists of Pandaria Classic (5.5.4)**.

## Features

- **Class-icon marker** — a circular class icon with a class-colored ring above
  your group members, so you always know where each teammate is. Show it for
  **all players**, **party members**, or **raid members** (your choice).
- **No raid markers needed** — find your allies instantly without relying on
  skull/cross raid icons.
- **Name-only friendly plates** — health, cast and level bars hidden on friendly
  players and NPCs, leaving just a clean floating name.
- **Second line under the name** — a player's `<Guild>`, or an NPC's occupation
  (`<Innkeeper>`, `<Vendor>`, …).
- **Smart name colors** — players tinted by class; friendly NPCs colored by your
  reputation with their faction (green / yellow / red). AFK/DND status prefix
  included.
- **Cleaner look** — the native raid target marker is hidden on friendly plates.
- **In-game options** — class-icon size (with a live preview), icon scope, font,
  and separate name size + outline for players and NPCs.

## How to use

1. Install and log in.
2. **Enable friendly nameplates** — press **Ctrl+V** (or
   `/console nameplateShowFriends 1`). The addon only works while friendly
   nameplates are shown.
3. Your party/raid members are now marked with their class icon. Open the
   options to customize: **ESC → Options → AddOns → PartyMembersMarker**, or type
   `/pmm config`.

## Options

- **Icon size** — class-icon diameter, with a live class-badge preview.
- **Show class icon for** — All players / Party members / Raid members.
- **Name text** — font, plus separate name size and outline for players and NPCs.

## Note

In some **instances** (e.g. random dungeons) the game protects friendly
nameplates so addons cannot modify them. There, party markers won't appear —
this is a client restriction, not a bug. It works in the open world and in
arenas/battlegrounds where friendly nameplates aren't protected.

## Slash commands

| Command | Description |
|---|---|
| `/pmm config` | Open the options panel. |
| `/pmm` | Debug: dump the current target's tooltip lines and nameplate info. |

## Documentation

A detailed technical overview of the architecture and rendering decisions is in
[docs/project-overview.md](docs/project-overview.md).

## Feedback

Bug reports and suggestions are welcome in the CurseForge comments _(project
link coming soon)_.

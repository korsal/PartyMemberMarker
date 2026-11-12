<p align="center">
  <img src="icon.png" width="128" alt="PartyMembersMarker icon">
</p>

<h1 align="center">PartyMembersMarker</h1>

<p align="center">
  Track your party and raid members at a glance with a class icon above their
  nameplate — no screen clutter, no raid markers.
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/party-member-marker">
    <img src="https://img.shields.io/curseforge/dt/1592276?logo=curseforge&label=CurseForge"></a>
  <a href="https://www.curseforge.com/wow/addons/party-member-marker/files">
    <img src="https://img.shields.io/curseforge/v/1592276?logo=curseforge&label=version"></a>
  <img src="https://img.shields.io/curseforge/game-versions/1592276?label=game%20version">
</p>

---

PartyMembersMarker makes it easy to keep track of where your party members are
— especially in **arena and battlegrounds**. Each ally is marked with their
**class icon** above their nameplate, so you can spot your teammates at a glance
— without cluttering the screen with full friendly nameplates, and without
asking everyone to set raid markers.

It also keeps things tidy: **friendly** nameplates are stripped down to a clean,
name-only look (like the native "nameplates off" view), while **enemy**
nameplates are left completely untouched.

Tested in **Mists of Pandaria Classic (5.5.4)**, **Burning Crusade Classic
Anniversary (2.5.6)**, and **WoW Forever (1.60.1)**. All three clients use the
same Lua file and a client-specific TOC.

## Local installation

Run `./deploy-anniversary.sh` or `./deploy-forever.sh` from this Git checkout to
copy the Lua file and the matching TOC into the adjacent client AddOns directory.
Run the same script again after CurseForge updates the game copy. The checkout
and its Git history stay outside `AddOns`; the game copy contains only runtime
files.

Run `./package-release.sh` to build a CurseForge-ready ZIP containing one
`PartyMembersMarker` folder with the shared Lua file and all three TOCs. Upload
that one ZIP and select the supported game versions on the CurseForge file page.

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
- **Cleaner look** — the native raid target marker is hidden on friendly plates
  by default; an option restores assigned markers when needed.
- **Auto-disable friendly plates in dungeons/raids** — optional: since the game
  protects (forbids) friendly nameplates inside PvE instances so they can't be
  cleaned up, turn them off automatically on entering and restore your setting on
  leaving.
- **In-game options** — class-icon size (with a live preview), icon scope, font,
  separate name size + outline for players and NPCs, and independent switches
  for player names and guilds. Cyrillic text uses the matching Cyrillic face of
  the chosen font.

## How to use

1. Install and log in — on first run the addon **enables friendly nameplates**
   for you so it works right away (it only marks plates that are actually shown).
2. If you ever turn them off, re-enable with **Ctrl+V** — the addon only works
   while friendly nameplates are shown.
3. Your party/raid members are now marked with their class icon. Open the
   options to customize: **ESC → Options → AddOns → PartyMembersMarker**, or type
   `/pmm config`.

## Options

- **Icon size / border thickness** — adjust the class-icon diameter and the
  colored ring around it independently, with a live badge preview. Setting
  border thickness to 0 removes the visible ring.
- **Show class icon for** — All players / Party members / Raid members.
- **Show level on class icons** — optional small level badge at the lower-left
  edge of each displayed class icon. Off by default. Adjust its diameter, ring
  thickness, and font size independently with a live preview.
- **Name text** — font, plus separate name size and outline for players and NPCs.
- **Show player names / guilds** — hide either line independently; class icons
  remain visible when both are hidden. Both switches are on by default.
- **Show friendly raid markers** — display assigned skull/cross/star markers on
  friendly plates. On players with a class badge, the marker sits over its
  center; otherwise it sits above the name. Off by default to keep the arena
  view uncluttered.
- **Auto-disable friendly nameplates when the client blocks marking them with the
  class icon** — turn friendly nameplates off while inside PvE instances (where
  they can't be cleaned up) and restore your previous setting on leaving. **On by
  default.**

## Note

In some **instances** (e.g. random dungeons) the game protects friendly
nameplates so addons cannot modify them. There, party markers won't appear —
this is a client restriction, not a bug. It works in the open world and in
arenas/battlegrounds where friendly nameplates aren't protected. The
**Auto-disable friendly nameplates when the client blocks marking them with the
class icon** option (on by default) removes the resulting clutter.

## Slash commands

| Command | Description |
|---|---|
| `/pmm config` | Open the options panel. |
| `/pmm` | Debug: dump the current target's tooltip lines and nameplate info. |

## Documentation

A detailed technical overview of the architecture and rendering decisions is in
[docs/project-overview.md](docs/project-overview.md).

## Feedback

Bug reports and suggestions are welcome in the
[CurseForge comments](https://www.curseforge.com/wow/addons/party-member-marker/comments).

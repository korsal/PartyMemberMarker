# Changelog

## v1.1.2
- Fixed a Lua error ("calling 'Hide' on bad self") caused by protected (forbidden) nameplates in some instances.
- Note: in instances where the client protects friendly nameplates (e.g. random dungeons), party markers can't be shown — a client restriction, not a bug.

## v1.1.1
- Fixed the unit level number occasionally appearing next to friendly names.

## v1.1.0
- NPC names are now colored by your reputation with their faction (green / yellow / red), instead of always green.
- Added font selection (Friz Quadrata / Arial Narrow / Morpheus / Skurri).
- Name size is now configurable separately for players and NPCs.
- Outline is now configurable separately for players and NPCs.
- Options panel reorganized: a "Name text" section with font, per-type size sliders, and per-type outline toggles.

## v1.0.0 — Initial release
- Friendly nameplates turned into a clean, name-only look (enemies untouched).
- Guild line for players, occupation line for NPCs.
- Class-colored names with AFK/DND status; green for friendly NPCs.
- Class-icon badge above party/raid members (configurable scope).
- Native raid marker hidden on friendly plates.
- Options panel (/pmm config): icon size with live preview + icon scope.

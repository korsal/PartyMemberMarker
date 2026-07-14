# Changelog

## v1.2.0
- Fixed friendly plates not flipping to a normal enemy plate when a duel starts (leftover guild line + level over the enemy plate, and missing debuffs from plate-buff addons). A duel changes a unit's attackability without recreating the nameplate, so the addon now reconciles each visible plate on a light timer (plus `UNIT_FACTION`) and flips it to a normal enemy plate for the duel and back to the friendly skin when it ends.
- Fixed the health/cast bars leaking back onto friendly plates: Blizzard re-shows them on updates, so they are now kept hidden with a persistent Show hook (like the level text and raid marker).
- Fixed a cluster of tiny raid-target icons appearing on a duel opponent's plate: the native raid-target frame was being force-shown without a marker, revealing its whole icon atlas; it is no longer force-shown.
- On first install the addon now enables friendly nameplates automatically so it works out of the box (only on the very first run; a later choice to hide them is never overridden).
- Added "Auto-disable friendly nameplates when the client blocks marking them with the class icon" (on by default): turns friendly nameplates off on entering a PvE instance (where the client protects them so they can't be cleaned up) and restores your previous setting on leaving.
- Fixed the feature never taking effect on MoP Classic 5.5.4: the client has no combined `nameplateShowFriends` CVar — it's split into `nameplateShowFriendlyPlayers` and `nameplateShowFriendlyNPCs`, and both are now driven and saved/restored.
- Reworked the hide/restore into a single reconcile driven by `PLAYER_ENTERING_WORLD` (immediate + delayed), so enter and exit no longer live on separate paths that could disagree.

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

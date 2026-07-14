local PMM = {}
PMM.hidden = {}      -- [plate] = true   (we hid its bar regions)
PMM.text   = {}      -- [plate] = { name = FontString, sub = FontString }
PMM.factionStanding = {}  -- [factionName] = standingID (1-8), for NPC rep coloring

-- ---- Tunables --------------------------------------------------------------
-- Font file. nil = clone the native nameplate name font (FRIZQT__ on most
-- clients). Set a path to override, e.g. "Fonts\\MORPHEUS.TTF". Any custom
-- font must contain Cyrillic glyphs.
local FONT_FILE       = STANDARD_TEXT_FONT  -- nil = native plate font; here the locale default UI font
local NAME_SIZE       = 10         -- nil = use the native size; or a number, e.g. 14
local NAME_OUTLINE    = "OUTLINE"  -- "" / "OUTLINE" / "THICKOUTLINE" (bold effect)
-- Faux colored outline: WoW's OUTLINE flag is always black, so to get a
-- colored edge we draw copies of the text behind it in this color.
-- nil = use the plain (black) NAME_OUTLINE flag instead.
local OUTLINE_COLOR   = nil        -- e.g. {0,1,0} green, or nil
local OUTLINE_WIDTH   = 1          -- faux-outline offset, pxNAME_OUTLINE
local SHADOW          = true       -- engine-style drop shadow (matches default names)
local SUB_SIZE_DELTA  = -2         -- sub line is this much smaller than name
local VERTICAL_OFFSET = -10        -- nudge name up (+) / down (-), in px
local SHOW_CLASS_ICON = true       -- class icon above friendly *player* names
-- Who gets the class icon (future: configurable via settings):
--   "all"   - all friendly players
--   "party" - only your party members
--   "raid"  - only your raid members
local ICON_SCOPE      = "party"
local ICON_SIZE       = 48         -- class icon size, px
local ICON_GAP        = 8          -- gap between icon bottom and name top, px
local ICON_BORDER     = 4          -- class-colored rim thickness around the icon, px
-- ---------------------------------------------------------------------------

-- Configurable (via the settings panel) icon size, persisted in SavedVariables.
local ICON_SIZE_MIN = 16
local ICON_SIZE_MAX = 96

local function GetIconSize()
    return (PartyMembersMarkerDB and PartyMembersMarkerDB.iconSize) or ICON_SIZE
end

local function GetIconScope()
    return (PartyMembersMarkerDB and PartyMembersMarkerDB.iconScope) or ICON_SCOPE
end

local function GetHideFriendlyInInstance()
    return PartyMembersMarkerDB and PartyMembersMarkerDB.hideFriendlyInInstance
end

-- Name text styling (configurable via the settings panel).
local NAME_SIZE_MIN = 8
local NAME_SIZE_MAX = 24

local FONTS = {
    { key = "DEFAULT",  label = "Default (Friz Quadrata)", path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
    { key = "ARIALN",   label = "Arial Narrow",            path = "Fonts\\ARIALN.TTF" },
    { key = "MORPHEUS", label = "Morpheus",                path = "Fonts\\MORPHEUS.TTF" },
    { key = "SKURRI",   label = "Skurri",                  path = "Fonts\\SKURRI.TTF" },
}
local FONT_BY_KEY, FONT_LABEL_BY_KEY = {}, {}
for _, f in ipairs(FONTS) do FONT_BY_KEY[f.key] = f.path; FONT_LABEL_BY_KEY[f.key] = f.label end

local function GetFontKey()
    return (PartyMembersMarkerDB and PartyMembersMarkerDB.fontKey) or "DEFAULT"
end
local function GetFontFile()
    return FONT_BY_KEY[GetFontKey()] or FONT_FILE
end
local function GetPlayerNameSize()
    return (PartyMembersMarkerDB and PartyMembersMarkerDB.nameSizePlayer) or NAME_SIZE or 12
end
local function GetNPCNameSize()
    return (PartyMembersMarkerDB and PartyMembersMarkerDB.nameSizeNPC) or NAME_SIZE or 12
end
local function GetNameSizeFor(unitToken)
    if UnitIsPlayer(unitToken) then return GetPlayerNameSize() else return GetNPCNameSize() end
end
local function GetPlayerOutline()
    if PartyMembersMarkerDB and PartyMembersMarkerDB.nameOutlinePlayer ~= nil then
        return PartyMembersMarkerDB.nameOutlinePlayer
    end
    return NAME_OUTLINE ~= ""
end
local function GetNPCOutline()
    if PartyMembersMarkerDB and PartyMembersMarkerDB.nameOutlineNPC ~= nil then
        return PartyMembersMarkerDB.nameOutlineNPC
    end
    return NAME_OUTLINE ~= ""
end
local function GetOutlineFor(unitToken)
    local on = UnitIsPlayer(unitToken) and GetPlayerOutline() or GetNPCOutline()
    return on and "OUTLINE" or ""
end

-- Blizzard nameplate regions we suppress for friendly units. The native name
-- is hidden via the UpdateName hook below (we draw our own instead).
-- Regions we force show/hide in bulk. NOTE: RaidTargetFrame is deliberately NOT
-- here -- it must only ever be visible when the unit actually has a marker, so
-- force-showing it (on restore) reveals its untextured atlas (all 8 markers,
-- tiny). It's hidden for friendly plates explicitly + via a Show hook instead.
local BAR_REGIONS = { "healthBar", "castBar", "LevelFrame", "ClassificationFrame" }

local function SetRegionsShown(plate, shown)
    local uf = plate.UnitFrame
    if not uf then return end
    for _, key in ipairs(BAR_REGIONS) do
        local region = uf[key]
        if region and region.SetShown then
            region:SetShown(shown)
        end
    end
end

-- A hidden tooltip used only to read an NPC's occupation/title line.
local scanTip = CreateFrame("GameTooltip", "PMMScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function ScanLine(i)
    local line = _G["PMMScanTooltipTextLeft" .. i]
    local text = line and line:GetText()
    if text then
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then return text end
    end
    return nil
end

-- NPC occupation/title (e.g. "Bread Vendor"), normalised to "<...>".
local function GetUnitOccupation(unitToken)
    scanTip:ClearLines()
    scanTip:SetUnit(unitToken)

    for i = 2, 4 do
        local text = ScanLine(i)
        if text and text:match("^<.+>$") then
            return text
        end
    end

    local l2 = ScanLine(2)
    if l2 and not l2:match("^[Ll]evel") and not l2:match("^%d") then
        return "<" .. l2 .. ">"
    end
    return nil
end

-- Second line under the name: player guild or NPC occupation, in <...> form.
local function GetSubText(unitToken)
    if UnitIsPlayer(unitToken) then
        local guild = GetGuildInfo(unitToken)
        return guild and ("<" .. guild .. ">") or nil
    end
    return GetUnitOccupation(unitToken)
end

-- Name with the AFK/DND status prefix (UnitName/UnitPVPName don't include it).
local function GetDisplayName(unitToken)
    local name = UnitPVPName(unitToken) or UnitName(unitToken) or ""
    if UnitIsAFK(unitToken) then
        return (CHAT_FLAG_AFK or "<Away> ") .. name
    elseif UnitIsDND(unitToken) then
        return (CHAT_FLAG_DND or "<Busy> ") .. name
    end
    return name
end

-- Cache "faction name -> your standing (1-8)" so we can color an NPC by your
-- reputation with its faction (UnitReaction is "friendly" for most city NPCs
-- regardless of rep).
local buildingFactions = false
local function BuildFactionStanding()
    if buildingFactions then return end
    buildingFactions = true
    -- Expand collapsed headers so child factions are enumerable.
    local i = 1
    while i <= GetNumFactions() do
        local _, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
        if isHeader and isCollapsed then
            ExpandFactionHeader(i)
        else
            i = i + 1
        end
    end
    wipe(PMM.factionStanding)
    for j = 1, GetNumFactions() do
        local name, _, standingID, _, _, _, _, _, isHeader = GetFactionInfo(j)
        if name and standingID and not isHeader then
            PMM.factionStanding[name] = standingID
        end
    end
    buildingFactions = false
end

-- Your standing with an NPC's faction, read from its tooltip faction line.
local function GetNPCFactionStanding(unitToken)
    scanTip:ClearLines()
    scanTip:SetUnit(unitToken)
    for i = 2, 6 do
        local line = _G["PMMScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and PMM.factionStanding[text] then
            return PMM.factionStanding[text]
        end
    end
    return nil
end

local function GetNameColor(unitToken)
    if UnitIsPlayer(unitToken) then
        local _, class = UnitClass(unitToken)
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if c then return c.r, c.g, c.b end
        return 1, 1, 1              -- fallback: white
    end
    -- NPC: color by your reputation standing with its faction when known,
    -- else fall back to its reaction. 1-3 hostile, 4 neutral, 5+ friendly.
    local rank = GetNPCFactionStanding(unitToken) or UnitReaction("player", unitToken)
    if rank then
        if rank <= 3 then
            return 1, 0.1, 0.1      -- hostile / low rep: red
        elseif rank == 4 then
            return 1, 1, 0          -- neutral: yellow
        end
    end
    return 0, 1, 0                  -- friendly: green
end

-- A "label" is the main FontString plus, when OUTLINE_COLOR is set, a ring of
-- offset copies drawn behind it to fake a colored outline.
local OUTLINE_DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }

local function MakeLabel(parent, fontFile, size)
    local flag = OUTLINE_COLOR and "" or (GetPlayerOutline() and "OUTLINE" or "")
    local label = { copies = {} }

    local main = parent:CreateFontString(nil, "OVERLAY")
    if fontFile then main:SetFont(fontFile, size, flag) end
    label.main = main

    if OUTLINE_COLOR then
        for _, d in ipairs(OUTLINE_DIRS) do
            local c = parent:CreateFontString(nil, "ARTWORK")
            if fontFile then c:SetFont(fontFile, size, flag) end
            c:SetTextColor(OUTLINE_COLOR[1], OUTLINE_COLOR[2], OUTLINE_COLOR[3], 1)
            c:SetPoint("CENTER", main, "CENTER", d[1] * OUTLINE_WIDTH, d[2] * OUTLINE_WIDTH)
            label.copies[#label.copies + 1] = c
        end
    elseif SHADOW then
        main:SetShadowColor(0, 0, 0, 1)
        main:SetShadowOffset(1, -1)
    end

    return label
end

local function LabelSetText(label, text)
    label.main:SetText(text)
    for _, c in ipairs(label.copies) do c:SetText(text) end
end

local function LabelSetColor(label, r, g, b)
    label.main:SetTextColor(r, g, b)   -- copies keep the outline color
end

local function LabelShow(label)
    label.main:Show()
    for _, c in ipairs(label.copies) do c:Show() end
end

local function LabelHide(label)
    label.main:Hide()
    for _, c in ipairs(label.copies) do c:Hide() end
end

-- Apply font/size/outline to a plate's name + sub labels (and outline copies).
local function ApplyLabelFonts(t, file, nameSize, flag)
    if not file then return end
    local subSize = math.max(nameSize + SUB_SIZE_DELTA, 1)
    t.name.main:SetFont(file, nameSize, flag)
    for _, c in ipairs(t.name.copies) do c:SetFont(file, nameSize, flag) end
    t.sub.main:SetFont(file, subSize, flag)
    for _, c in ipairs(t.sub.copies) do c:SetFont(file, subSize, flag) end
end

-- Lazily build our name + sub labels, mirroring the native name's font.
local function GetText(plate)
    if PMM.text[plate] then return PMM.text[plate] end

    local uf = plate.UnitFrame
    if not uf then return nil end

    local nativeFile, nativeHeight = uf.name and uf.name:GetFont()
    local fontFile   = GetFontFile() or nativeFile
    local fontHeight = GetPlayerNameSize() or nativeHeight or 12  -- per-unit size set in ApplyFriendly

    -- Per-plate holder parented to the nameplate itself: this keeps our text
    -- on the nameplate layer (so it interleaves correctly with other plates
    -- and stays below UIParent raid/party frames). SetIgnoreParentAlpha keeps
    -- it full-opacity even when the plate's non-target fade dims the parent.
    local holder = CreateFrame("Frame", nil, plate)
    holder:SetAllPoints(plate)
    holder:SetIgnoreParentAlpha(true)

    local name = MakeLabel(holder, fontFile, fontHeight)
    name.main:SetPoint("CENTER", uf, "CENTER", 0, VERTICAL_OFFSET)

    local sub = MakeLabel(holder, fontFile, math.max(fontHeight + SUB_SIZE_DELTA, 1))
    sub.main:SetPoint("TOP", name.main, "BOTTOM", 0, -1)

    local iconSize = GetIconSize()

    -- Class-colored ring behind the icon: a solid white square (tints
    -- correctly), masked into a smooth circle, larger than the icon so its
    -- rim shows as a colored border.
    local border = holder:CreateTexture(nil, "ARTWORK", nil, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetSize(iconSize + ICON_BORDER * 2, iconSize + ICON_BORDER * 2)
    border:Hide()

    -- Class icon, sits above the name (used for friendly players only).
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    icon:SetPoint("BOTTOM", name.main, "TOP", 0, ICON_GAP)
    icon:Hide()

    border:SetPoint("CENTER", icon, "CENTER", 0, 0)

    -- Smooth both circles' hard edges with a soft circle mask.
    if holder.CreateMaskTexture then
        local iconMask = holder:CreateMaskTexture()
        iconMask:SetTexture("Interface\\Masks\\CircleMaskScalable",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        iconMask:SetAllPoints(icon)
        icon:AddMaskTexture(iconMask)

        local borderMask = holder:CreateMaskTexture()
        borderMask:SetTexture("Interface\\Masks\\CircleMaskScalable",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        borderMask:SetAllPoints(border)
        border:AddMaskTexture(borderMask)
    end

    PMM.text[plate] = { name = name, sub = sub, icon = icon, border = border }
    return PMM.text[plate]
end

-- Friendly = a unit we would not attack (friendly players and friendly NPCs).
local function IsFriendlyUnit(unitToken)
    if UnitCanAttack("player", unitToken) then
        return false
    end
    return UnitIsFriend("player", unitToken)
end

-- Whether the class icon should show for this player, per the configured scope.
local function PlayerInIconScope(unitToken)
    local scope = GetIconScope()
    if scope == "all" then
        return true
    elseif scope == "raid" then
        return UnitInRaid(unitToken) and true or false
    else -- "party"
        return UnitInParty(unitToken) and true or false
    end
end

local function ApplyFriendly(plate, unitToken)
    if not PMM.hidden[plate] then
        SetRegionsShown(plate, false)
        PMM.hidden[plate] = true
    end

    local uf = plate.UnitFrame
    if uf and uf.name then uf.name:Hide() end

    -- The native raid marker (RaidTargetFrame) is re-shown by uf:UpdateRaidTarget
    -- when the marker changes; hook its Show once per plate to keep it hidden
    -- for friendly units.
    local rt = uf and uf.RaidTargetFrame
    if rt then
        rt:Hide()   -- keep the native raid marker off friendly plates
        if not rt.pmmHooked then
            rt.pmmHooked = true
            hooksecurefunc(rt, "Show", function(self)
                if uf.unit and IsFriendlyUnit(uf.unit) then self:Hide() end
            end)
        end
    end

    -- The level text is likewise re-shown by Blizzard on updates; keep it
    -- hidden for friendly units via a per-plate Show hook.
    local lvl = uf and uf.LevelFrame
    if lvl and lvl.Show and not lvl.pmmHooked then
        lvl.pmmHooked = true
        hooksecurefunc(lvl, "Show", function(self)
            if uf.unit and IsFriendlyUnit(uf.unit) then self:Hide() end
        end)
    end

    -- Same story for the health and cast bars: Blizzard re-shows them on
    -- health/cast updates, so a one-time SetRegionsShown(false) leaks back
    -- (visible health bar over a friendly plate). Keep them hidden for friendly
    -- units with the same per-plate Show hook; enemies/duel opponents keep them.
    local hb = uf and uf.healthBar
    if hb and hb.Show and not hb.pmmHooked then
        hb.pmmHooked = true
        hooksecurefunc(hb, "Show", function(self)
            if uf.unit and IsFriendlyUnit(uf.unit) then self:Hide() end
        end)
    end
    local cb = uf and uf.castBar
    if cb and cb.Show and not cb.pmmHooked then
        cb.pmmHooked = true
        hooksecurefunc(cb, "Show", function(self)
            if uf.unit and IsFriendlyUnit(uf.unit) then self:Hide() end
        end)
    end

    local t = GetText(plate)
    if not t then return end

    -- Apply the per-unit-type font size + outline (player vs NPC).
    ApplyLabelFonts(t, GetFontFile(), GetNameSizeFor(unitToken), GetOutlineFor(unitToken))

    local r, g, b = GetNameColor(unitToken)
    LabelSetText(t.name, GetDisplayName(unitToken))
    LabelSetColor(t.name, r, g, b)
    LabelShow(t.name)

    local subText = GetSubText(unitToken)
    if subText then
        LabelSetText(t.sub, subText)
        LabelSetColor(t.sub, r, g, b)
        LabelShow(t.sub)
    else
        LabelHide(t.sub)
    end

    -- Class icon: friendly players in scope, when the class is resolved.
    local coords
    if SHOW_CLASS_ICON and UnitIsPlayer(unitToken) and PlayerInIconScope(unitToken) then
        local _, class = UnitClass(unitToken)
        coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    end
    if coords then
        t.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        t.icon:Show()
        t.border:SetVertexColor(r, g, b)   -- class color (same as the name)
        t.border:Show()
    else
        t.icon:Hide()
        t.border:Hide()
    end
end

local function RestorePlate(plate)
    if PMM.hidden[plate] then
        SetRegionsShown(plate, true)
        PMM.hidden[plate] = nil
    end
    local uf = plate.UnitFrame
    if uf and uf.name then uf.name:Show() end

    -- SetRegionsShown(true) force-shows the raid-target frame too, but it must
    -- only be visible when the unit actually has a marker assigned -- otherwise
    -- the untextured frame shows the whole raid-icon atlas (all 8 markers,
    -- tiny). Let Blizzard reset its visibility from the unit's real marker.
    if uf and uf.UpdateRaidTarget then pcall(uf.UpdateRaidTarget, uf) end

    local t = PMM.text[plate]
    if t then
        LabelHide(t.name)
        LabelHide(t.sub)
        t.icon:Hide()
        t.border:Hide()
    end
end

local function UpdateNameplate(unitToken)
    local plate = C_NamePlate.GetNamePlateForUnit(unitToken)
    if not plate then return end
    if plate.UnitFrame and plate.UnitFrame:IsForbidden() then return end  -- skip forbidden plates

    if IsFriendlyUnit(unitToken) then
        ApplyFriendly(plate, unitToken)
    else
        RestorePlate(plate)
    end
end

local function UpdateAllNameplates()
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken
        -- pcall so one bad plate can't abort the whole refresh (which left
        -- some plates stale when switching the icon scope).
        if unit then pcall(UpdateNameplate, unit) end
    end
end

-- Cheap re-classify for a single plate whose friend/enemy state can change
-- WITHOUT a NAME_PLATE_UNIT_ADDED (a duel starting/ending, PvP flagging): flip
-- it between our friendly skin and a normal plate. Only touches a plate on the
-- actual transition, so it's a no-op every other call and safe to run from the
-- frequently-fired health-color hook below.
--
-- The un-skin is gated on the POSITIVE UnitCanAttack signal (not merely "not
-- friendly"): the hook can fire before a plate's unit data is loaded, when
-- UnitCanAttack/UnitIsFriend both read false, and treating that transient as
-- "hostile" would permanently un-skin a genuinely friendly plate (no further
-- health-color update fires for an idle player to correct it).
local function ReclassifyPlate(plate, unitToken)
    if not plate or not unitToken or not UnitExists(unitToken) then return end
    if PMM.hidden[plate] then
        -- We have it skinned as friendly; only un-skin once it's actually
        -- attackable (a duel started).
        if UnitCanAttack("player", unitToken) then
            RestorePlate(plate)
        end
    elseif IsFriendlyUnit(unitToken) then
        -- Not skinned but now friendly (a duel ended) -> re-apply our skin.
        ApplyFriendly(plate, unitToken)
    end
end

-- In PvE instances the client protects (forbids) friendly nameplates, so the
-- addon can't skin them; optionally just turn friendly nameplates off there and
-- restore the previous setting on leaving. (Arena/BG plates aren't protected.)

-- CVars controlling friendly-nameplate visibility on this client. MoP Classic
-- 5.5.4 has NO combined `nameplateShowFriends` (returns nil) -- it splits into
-- separate players/NPCs CVars, so we drive both. (Confirmed via the /pmm probe.)
local FRIENDLY_NP_CVARS = { "nameplateShowFriendlyPlayers", "nameplateShowFriendlyNPCs" }

-- Restore each friendly-nameplate CVar to the value saved before we hid it.
local function RestoreFriendlyNameplates()
    local db = PartyMembersMarkerDB
    if not db or not db.hidFriendly then return end
    local saved = type(db.savedShowFriends) == "table" and db.savedShowFriends or {}
    for _, cv in ipairs(FRIENDLY_NP_CVARS) do
        pcall(SetCVar, cv, saved[cv] or "1")
    end
    db.hidFriendly = false
end

-- Single source of truth: reconcile the friendly-nameplate hide state with the
-- current zone. Hide when the option is on and we're in a party/raid instance;
-- otherwise restore. Driven by PLAYER_ENTERING_WORLD (immediate + delayed, since
-- IsInInstance() can lag right at the event), the options checkbox, and the
-- forbidden-plate hook (a backup trigger). savedShowFriends (a per-CVar table)
-- + hidFriendly live in the DB so a /reload inside the instance can't lose or
-- overwrite them.
local function ApplyInstanceNameplateState()
    local db = PartyMembersMarkerDB
    if not db then return end
    local inInstance, instType = IsInInstance()
    local shouldHide = GetHideFriendlyInInstance()
        and inInstance and (instType == "party" or instType == "raid")
    if shouldHide then
        if not db.hidFriendly then
            local saved = {}
            for _, cv in ipairs(FRIENDLY_NP_CVARS) do
                saved[cv] = GetCVar(cv) or "1"
            end
            db.savedShowFriends = saved
            db.hidFriendly = true
        end
        for _, cv in ipairs(FRIENDLY_NP_CVARS) do
            pcall(SetCVar, cv, "0")
        end
    else
        RestoreFriendlyNameplates()
    end
end

-- Resize the class icon + ring on all existing plates (called after the
-- settings slider changes). Masks track their textures via SetAllPoints.
local function RefreshIconSizes()
    local size = GetIconSize()
    for _, t in pairs(PMM.text) do
        if t.icon then t.icon:SetSize(size, size) end
        if t.border then t.border:SetSize(size + ICON_BORDER * 2, size + ICON_BORDER * 2) end
    end
end

-- Re-apply font/size/outline to all existing labels (after a text setting
-- changes), picking the player or NPC size per plate's current unit.
local function RefreshFonts()
    local file = GetFontFile()
    if not file then return end
    for plate, t in pairs(PMM.text) do
        local unit = (plate.UnitFrame and plate.UnitFrame.unit) or plate.namePlateUnitToken
        if unit then
            ApplyLabelFonts(t, file, GetNameSizeFor(unit), GetOutlineFor(unit))
        end
    end
end

------------------------------------------------------------
-- Options panel (ESC -> Options -> AddOns), built once at login.
------------------------------------------------------------
StaticPopupDialogs["PMM_RELOAD"] = {
    text = "PartyMembersMarker: reload the UI to apply the icon scope change?",
    button1 = "Reload",
    button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local optionsCategory

local function SetupOptions()
    if optionsCategory then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    -- Small left/right arrow stepper button next to a slider.
    local function MakeStepper(parent, isLeft, onClick)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(18, 18)
        local base = isLeft and "PrevPage" or "NextPage"
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. base .. "-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. base .. "-Down")
        b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. base .. "-Disabled")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", onClick)
        return b
    end

    local panel = CreateFrame("Frame")
    panel.name = "PartyMembersMarker"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PartyMembersMarker")

    -- Live preview badge (uses the player's own class). Positioned to the
    -- right of the slider below (anchored after the slider is created).
    local previewLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    previewLabel:SetText("Preview")

    local preview = CreateFrame("Frame", nil, panel)
    preview:SetSize(ICON_SIZE_MAX + ICON_BORDER * 2, ICON_SIZE_MAX + ICON_BORDER * 2)

    local pBorder = preview:CreateTexture(nil, "ARTWORK", nil, -1)
    pBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    pBorder:SetPoint("CENTER")

    local pIcon = preview:CreateTexture(nil, "ARTWORK")
    pIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    pIcon:SetPoint("CENTER")

    if preview.CreateMaskTexture then
        local mi = preview:CreateMaskTexture()
        mi:SetTexture("Interface\\Masks\\CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mi:SetAllPoints(pIcon)
        pIcon:AddMaskTexture(mi)

        local mb = preview:CreateMaskTexture()
        mb:SetTexture("Interface\\Masks\\CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mb:SetAllPoints(pBorder)
        pBorder:AddMaskTexture(mb)
    end

    local function UpdatePreview(size)
        local _, class = UnitClass("player")
        local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if coords then pIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if c then pBorder:SetVertexColor(c.r, c.g, c.b) end
        pIcon:SetSize(size, size)
        pBorder:SetSize(size + ICON_BORDER * 2, size + ICON_BORDER * 2)
    end

    -- Icon size slider with +/- arrow steppers.
    local slider = CreateFrame("Slider", "PMMIconSizeSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 24, -48)
    slider:SetWidth(220)
    slider:SetMinMaxValues(ICON_SIZE_MIN, ICON_SIZE_MAX)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    PMMIconSizeSliderLow:SetText(tostring(ICON_SIZE_MIN))
    PMMIconSizeSliderHigh:SetText(tostring(ICON_SIZE_MAX))

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        PMMIconSizeSliderText:SetText("Icon size: " .. value)
        UpdatePreview(value)
        if PartyMembersMarkerDB then
            PartyMembersMarkerDB.iconSize = value
            RefreshIconSizes()
        end
    end)
    MakeStepper(slider, true, function()
        slider:SetValue(math.max(ICON_SIZE_MIN, math.min(ICON_SIZE_MAX, GetIconSize() - 1)))
    end):SetPoint("RIGHT", slider, "LEFT", -4, 0)
    MakeStepper(slider, false, function()
        slider:SetValue(math.max(ICON_SIZE_MIN, math.min(ICON_SIZE_MAX, GetIconSize() + 1)))
    end):SetPoint("LEFT", slider, "RIGHT", 4, 0)

    -- Place the preview to the right of the slider (clearing the stepper).
    preview:SetPoint("LEFT", slider, "RIGHT", 60, 0)
    previewLabel:SetPoint("BOTTOM", preview, "TOP", 0, 8)

    -- Icon scope: show the class icon for all / party / raid (radio group).
    local scopeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scopeHeader:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -40)
    scopeHeader:SetText("Show class icon for:")

    local SCOPE_OPTIONS = {
        { value = "all",   label = "All players" },
        { value = "party", label = "Party members" },
        { value = "raid",  label = "Raid members" },
    }
    local scopeButtons = {}

    local function SyncScopeButtons()
        local scope = GetIconScope()
        for _, b in ipairs(scopeButtons) do
            b:SetChecked(b.pmmValue == scope)
        end
    end

    local prev = scopeHeader
    for i, opt in ipairs(SCOPE_OPTIONS) do
        local b = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        b.pmmValue = opt.value
        if i == 1 then
            b:SetPoint("TOPLEFT", scopeHeader, "BOTTOMLEFT", 4, -8)
        else
            b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        end
        local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", b, "RIGHT", 4, 0)
        fs:SetText(opt.label)
        b:SetScript("OnClick", function(self)
            if PartyMembersMarkerDB then
                PartyMembersMarkerDB.iconScope = self.pmmValue
            end
            SyncScopeButtons()
            -- A reload applies the scope cleanly (live refresh can lag while
            -- class data loads); offer it.
            StaticPopup_Show("PMM_RELOAD")
        end)
        scopeButtons[#scopeButtons + 1] = b
        prev = b
    end

    -- Hide friendly nameplates inside instances (where they're protected).
    local instCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    instCheck:SetPoint("TOPLEFT", scopeButtons[#scopeButtons], "BOTTOMLEFT", 0, -14)
    local instText = instCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    instText:SetPoint("LEFT", instCheck, "RIGHT", 4, 0)
    instText:SetText("Auto-disable friendly nameplates when the client blocks marking them with the class icon")
    instCheck:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if PartyMembersMarkerDB then
            PartyMembersMarkerDB.hideFriendlyInInstance = on
        end
        -- Apply right away: hide now if we're in an instance, or restore if the
        -- option was just turned off.
        ApplyInstanceNameplateState()
    end)

    -- ===== Name text styling =====
    local textHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    textHeader:SetPoint("TOPLEFT", instCheck, "BOTTOMLEFT", 0, -16)
    textHeader:SetText("Name text")

    -- Font dropdown
    local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -8)
    fontLabel:SetText("Font")
    local fontDrop = CreateFrame("Frame", "PMMFontDropdown", panel, "UIDropDownMenuTemplate")
    fontDrop:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(fontDrop, 150)
    UIDropDownMenu_Initialize(fontDrop, function(_, level)
        for _, f in ipairs(FONTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = f.label
            info.checked = (GetFontKey() == f.key)
            info.func = function()
                if PartyMembersMarkerDB then PartyMembersMarkerDB.fontKey = f.key end
                UIDropDownMenu_SetText(fontDrop, f.label)
                RefreshFonts()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Separate name-size sliders for players and NPCs.
    local function MakeSizeSlider(globalName, anchor, xoff, yoff, labelText, getter, dbKey)
        local s = CreateFrame("Slider", globalName, panel, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xoff, yoff)
        s:SetWidth(220)
        s:SetMinMaxValues(NAME_SIZE_MIN, NAME_SIZE_MAX)
        s:SetValueStep(1)
        s:SetObeyStepOnDrag(true)
        _G[globalName .. "Low"]:SetText(tostring(NAME_SIZE_MIN))
        _G[globalName .. "High"]:SetText(tostring(NAME_SIZE_MAX))
        local txt = _G[globalName .. "Text"]
        s.pmmLabel, s.pmmGetter = labelText, getter
        s:SetScript("OnValueChanged", function(_, v)
            v = math.floor(v + 0.5)
            txt:SetText(labelText .. ": " .. v)
            if PartyMembersMarkerDB then PartyMembersMarkerDB[dbKey] = v end
            RefreshFonts()
        end)
        MakeStepper(s, true, function()
            s:SetValue(math.max(NAME_SIZE_MIN, math.min(NAME_SIZE_MAX, getter() - 1)))
        end):SetPoint("RIGHT", s, "LEFT", -4, 0)
        MakeStepper(s, false, function()
            s:SetValue(math.max(NAME_SIZE_MIN, math.min(NAME_SIZE_MAX, getter() + 1)))
        end):SetPoint("LEFT", s, "RIGHT", 4, 0)
        return s
    end

    local playerSlider = MakeSizeSlider("PMMPlayerSizeSlider", fontDrop, 20, -26,
        "Player name size", GetPlayerNameSize, "nameSizePlayer")
    local npcSlider = MakeSizeSlider("PMMNPCSizeSlider", playerSlider, 0, -34,
        "NPC name size", GetNPCNameSize, "nameSizeNPC")

    -- An "Outline" checkbox to the right of each size slider (per unit type).
    local function MakeOutlineCheck(anchorSlider, getter, dbKey)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", anchorSlider, "RIGHT", 44, 0)
        local txt = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        txt:SetText("Outline")
        cb.pmmGetter = getter
        cb:SetScript("OnClick", function(self)
            if PartyMembersMarkerDB then
                PartyMembersMarkerDB[dbKey] = self:GetChecked() and true or false
            end
            RefreshFonts()
        end)
        return cb
    end

    local playerOutline = MakeOutlineCheck(playerSlider, GetPlayerOutline, "nameOutlinePlayer")
    local npcOutline    = MakeOutlineCheck(npcSlider, GetNPCOutline, "nameOutlineNPC")

    local sizeSliders = { playerSlider, npcSlider }
    local outlineChecks = { playerOutline, npcOutline }

    panel:SetScript("OnShow", function()
        local size = GetIconSize()
        slider:SetValue(size)
        PMMIconSizeSliderText:SetText("Icon size: " .. size)
        UpdatePreview(size)
        SyncScopeButtons()

        UIDropDownMenu_SetText(fontDrop, FONT_LABEL_BY_KEY[GetFontKey()] or "Default")
        for _, s in ipairs(sizeSliders) do
            local v = s.pmmGetter()
            s:SetValue(v)
            _G[s:GetName() .. "Text"]:SetText(s.pmmLabel .. ": " .. v)
        end
        for _, cb in ipairs(outlineChecks) do
            cb:SetChecked(cb.pmmGetter())
        end
        instCheck:SetChecked(GetHideFriendlyInInstance())
    end)

    optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(optionsCategory)
end

local function OpenOptions()
    if optionsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(optionsCategory:GetID())
    else
        print("|cff00ff00PartyMembersMarker|r: options panel unavailable.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("UNIT_FACTION")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        local firstRun = (PartyMembersMarkerDB == nil)
        PartyMembersMarkerDB = PartyMembersMarkerDB or {}
        if type(PartyMembersMarkerDB.iconSize) ~= "number" then
            PartyMembersMarkerDB.iconSize = ICON_SIZE
        end
        if type(PartyMembersMarkerDB.iconScope) ~= "string" then
            PartyMembersMarkerDB.iconScope = ICON_SCOPE
        end
        if type(PartyMembersMarkerDB.nameSizePlayer) ~= "number" then
            PartyMembersMarkerDB.nameSizePlayer = PartyMembersMarkerDB.nameSize or NAME_SIZE
        end
        if type(PartyMembersMarkerDB.nameSizeNPC) ~= "number" then
            PartyMembersMarkerDB.nameSizeNPC = PartyMembersMarkerDB.nameSize or NAME_SIZE
        end
        if type(PartyMembersMarkerDB.nameOutlinePlayer) ~= "boolean" then
            local d = PartyMembersMarkerDB.nameOutline
            if d == nil then d = (NAME_OUTLINE ~= "") end
            PartyMembersMarkerDB.nameOutlinePlayer = d
        end
        if type(PartyMembersMarkerDB.nameOutlineNPC) ~= "boolean" then
            local d = PartyMembersMarkerDB.nameOutline
            if d == nil then d = (NAME_OUTLINE ~= "") end
            PartyMembersMarkerDB.nameOutlineNPC = d
        end
        if type(PartyMembersMarkerDB.fontKey) ~= "string" then
            PartyMembersMarkerDB.fontKey = "DEFAULT"
        end
        if type(PartyMembersMarkerDB.hideFriendlyInInstance) ~= "boolean" then
            PartyMembersMarkerDB.hideFriendlyInInstance = true  -- on by default
        end
        -- First install: enable friendly nameplates so the addon works out of
        -- the box (it only marks/skins plates that are actually shown). Only on
        -- the very first run, so we never override a later choice to hide them.
        if firstRun then
            for _, cv in ipairs(FRIENDLY_NP_CVARS) do
                pcall(SetCVar, cv, "1")
            end
        end
        BuildFactionStanding()
        pcall(SetupOptions)
        print("|cff00ff00PartyMembersMarker|r: loaded")

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateNameplate(unit)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            RestorePlate(plate)
        end

    elseif event == "PLAYER_FLAGS_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
        -- AFK/DND toggled, or party/raid roster changed; refresh visible plates.
        UpdateAllNameplates()

    elseif event == "UNIT_NAME_UPDATE" then
        -- Name/class info just arrived for a unit; refresh its plate so the
        -- class icon can appear once the class is finally known.
        if unit then pcall(UpdateNameplate, unit) end

    elseif event == "UPDATE_FACTION" then
        -- Reputation changed; rebuild the standing cache and recolor plates.
        BuildFactionStanding()
        UpdateAllNameplates()

    elseif event == "UNIT_FACTION" then
        -- A unit's attackability/reaction changed (a duel starting or ending,
        -- PvP flagging, ...). Re-classify visible plates through the SAFE
        -- ReclassifyPlate (un-skin only on a positive UnitCanAttack), never the
        -- un-gated UpdateNameplate -- UNIT_FACTION fires often for allies and a
        -- transient "not friendly" read there would permanently un-skin a
        -- friendly plate (leaking the health bar).
        for _, plate in pairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if u then pcall(ReclassifyPlate, plate, u) end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Entered or left a zone: reconcile the hide state. IsInInstance() can
        -- lag right at the event, so re-check after a short delay too.
        ApplyInstanceNameplateState()
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, ApplyInstanceNameplateState)
        end
    end
end)

-- Blizzard re-shows the native name on every update (incl. mouseover); keep it
-- hidden for the friendly units we manage so our own text never doubles.
if CompactUnitFrame_UpdateName then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(uf)
        -- Skip forbidden plates: the client protects friendly nameplates in
        -- some instances (anti-automation), and addons can't touch them. Their
        -- mere presence is the trigger to hide friendly nameplates (if opted in).
        if not uf or uf:IsForbidden() then
            -- A forbidden friendly plate means we're in a protected PvE
            -- instance; kick the reconcile once if we haven't hidden yet
            -- (backup for the PLAYER_ENTERING_WORLD path). Guarded so we don't
            -- re-run SetCVar on every UpdateName call.
            local db = PartyMembersMarkerDB
            if db and GetHideFriendlyInInstance() and not db.hidFriendly then
                ApplyInstanceNameplateState()
            end
            return
        end
        local unit = uf.unit
        if not unit or not unit:match("^nameplate") then return end
        if uf.name and IsFriendlyUnit(unit) then
            uf.name:Hide()
        end
    end)
end

-- Duels (and PvP flagging) change a unit's attackability WITHOUT recreating the
-- nameplate, and the exact event/timing of that flip is unreliable here:
-- UNIT_FACTION / CompactUnitFrame_UpdateHealthColor can fire before
-- UnitCanAttack settles, so an event-driven re-check runs once on the stale
-- state and then never again, leaving a plate stuck half-skinned (native health
-- bar + level after a duel, or no un-skin at duel start so plate-buff addons
-- show nothing). A light periodic reconcile is the robust catch-all: every tick
-- re-check each visible plate and flip it if its friend/enemy state no longer
-- matches how we skinned it. ReclassifyPlate only does work on the actual
-- transition, so steady state is just a couple of cheap checks per plate.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.3, function()
        for _, plate in pairs(C_NamePlate.GetNamePlates()) do
            local uf = plate.UnitFrame
            if not (uf and uf:IsForbidden()) then
                local u = plate.namePlateUnitToken or (uf and uf.unit)
                if u then pcall(ReclassifyPlate, plate, u) end
            end
        end
    end)
end


-- /pmm config opens the options panel; /pmm dumps the current target's tooltip.
SLASH_PMM1 = "/pmm"
SlashCmdList["PMM"] = function(msg)
    if msg and msg:lower():match("^%s*config") then
        OpenOptions()
        return
    end
    local unit = "target"
    if not UnitExists(unit) then
        print("|cff00ff00PMM|r: no target")
        return
    end
    scanTip:ClearLines()
    scanTip:SetUnit(unit)
    print("|cff00ff00PMM|r tooltip lines for", UnitName(unit) or "?", ":")
    for i = 1, 6 do
        local line = _G["PMMScanTooltipTextLeft" .. i]
        print(i, line and line:GetText() or "<nil>")
    end

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local uf = plate and plate.UnitFrame
    local nameRegion = uf and uf.name
    if nameRegion then
        local f, h, flags = nameRegion:GetFont()
        print("|cff00ff00PMM|r native name font:", f, h, "flags:", flags == "" and "<none>" or flags)
    end
    if uf then
        for k, v in pairs(uf) do
            if type(k) == "string" and (k:lower():find("raid") or k:lower():find("target") or k:lower():find("level")) then
                print("|cff00ff00PMM|r uf field:", k, type(v))
            end
        end
    end
end


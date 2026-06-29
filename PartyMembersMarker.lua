local PMM = {}
PMM.hidden = {}      -- [plate] = true   (we hid its bar regions)
PMM.text   = {}      -- [plate] = { name = FontString, sub = FontString }

-- ---- Tunables --------------------------------------------------------------
-- Font file. nil = clone the native nameplate name font (FRIZQT__ on most
-- clients). Set a path to override, e.g. "Fonts\\MORPHEUS.TTF". Any custom
-- font must contain Cyrillic glyphs.
local FONT_FILE       = nil        -- nil = native plate font (Friz Quadrata, FRIZQT__)
local NAME_SIZE       = nil        -- nil = use the native size; or a number, e.g. 14
local NAME_OUTLINE    = "OUTLINE"  -- "" / "OUTLINE" / "THICKOUTLINE" (bold effect)
-- Faux colored outline: WoW's OUTLINE flag is always black, so to get a
-- colored edge we draw copies of the text behind it in this color.
-- nil = use the plain (black) NAME_OUTLINE flag instead.
local OUTLINE_COLOR   = nil        -- e.g. {0,1,0} green, or nil
local OUTLINE_WIDTH   = 1          -- faux-outline offset, px
local SHADOW          = true       -- engine-style drop shadow (matches default names)
local SUB_SIZE_DELTA  = -2         -- sub line is this much smaller than name
local VERTICAL_OFFSET = -10        -- nudge name up (+) / down (-), in px
local SHOW_CLASS_ICON = true       -- class icon above friendly *player* names
local ICON_SIZE       = 48         -- class icon size, px
local ICON_GAP        = 8          -- gap between icon bottom and name top, px
local ICON_BORDER     = 4          -- class-colored rim thickness around the icon, px
-- Strata for our text. Off the nameplate (so the non-target fade doesn't dim
-- it) but kept LOW so raid/party frames (MEDIUM) draw on top of it.
local TEXT_STRATA     = "BACKGROUND"
-- ---------------------------------------------------------------------------

-- Dedicated layer for all our FontStrings: a UIParent child (escapes the
-- nameplate alpha fade) at a low strata (below raid/party frames).
local layer = CreateFrame("Frame", nil, UIParent)
layer:SetFrameStrata(TEXT_STRATA)

-- Blizzard nameplate regions we suppress for friendly units. The native name
-- is hidden via the UpdateName hook below (we draw our own instead).
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

local function GetNameColor(unitToken)
    if UnitIsPlayer(unitToken) then
        local _, class = UnitClass(unitToken)
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if c then return c.r, c.g, c.b end
        return 1, 1, 1              -- fallback: white
    end
    local reaction = UnitReaction("player", unitToken)
    if reaction and reaction == 4 then
        return 1, 1, 0              -- neutral: yellow
    end
    return 0, 1, 0                  -- friendly NPC: green
end

-- A "label" is the main FontString plus, when OUTLINE_COLOR is set, a ring of
-- offset copies drawn behind it to fake a colored outline.
local OUTLINE_DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }

local function MakeLabel(fontFile, size)
    local flag = OUTLINE_COLOR and "" or NAME_OUTLINE
    local label = { copies = {} }

    -- Parent to our low-strata layer (off the nameplate) so the non-target
    -- alpha fade doesn't dim it and raid/party frames draw on top.
    local main = layer:CreateFontString(nil, "OVERLAY")
    if fontFile then main:SetFont(fontFile, size, flag) end
    label.main = main

    if OUTLINE_COLOR then
        for _, d in ipairs(OUTLINE_DIRS) do
            local c = layer:CreateFontString(nil, "ARTWORK")
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

-- Lazily build our name + sub labels, mirroring the native name's font.
local function GetText(plate)
    if PMM.text[plate] then return PMM.text[plate] end

    local uf = plate.UnitFrame
    if not uf then return nil end

    local nativeFile, nativeHeight = uf.name and uf.name:GetFont()
    local fontFile   = FONT_FILE or nativeFile
    local fontHeight = NAME_SIZE or nativeHeight or 12

    local name = MakeLabel(fontFile, fontHeight)
    name.main:SetPoint("CENTER", uf, "CENTER", 0, VERTICAL_OFFSET)

    local sub = MakeLabel(fontFile, math.max(fontHeight + SUB_SIZE_DELTA, 1))
    sub.main:SetPoint("TOP", name.main, "BOTTOM", 0, -1)

    -- Class-colored ring behind the icon: a solid white square (tints
    -- correctly), masked into a smooth circle, larger than the icon so its
    -- rim shows as a colored border.
    local border = layer:CreateTexture(nil, "ARTWORK", nil, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetSize(ICON_SIZE + ICON_BORDER * 2, ICON_SIZE + ICON_BORDER * 2)
    border:Hide()

    -- Class icon, sits above the name (used for friendly players only).
    local icon = layer:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    icon:SetPoint("BOTTOM", name.main, "TOP", 0, ICON_GAP)
    icon:Hide()

    border:SetPoint("CENTER", icon, "CENTER", 0, 0)

    -- Smooth both circles' hard edges with a soft circle mask.
    if layer.CreateMaskTexture then
        local iconMask = layer:CreateMaskTexture()
        iconMask:SetTexture("Interface\\Masks\\CircleMaskScalable",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        iconMask:SetAllPoints(icon)
        icon:AddMaskTexture(iconMask)

        local borderMask = layer:CreateMaskTexture()
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

local function ApplyFriendly(plate, unitToken)
    if not PMM.hidden[plate] then
        SetRegionsShown(plate, false)
        PMM.hidden[plate] = true
    end

    local uf = plate.UnitFrame
    if uf and uf.name then uf.name:Hide() end

    local t = GetText(plate)
    if not t then return end

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

    -- Class icon: friendly players only, when the class is resolved.
    local coords
    if SHOW_CLASS_ICON and UnitIsPlayer(unitToken) then
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

    if IsFriendlyUnit(unitToken) then
        ApplyFriendly(plate, unitToken)
    else
        RestorePlate(plate)
    end
end

local function UpdateAllNameplates()
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken
        if unit then UpdateNameplate(unit) end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("PLAYER_FLAGS_CHANGED")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00PartyMembersMarker|r: loaded")

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateNameplate(unit)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            RestorePlate(plate)
        end

    elseif event == "PLAYER_FLAGS_CHANGED" then
        -- AFK/DND toggled for some unit; refresh visible plates.
        UpdateAllNameplates()
    end
end)

-- Blizzard re-shows the native name on every update (incl. mouseover); keep it
-- hidden for the friendly units we manage so our own text never doubles.
if CompactUnitFrame_UpdateName then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(uf)
        local unit = uf and uf.unit
        if not unit or not unit:match("^nameplate") then return end
        if uf.name and IsFriendlyUnit(unit) then
            uf.name:Hide()
        end
    end)
end

-- Debug: /pmm dumps the tooltip lines of your current target.
SLASH_PMM1 = "/pmm"
SlashCmdList["PMM"] = function()
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
    local nameRegion = plate and plate.UnitFrame and plate.UnitFrame.name
    if nameRegion then
        local f, h, flags = nameRegion:GetFont()
        print("|cff00ff00PMM|r native name font:", f, h, "flags:", flags == "" and "<none>" or flags)
    end
end

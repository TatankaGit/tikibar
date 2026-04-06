local addon = TikiBar

-- ============================================================
-- Shared API Shims (Midnight-compatible)
-- ============================================================

local function TB_IsSpellKnown(spellID)
    if C_Spell and C_Spell.IsSpellKnown then
        return C_Spell.IsSpellKnown(spellID)
    end
    return IsSpellKnown(spellID)
end

local function TB_GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    local name = GetSpellInfo(spellID)
    return name
end

local function TB_FindItemInBags(itemID)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- ============================================================
-- Hearth Widget Data
-- ============================================================

-- Secondary hearthstones: items/toys with a fixed destination distinct from
-- the player's standard bind point.
-- isToy = true  → availability checked via PlayerHasToy(id)
-- isToy = false → availability checked via bag scan
-- All are used via SecureActionButton type="item" regardless of isToy.
local SECONDARY_HEARTHS = {
    { id = 140192, name = "Dalaran Hearthstone",             dest = "Dalaran (Legion)",  isToy = true  },
    { id = 110560, name = "Garrison Hearthstone",            dest = "Garrison",          isToy = true  },
    { id = 93672,  name = "Dark Portal",                     dest = "Blasted Lands",     isToy = true  },
    { id = 211788, name = "Tess's Peacebloom",               dest = "Gilneas",           isToy = true  },
    { id = 253629, name = "Personal Key to the Arcantina",   dest = "Silvermoon Inn",    isToy = true  },
}

-- Class teleport spell IDs, keyed by English class token.
-- Checked against IsSpellKnown at popup-build time; unlearned spells are omitted.
local CLASS_TELEPORTS = {
    DRUID       = { 193753  },  -- Dreamwalk
    DEATHKNIGHT = { 50977   },  -- Death Gate
    MONK        = { 126892  },  -- Zen Pilgrimage
    SHAMAN      = { 556     },  -- Astral Recall
    EVOKER      = { 361584  },  -- Return
    WARLOCK     = { 48020   },  -- Demonic Circle: Teleport
    MAGE = {
        3561,   3562,   3565,   32271,
        33836,  3563,   3567,   32276,
        33690,  33691,
        53140,  53142,
        168487, 193759,
        281404, 281403,
        344587, 468655,
    },
}


-- ============================================================
-- Clock Widget
-- ============================================================

local function CreateClockWidget()
    local clockWidget = CreateFrame("Frame", "ClockWidget", addon.bar)
    local clockText = clockWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clockText:SetPoint("CENTER")
    clockText:SetText("00:00")
    clockText:SetWidth(0)

    -- Update time text
    local function UpdateTime()
        local h, m = GetGameTime()
        clockText:SetText(string.format("%02d:%02d", h, m))
    end
    UpdateTime()
    -- Timer for updating the time text
    C_Timer.NewTicker(1, UpdateTime)

    function clockWidget:UpdateLayout()
        local padding = TikiBarDB.padding
        self:SetSize(clockText:GetStringWidth() + padding * 2, TikiBarDB.height)
        self:ClearAllPoints()
    end

    clockWidget:EnableMouse(true)

    -- Tooltip for the clock widget
    clockWidget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Server Time")
        GameTooltip:AddLine("Left-Click to open Calendar")
        GameTooltip:AddLine("Right-Click to open Timer")
        GameTooltip:Show()
    end)
    clockWidget:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Calendar and Timer links
    clockWidget:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            ToggleCalendar()
        elseif button == "RightButton" then
            Stopwatch_Toggle()
        end
    end)

    C_Timer.After(0, function()
        clockWidget:UpdateLayout()
        addon:LayoutGroups()
    end)

    return clockWidget
end

-- ============================================================
-- Specialisation Widget
-- ============================================================

local function CreateSpecWidget()
    local specWidget = CreateFrame("Frame", "SpecWidget", addon.bar)
    local specText = specWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specText:SetPoint("CENTER")
    specText:SetText("Placeholder")
    specText:SetWidth(0)

    local function UpdateSpecText()
        local specIndex = GetSpecialization()
        if specIndex then
            local _, specName = GetSpecializationInfo(specIndex)
            specText:SetText(specName)
        else
            specText:SetText("No Spec")
        end
    end

    specWidget:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    specWidget:RegisterEvent("TRAIT_CONFIG_UPDATED")
    specWidget:RegisterEvent("PLAYER_LOGIN")
    specWidget:SetScript("OnEvent", function(self, event)
        UpdateSpecText()
        self:UpdateLayout()
        addon:LayoutGroups()
    end)

    function specWidget:UpdateLayout()
        local padding = TikiBarDB.padding
        self:SetSize(specText:GetStringWidth() + padding * 2, TikiBarDB.height)
        self:ClearAllPoints()
    end

    specWidget:EnableMouse(true)

    -- Tooltip
    specWidget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Specialization")
        GameTooltip:AddLine("Left-Click to change spec", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    specWidget:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Click handler
    specWidget:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            -- Spec selection dropdown
            MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
                rootDescription:CreateTitle("Select Specialization")
                local numSpecs = GetNumSpecializations()
                for i = 1, numSpecs do
                    local specID, specName = GetSpecializationInfo(i)
                    rootDescription:CreateButton(specName, function()
                        C_SpecializationInfo.SetSpecialization(i)
                    end)
                end
            end)
        end
    end)

    C_Timer.After(0, function()
        UpdateSpecText()
        specWidget:UpdateLayout()
        addon:LayoutGroups()
    end)

    return specWidget
end

-- ============================================================
-- Hearth / Teleport Widget
-- ============================================================

local function CreateHearthWidget()
    local POPUP_W   = 220
    local ENTRY_H   = 22
    local HEADER_H  = 18
    local PAD       = 6

    local hearthWidget = CreateFrame("Frame", "HearthWidget", addon.bar)
    local hearthText = hearthWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hearthText:SetPoint("CENTER")
    hearthText:SetText("Home")
    hearthText:SetWidth(0)

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClampedToScreen(true)
    popup:Hide()
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.06, 0.06, 0.06, 0.96)
    popup:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)

    -- ── Button pool ───────────────────────────────────────────────
    local buttonPool = {}

    local function AcquireButton()
        for _, btn in ipairs(buttonPool) do
            if not btn:IsShown() then return btn end
        end
        local btn = CreateFrame("Button", nil, popup, "SecureActionButtonTemplate")
        btn:SetFrameLevel(popup:GetFrameLevel() + 2)
        btn:SetHeight(ENTRY_H)
        btn:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        btn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT",  btn, "LEFT",  8, 0)
        lbl:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(1, 1, 1)
        btn.lbl = lbl
        btn:SetScript("PostClick", function()
            popup:Hide()
        end)
        table.insert(buttonPool, btn)
        return btn
    end

    local headerPool = {}

    local function AcquireHeader()
        for _, h in ipairs(headerPool) do
            if not h:IsShown() then return h end
        end
        local h = CreateFrame("Frame", nil, popup)
        h:SetHeight(HEADER_H)
        local t = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("LEFT", h, "LEFT", 8, 0)
        t:SetTextColor(0.5, 0.5, 0.5)
        h.text = t
        table.insert(headerPool, h)
        return h
    end

    -- ── Build popup ───────────────────────────────────────────────
    local function BuildPopup()
        -- Reset all pooled frames
        for _, b in ipairs(buttonPool) do b:Hide() end
        for _, h in ipairs(headerPool) do h:Hide() end

        local rows = {}  -- { frame, height }

        local function AddHeader(text)
            local h = AcquireHeader()
            h:SetWidth(POPUP_W)
            h.text:SetText(text)
            h:Show()
            table.insert(rows, { frame = h, height = HEADER_H })
        end

        local function AddButton(labelText, actionType, actionValue)
            local btn = AcquireButton()
            btn:SetWidth(POPUP_W)
            btn.lbl:SetText(labelText)
            -- Same as Dreamwalk widget: set secure attributes directly (no macrotext /
            -- SecureHandlerExecute). Toys and hearth items use type "item" with item/toy id.
            if actionType == "item" then
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("type", "item")
                btn:SetAttribute("item", actionValue)
            elseif actionType == "spell" then
                btn:SetAttribute("item", nil)
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", actionValue)
            end
            btn:RegisterForClicks("AnyUp", "AnyDown")
            btn:Show()
            table.insert(rows, { frame = btn, height = ENTRY_H })
        end

        -- 1. Primary Hearthstone
        local toyID = TikiBarDB and TikiBarDB.hearthToyID or 0
        local primaryDest = (GetBindLocation and GetBindLocation()) or "Home"
        if toyID ~= 0 and PlayerHasToy(toyID) then
            local toyName = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(toyID)) or "Hearthstone"
            AddButton(toyName, "item", toyID)
        else
            AddButton("Hearthstone", "item", 6948)
        end

        -- 2. Secondary Hearthstones
        local secondaryAdded = false
        for _, entry in ipairs(SECONDARY_HEARTHS) do
            local available = entry.isToy and PlayerHasToy(entry.id)
                              or (not entry.isToy and TB_FindItemInBags(entry.id) ~= nil)
            if available then
                if not secondaryAdded then
                    AddHeader("Other Hearthstones")
                    secondaryAdded = true
                end
                local itemName = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id))
                                 or entry.name
                AddButton(itemName, "item", entry.id)
            end
        end

        -- 3. Class Teleport Abilities
        local _, playerClass = UnitClass("player")
        local spells = CLASS_TELEPORTS[playerClass]
        local classAdded = false
        if spells then
            for _, spellID in ipairs(spells) do
                if TB_IsSpellKnown(spellID) then
                    if not classAdded then
                        AddHeader("Class Abilities")
                        classAdded = true
                    end
                    local spellName = TB_GetSpellName(spellID) or ("Spell " .. spellID)
                    AddButton(spellName, "spell", spellID)
                end
            end
        end

        -- Stack rows top-to-bottom inside the popup
        local totalH = PAD
        for i, row in ipairs(rows) do
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -totalH)
            totalH = totalH + row.height + (i < #rows and 2 or 0)
        end
        totalH = totalH + PAD
        popup:SetSize(POPUP_W, totalH)
    end

    -- ── Widget text / layout ──────────────────────────────────────
    local function GetHearthDestText()
        return (GetBindLocation and GetBindLocation()) or "Home"
    end

    local function UpdateHearthText()
        hearthText:SetText(GetHearthDestText())
    end

    function hearthWidget:UpdateLayout()
        local padding = TikiBarDB.padding
        self:SetSize(hearthText:GetStringWidth() + padding * 2, TikiBarDB.height)
        self:ClearAllPoints()
    end

    hearthWidget:EnableMouse(true)

    hearthWidget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Hearthstone")
        GameTooltip:AddLine("Click to open teleport menu", 1, 1, 1)
        GameTooltip:Show()
    end)

    hearthWidget:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    hearthWidget:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        if popup:IsShown() then
            popup:Hide()
            return
        end
        BuildPopup()
        popup:ClearAllPoints()
        popup:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 2)
        popup:Show()
    end)

    hearthWidget:RegisterEvent("PLAYER_LOGIN")
    hearthWidget:RegisterEvent("PLAYER_ENTERING_WORLD")
    hearthWidget:SetScript("OnEvent", function(self)
        C_Timer.After(0, function()
            UpdateHearthText()
            self:UpdateLayout()
            addon:LayoutGroups()
        end)
    end)

    UpdateHearthText()
    C_Timer.After(0, function()
        hearthWidget:UpdateLayout()
        addon:LayoutGroups()
    end)

    return hearthWidget
end

-- ============================================================
-- Dreamwalk (Druid)
-- SecureActionButtonTemplate: only type/spell via SecureHandlerExecute (restricted
-- env rejects _onclick and macrotext-style attributes on SetAttribute).
-- ============================================================

local DREAMWALK_SPELL_ID = 193753

local function CreateDreamwalkWidget()
    local w = CreateFrame("Frame", "TikiBarDreamwalkWidget", addon.bar)
    w:EnableMouse(true)

    local btn = CreateFrame("Button", "TikiBarDreamwalkButton", w, "SecureActionButtonTemplate")
    btn:SetSize(100, 20)
    btn:SetPoint("CENTER")
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", DREAMWALK_SPELL_ID)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    -- Remove default button textures
    btn:SetNormalTexture("")
    btn:SetHighlightTexture("")
    btn:SetPushedTexture("")

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetAllPoints(btn)
    label:SetText("Dreamwalk")


    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(TB_GetSpellName(DREAMWALK_SPELL_ID) or "Dreamwalk", 1, 1, 1)
        GameTooltip:AddLine("Click to cast", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    function w:UpdateLayout()
        local padding = (TikiBarDB and TikiBarDB.padding) or addon.DEFAULTS.padding
        if self:IsShown() then
            self:SetSize(label:GetStringWidth() + padding * 2, TikiBarDB and TikiBarDB.height or addon.DEFAULTS.height)
        else
            self:SetSize(0, TikiBarDB and TikiBarDB.height or addon.DEFAULTS.height)
        end
        self:ClearAllPoints()
    end

    local function Refresh()
        local _, class = UnitClass("player")
        if class == "DRUID" and TB_IsSpellKnown(DREAMWALK_SPELL_ID) then
            w:Show()
            label:SetText(TB_GetSpellName(DREAMWALK_SPELL_ID) or "Dreamwalk")
        else
            w:Hide()
        end
        w:UpdateLayout()
        addon:LayoutGroups()
    end

    w:RegisterEvent("PLAYER_LOGIN")
    w:RegisterEvent("PLAYER_ENTERING_WORLD")
    w:RegisterEvent("SPELLS_CHANGED")
    w:SetScript("OnEvent", Refresh)
    Refresh()
    C_Timer.After(0, Refresh)

    return w
end


-- ============================================================
-- Widget Layout and positioning
-- ============================================================

function addon:LayoutGroups()
    local padding = TikiBarDB and TikiBarDB.padding or addon.DEFAULTS.padding
    local prev    -- local to this call; reset explicitly before each group

    -- LEFT group: build left-to-right from the bar's left edge
    prev = nil
    for _, w in ipairs(addon.widgetGroups.LEFT) do
        w:ClearAllPoints()
        if prev then
            w:SetPoint("LEFT", prev, "RIGHT", padding, 0)
        else
            w:SetPoint("LEFT", addon.bar, "LEFT", padding, 0)
        end
        w:SetPoint("TOP",    addon.bar, "TOP",    0, 0)
        w:SetPoint("BOTTOM", addon.bar, "BOTTOM", 0, 0)
        prev = w
    end

    -- RIGHT group: build right-to-left from the bar's right edge
    prev = nil
    for _, w in ipairs(addon.widgetGroups.RIGHT) do
        w:ClearAllPoints()
        if prev then
            w:SetPoint("RIGHT", prev, "LEFT", -padding, 0)
        else
            w:SetPoint("RIGHT", addon.bar, "RIGHT", -padding, 0)
        end
        w:SetPoint("TOP",    addon.bar, "TOP",    0, 0)
        w:SetPoint("BOTTOM", addon.bar, "BOTTOM", 0, 0)
        prev = w
    end

    -- CENTER group: anchor the middle widget to the bar center, build outward
    local CENTER = addon.widgetGroups.CENTER
    local count  = #CENTER

    if count > 0 then
        local midIdx = math.ceil(count / 2)

        CENTER[midIdx]:ClearAllPoints()
        CENTER[midIdx]:SetPoint("CENTER", addon.bar, "CENTER", 0, 0)

        for i = midIdx - 1, 1, -1 do
            CENTER[i]:ClearAllPoints()
            CENTER[i]:SetPoint("TOPRIGHT", CENTER[i + 1], "TOPLEFT", -padding, 0)
        end

        for i = midIdx + 1, count do
            CENTER[i]:ClearAllPoints()
            CENTER[i]:SetPoint("TOPLEFT", CENTER[i - 1], "TOPRIGHT", padding, 0)
        end
    end
end

-- ============================================================
-- Initialize and register Widgets
-- ============================================================

-- function for registering a widget to a specific anchor group
function addon:RegisterWidget(widget, anchor)
    anchor = anchor or "LEFT"
    table.insert(addon.widgetGroups[anchor], widget)
    table.insert(addon.widgets, widget)
end

function addon:InitializeWidgets()
    local clock = CreateClockWidget()
    self:RegisterWidget(clock, "CENTER")
    local spec = CreateSpecWidget()
    self:RegisterWidget(spec, "CENTER")
    -- RIGHT group: first = anchored to bar's right edge (outer corner).
    local hearth = CreateHearthWidget()
    self:RegisterWidget(hearth, "RIGHT")
    local dreamwalk = CreateDreamwalkWidget()
    self:RegisterWidget(dreamwalk, "RIGHT")
end



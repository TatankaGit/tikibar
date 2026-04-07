local addon = TikiBar

-- ============================================================
-- Hearth Widget Data
-- ============================================================

-- Secondary hearthstones: items/toys with a fixed destination distinct from
-- the player's standard bind point.
-- isToy = true  → availability checked via PlayerHasToy(id)
-- isToy = false → availability checked via bag scan
-- All are used via SecureActionButton type="item" regardless of isToy.
local SECONDARY_HEARTHS = {
    { id = 140192, name = "Dalaran Hearthstone",             dest = "Dalaran",      isToy = true  },
    { id = 110560, name = "Garrison Hearthstone",            dest = "Garrison",     isToy = true  },
    { id = 211788, name = "Tess's Peacebloom",               dest = "Gilneas",      isToy = true  },
    { id = 253629, name = "Personal Key to the Arcantina",   dest = "Arcantina",    isToy = true  },
}

-- Class teleport spell IDs, keyed by English class token.
-- Checked against IsSpellKnown at popup-build time; unlearned spells are omitted.
local CLASS_TELEPORTS = {
    DRUID       = { id = 193753, name = "Dreamwalk", dest = "Dreamwalk", isToy = false  },  -- Dreamwalk
    DEATHKNIGHT = { id = 50977, name = "Death Gate", dest = "Death Gate", isToy = false  },  -- Death Gate
    MONK        = { id = 126892, name = "Zen Pilgrimage", dest = "Zen Pilgrimage", isToy = false  },  -- Zen Pilgrimage
    SHAMAN      = { id = 556, name = "Astral Recall", dest = "Astral Recall", isToy = false  },  -- Astral Recall
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
    addon:RegisterWidgetFont(clockText)

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
    addon:RegisterWidgetFont(specText)

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
    local PAD       = addon.DEFAULTS.padding

    local hearthWidget = CreateFrame("Frame", nil, addon.bar)
    local hearthFonts = {}
    local function registerHearthFont(fs)
        table.insert(hearthFonts, fs)
        addon:RegisterWidgetFont(fs)
    end

    local hearthText = hearthWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hearthText:SetPoint("CENTER")
    hearthText:SetText("Home")
    hearthText:SetWidth(0)
    registerHearthFont(hearthText)

    local popup = CreateFrame("Frame", nil, hearthWidget, "BackdropTemplate")
    hearthWidget.popup = popup
    popup:SetSize(POPUP_W, ENTRY_H * 2 + HEADER_H + PAD * 2)
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0, 0, 0, 0.75)
    popup:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
    popup:Hide()

    -- Establish avaialble teleports/hearths and their secureactionbuttons

    local availableTeleports = {}
    local teleportButtons = {}

    table.insert(availableTeleports, {id = TikiBarDB.hearthToyID, name = TikiBarDB.hearthToyName, dest = GetBindLocation(), isToy = true})
    for _, teleport in ipairs(SECONDARY_HEARTHS) do
        if PlayerHasToy(teleport.id) then
            table.insert(availableTeleports, {id = teleport.id, name = teleport.name, dest = teleport.dest, isToy = teleport.isToy})
        end
    end
    for _, teleport in pairs(CLASS_TELEPORTS) do
        if IsSpellKnown(teleport.id) then
            table.insert(availableTeleports, {id = teleport.id, name = teleport.name, dest = teleport.dest, isToy = teleport.isToy})
        end
    end

    function hearthWidget:CreateTeleportButtons(index, teleport)
        local btn = CreateFrame("Button", nil, self.popup, "SecureActionButtonTemplate")
        btn:SetSize(100, 20)
        btn:SetPoint("TOPLEFT", self.popup, "TOPLEFT", PAD, -PAD - (index - 1) * ENTRY_H)
        btn:SetAttribute("type", teleport.isToy and "toy" or "spell")
        btn:SetAttribute(teleport.isToy and "toy" or "spell", teleport.id)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        -- Remove default button textures
        btn:SetNormalTexture("")
        btn:SetHighlightTexture("")
        btn:SetPushedTexture("")
        btn:SetScript("PostClick", function()
            popup:Hide()
        end)
    
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetAllPoints(btn)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetText(teleport.name)
        registerHearthFont(label)

        btn.label = label
        teleportButtons[index] = btn
    end

    function hearthWidget:RefreshPopupLayout()
        local maxWidth = 0
        for _, btn in ipairs(teleportButtons) do
            if btn then
                maxWidth = math.max(maxWidth, btn.label:GetStringWidth())
            end
        end
        local y = PAD
        for _, btn in ipairs(teleportButtons) do
            if not btn then break end
            local h = math.max(ENTRY_H, btn.label:GetHeight())
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -y)
            btn:SetHeight(h)
            btn:SetWidth(maxWidth + PAD * 2)
            y = y + h + 2
        end
        popup:SetSize(maxWidth + PAD * 2, y + PAD)
        popup:SetPoint("BOTTOM", hearthWidget, "TOPLEFT", 0, 0)
    end

    for i, teleport in ipairs(availableTeleports) do
        hearthWidget:CreateTeleportButtons(i, teleport)
    end

    popup:SetFrameStrata("HIGH")
    popup:EnableMouse(true)

    hearthWidget:RefreshPopupLayout()




    -- ── Widget functions ──────────────────────────────────────
    local function UpdateHearthText()
        hearthText:SetText((GetBindLocation and GetBindLocation()) or "Home")
        GameTooltip:Hide()
    end
    popup:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if popup:IsShown() then
                popup:Hide()
            else
                popup:Show()
            end
        end
    end)

    function hearthWidget:UpdateLayout()
        local padding = TikiBarDB.padding
        self:SetSize(hearthText:GetStringWidth() + padding * 2, TikiBarDB.height)
        self:ClearAllPoints()
    end

    hearthWidget:EnableMouse(true)

    -- Tooltip
    hearthWidget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Hearthstones")
        GameTooltip:AddLine("Left-Click to open teleport menu", 1, 1, 1)
        GameTooltip:Show()
    end)

    hearthWidget:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Click handler
    hearthWidget:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if popup:IsShown() then
                popup:Hide()
            else
                popup:Show()
            end
        end
    end)

    -- Event Handlers
    hearthWidget:RegisterEvent("PLAYER_LOGIN")
    hearthWidget:RegisterEvent("PLAYER_ENTERING_WORLD")
    hearthWidget:RegisterEvent("HEARTHSTONE_BOUND")
    hearthWidget:SetScript("OnEvent", function(self)
        C_Timer.After(0, function()
            UpdateHearthText()
            self:UpdateLayout()
            addon:LayoutGroups()
        end)
    end)

    -- Events only run on login/world/hearth change; after a mid-session reinit they do not fire
    -- again, so apply bind location here (same text RefreshLayout will use for width).
    UpdateHearthText()

    hearthWidget.hearthFonts = hearthFonts
    addon.hearthWidget = hearthWidget
    return hearthWidget
end

function addon:ReinitializeHearthWidget()
    local old = self.hearthWidget
    if old then
        if old.hearthFonts then
            for _, fs in ipairs(old.hearthFonts) do
                self:UnregisterWidgetFont(fs)
            end
        end
        self:RemoveWidget(old, "RIGHT")
        old:UnregisterAllEvents()
        old:SetScript("OnEvent", nil)
        old:SetScript("OnEnter", nil)
        old:SetScript("OnLeave", nil)
        old:SetScript("OnMouseUp", nil)
        old:Hide()
        old:SetParent(nil)
        self.hearthWidget = nil
    end
    local hearth = CreateHearthWidget()
    self:RegisterWidget(hearth, "RIGHT")
    self:RefreshLayout()
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
end

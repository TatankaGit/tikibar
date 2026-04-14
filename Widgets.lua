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
    { id = 193753, name = "Dreamwalk", dest = "Dreamwalk", isToy = false  },  -- Dreamwalk
    { id = 50977, name = "Death Gate", dest = "Death Gate", isToy = false  },  -- Death Gate
    { id = 126892, name = "Zen Pilgrimage", dest = "Zen Pilgrimage", isToy = false  },  -- Zen Pilgrimage
    { id = 556, name = "Astral Recall", dest = "Astral Recall", isToy = false  },  -- Astral Recall
}

local RACIAL_TELEPORTS = {
    { id = 1238686, name = "Rootwalking", dest = "The Den", isToy = false },
    { id = 265225, name = "Mole Machine", dest = "Mole Hole", isToy = false },
}

local MYTHIC_TELEPORTS = {
    { id = 393273,  name = "Algeth'ar Academy",         dest = "Algeth'ar Academy",         mapID = 402 },
    { id = 1254572, name = "Magister's Terrace",        dest = "Magister's Terrace",        mapID = 558 },
    { id = 1254559, name = "Maisara Caverns",           dest = "Maisara Caverns",           mapID = 560 },
    { id = 1254563, name = "Nexus-Point Xenas",         dest = "Nexus-Point Xenas",         mapID = 559 },
    { id = 1254555, name = "Pit of Saron",              dest = "Pit of Saron",              mapID = 556 },
    { id = 1254551, name = "Seat of the Triumvirate",   dest = "Seat of the Triumvirate",   mapID = 239 },
    { id = 159898,  name = "Skyreach",                  dest = "Skyreach",                  mapID = 161 },
    { id = 1254400, name = "Windrunner's Spire",        dest = "Windrunner's Spire",        mapID = 557 },
}

-- ============================================================
-- Clock Widget
-- ============================================================

local function CreateClockWidget()
    local clockWidget = CreateFrame("Frame", "ClockWidget", addon.bar)
    local clockText = clockWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
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
        addon:ScheduleLayoutRefresh()
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
        addon:ScheduleLayoutRefresh()
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
        addon:ScheduleLayoutRefresh()
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
    for _, teleport in ipairs(CLASS_TELEPORTS) do
        if IsSpellKnown(teleport.id) then
            table.insert(availableTeleports, {id = teleport.id, name = teleport.name, dest = teleport.dest, isToy = teleport.isToy})
        end
    end
    for _, teleport in ipairs(RACIAL_TELEPORTS) do
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
            addon:ScheduleLayoutRefresh()
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
-- Bag Widget
-- ============================================================

local function CreateBagWidget()
    local bagWidget = CreateFrame("Frame", "BagWidget", addon.bar)
    local bagText = bagWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagText:SetPoint("CENTER")
    bagText:SetWidth(0)
    addon:RegisterWidgetFont(bagText)

    -- Inline texture escape: path, height, width
    local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldMedallion:14:14|t"

    local function UpdateBagText()
        local money = GetMoney()
        local gold = math.floor(money / 10000)
        -- GetCoinTextureString handles the icon markup for you
        bagText:SetText(GetCoinTextureString(gold * 10000))
        addon:ScheduleLayoutRefresh()
    end

    function bagWidget:UpdateLayout()
        local padding = TikiBarDB.padding
        self:SetSize(bagText:GetStringWidth() + padding * 2, TikiBarDB.height)
        self:ClearAllPoints()
    end

    bagWidget:EnableMouse(true)

    -- Update whenever the player's money changes
    bagWidget:RegisterEvent("PLAYER_MONEY")
    bagWidget:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_MONEY" then
            UpdateBagText()
        end
    end)

    bagWidget:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            ToggleAllBags()
        end
    end)

    -- Populate on load
    UpdateBagText()

    return bagWidget
end


-- ============================================================
-- Mythic Widget
-- ============================================================

local function CreateMythicWidget()
    local mythicWidget = CreateFrame("Frame", "MythicWidget", addon.bar)
    local mythicText = mythicWidget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mythicText:SetPoint("CENTER")
    mythicText:SetText("Mythic")
    mythicText:SetWidth(0)
    addon:RegisterWidgetFont(mythicText)

    -- Update widget label: key info if available, else M+: score fallback
    function mythicWidget:UpdateMythicText()
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        if level and mapID then
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name then
                mythicText:SetText("Key: " .. name .. " +" .. level)
                return
            end
        end
        -- Fallback: M+: <score>
        local score = C_ChallengeMode.GetOverallDungeonScore()
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then
            local hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            mythicText:SetText("M+: " .. hex .. score .. "|r")
        else
            mythicText:SetText("M+: " .. score)
        end
    end

    function mythicWidget:UpdateLayout()
        mythicWidget:UpdateMythicText()
        local padding = TikiBarDB.padding
        self:SetSize(mythicText:GetStringWidth() + padding * 2, TikiBarDB.height)
        self:ClearAllPoints()
    end

    -- Popup creation for the mythic widget
    local POPUP_W  = 200
    local ENTRY_H  = 20
    local HEADER_H = 18
    local PAD      = addon.DEFAULTS.padding
    local popup = CreateFrame("Frame", nil, mythicWidget, "BackdropTemplate")
    mythicWidget.popup = popup
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0, 0, 0, 0.75)
    popup:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
    popup:Hide()

    -- Popup header: M+: <score>
    local headerText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -PAD)
    headerText:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PAD, -PAD)
    headerText:SetJustifyH("CENTER")
    headerText:SetHeight(HEADER_H)

    local function UpdatePopupHeader()
        local score = C_ChallengeMode.GetOverallDungeonScore()
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then
            local hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            headerText:SetText("M+: " .. hex .. score .. "|r")
        else
            headerText:SetText("M+: " .. score)
        end
    end

    -- Buttons for the popup
    local mythicButtons = {}

    function mythicWidget:CreateMythicTeleportButton(index, teleport)
        local btn = CreateFrame("Button", nil, popup, "SecureActionButtonTemplate")
        btn:SetSize(POPUP_W - PAD * 2, ENTRY_H)
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", teleport.id)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetNormalTexture("")
        btn:SetHighlightTexture("")
        btn:SetPushedTexture("")
        btn:SetScript("PostClick", function()
            popup:Hide()
        end)

        -- Left: dungeon name
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("LEFT", btn, "LEFT", 0, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetJustifyV("MIDDLE")
        nameLabel:SetText(teleport.name)
        if IsSpellKnown(teleport.id) then
            nameLabel:SetTextColor(0, 1, 0)  -- green for known spells
        end
        -- unknown spells use default GameFontNormal color

        -- Right: dungeon score (colored by rarity)
        local scoreLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scoreLabel:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        scoreLabel:SetJustifyH("RIGHT")
        scoreLabel:SetJustifyV("MIDDLE")

        local info = C_MythicPlus.GetSeasonBestForMap(teleport.mapID)
        local score = info and info.dungeonScore or 0
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then
            local hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            scoreLabel:SetText(hex .. score .. "|r")
        else
            scoreLabel:SetText(tostring(score))
        end

        btn.nameLabel  = nameLabel
        btn.scoreLabel = scoreLabel
        mythicButtons[index] = btn
    end

    function mythicWidget:RefreshMythicPopupLayout()
        UpdatePopupHeader()
        local y = PAD + HEADER_H + PAD
        for _, btn in ipairs(mythicButtons) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -y)
            btn:SetWidth(POPUP_W - PAD * 2)
            btn:SetHeight(ENTRY_H)
            y = y + ENTRY_H + 2
        end
        popup:SetSize(POPUP_W, y + PAD)
        popup:SetPoint("BOTTOM", mythicWidget, "TOPLEFT", 0, 0)
    end

    for i, teleport in ipairs(MYTHIC_TELEPORTS) do
        mythicWidget:CreateMythicTeleportButton(i, teleport)
    end

    mythicWidget:RefreshMythicPopupLayout()
    popup:SetFrameStrata("HIGH")
    popup:EnableMouse(true)

    mythicWidget:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if popup:IsShown() then
                popup:Hide()
            else
                popup:Show()
            end
        end
    end)

    -- Refresh label and header on relevant events
    mythicWidget:RegisterEvent("PLAYER_ENTERING_WORLD")
    mythicWidget:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    mythicWidget:RegisterEvent("CHALLENGE_MODE_RESET")
    mythicWidget:SetScript("OnEvent", function(self)
        C_Timer.After(0, function()
            addon:ScheduleLayoutRefresh()
        end)
    end)

    mythicWidget:EnableMouse(true)
    mythicWidget:UpdateLayout()
    return mythicWidget
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
    local mythic = CreateMythicWidget()
    self:RegisterWidget(mythic, "CENTER")
    local clock = CreateClockWidget()
    self:RegisterWidget(clock, "CENTER")
    local spec = CreateSpecWidget()
    self:RegisterWidget(spec, "CENTER")
    -- RIGHT group: first = anchored to bar's right edge (outer corner).
    local bags = CreateBagWidget()
    self:RegisterWidget(bags, "RIGHT")
    local hearth = CreateHearthWidget()
    self:RegisterWidget(hearth, "RIGHT")
end
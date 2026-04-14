-- TikiBar.lua
-- Displays a thin bar at the bottom of the screen with server time.
-- Bar height is configurable via the addon settings panel.

TikiBar = TikiBar or {}
local addon = TikiBar

addon.ADDON_NAME  = "TikiBar"
addon.ADDON_TITLE = "Tiki Bar"
addon.DEFAULTS    = { 
    height = 24,
    padding = 6,
    fontSize = 12,
    hearthToyID = 0,
    hearthToyName = "Hearthstone",
    DisableMicroMenu = true,
}
addon.widgets = {}
addon.widgetFonts = {}
addon.widgetGroups = {
    LEFT = {},
    CENTER = {},
    RIGHT = {}
}
addon.HEARTH_TOY_OPTIONS = {
    -- Standard
    { id = 0,      name = "Standard Hearthstone"               },  -- item 6948, handled separately
    -- World Event / Seasonal
    { id = 166747, name = "Brewfest Reveler's Hearthstone"     },  -- Brewfest
    { id = 166746, name = "Fire Eater's Hearthstone"           },  -- Brewfest
    { id = 162973, name = "Greatfather Winter's Hearthstone"   },  -- Winter Veil
    { id = 163045, name = "Headless Horseman's Hearthstone"    },  -- Hallow's End
    { id = 165669, name = "Lunar Elder's Hearthstone"          },  -- Lunar New Year
    { id = 165802, name = "Noble Gardener's Hearthstone"       },  -- Noblegarden
    { id = 165670, name = "Peddlefeet's Lovely Hearthstone"    },  -- Love is in the Air
    -- Expansion / Reputation / Achievement
    { id = 54452,  name = "Ethereal Portal"                    },  -- Archaeology (Outland)
    { id = 64488,  name = "The Innkeeper's Daughter"           },  -- Archaeology
    { id = 142542, name = "Tome of Town Portal"                },  -- Diablo 20th anniversary
    { id = 172179, name = "Eternal Traveler's Hearthstone"     },  -- Shadowlands CE / upgrade
    { id = 190196, name = "Enlightened Hearthstone"            },  -- Zereth Mortis rep
    { id = 190237, name = "Broker Translocation Matrix"        },  -- Zereth Mortis rep 
    { id = 188952, name = "Dominated Hearthstone"              },  -- Sanctum of Domination
    { id = 193588, name = "Timewalker's Hearthstone"           },  -- Trading Post         
    { id = 168907, name = "Holographic Digitalization Hearthstone" },  -- BfA engineering  
    { id = 200630, name = "Ohn'ir Windsage's Hearthstone"      },  -- Dragonflight achievement
    { id = 206195, name = "Path of the Naaru"                  },  -- Dragonflight Lightforged
    { id = 208704, name = "Deepdweller's Earthen Hearthstone"  },  -- Dragonflight
    { id = 209035, name = "Hearthstone of the Flame"           },  -- Dragonflight
    { id = 212337, name = "Stone of the Hearth"                },  -- TWW
    { id = 228940, name = "Notorious Thread's Hearthstone"     },  -- TWW
    { id = 235016, name = "Redeployment Module"                },  -- TWW
    { id = 236687, name = "Explosive Hearthstone"              },  -- TWW
    -- Shadowlands Covenant (only usable while pledged to matching covenant)
    { id = 184353, name = "Kyrian Hearthstone"                 },  
    { id = 182773, name = "Necrolord Hearthstone"              },
    { id = 180290, name = "Night Fae Hearthstone"              },
    { id = 183716, name = "Venthyr Sinstone"                   },
    -- Racial
    { id = 210455, name = "Draenic Hologem"                    },  -- Draenei / Lightforged only
}


-- ============================================================
-- Bar frame
-- ============================================================

local bar = CreateFrame("Frame", "TikiBarFrame", UIParent, "BackdropTemplate")
addon.bar = bar
bar:SetPoint("BOTTOMLEFT",  UIParent, "BOTTOMLEFT",  0, 0)
bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
bar:SetHeight(addon.DEFAULTS.height)
bar:SetFrameStrata("MEDIUM")

-- Dark semi-transparent background
bar:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
bar:SetBackdropColor(0, 0, 0, 0.75)
bar:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)


-- ============================================================
-- Hide the Blizzard bag bar and micro menu, and suppress any attempts
-- by Blizzard's layout code to show them again.
-- ============================================================
local suppressedFrames = {}
local forcedVisibleFrames = {}

function addon:SuppressFrame(frame)
    if not frame then return end
    forcedVisibleFrames[frame] = nil  -- clear any force-visible state
    frame:Hide()
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    if not suppressedFrames[frame] then
        hooksecurefunc(frame, "Show", function(f)
            if suppressedFrames[f] then
                f:Hide()
                f:SetAlpha(0)
            end
        end)
        hooksecurefunc(frame, "Hide", function(f)
            if forcedVisibleFrames[f] then
                f:Show()
                f:SetAlpha(1)
            end
        end)
    end
    suppressedFrames[frame] = true
end

function addon:UnsuppressFrame(frame)
    if not frame then return end
    suppressedFrames[frame] = nil
    forcedVisibleFrames[frame] = true
    frame:SetAlpha(1)
    frame:EnableMouse(true)
    frame:Show()
end


-- ============================================================
-- Initialisation (runs after SavedVariables are loaded)
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon.ADDON_NAME then return end

        -- Initialise DB, preserving any saved values and setting default values for nil keys
        TikiBarDB = TikiBarDB or {}
        for k, v in pairs(addon.DEFAULTS) do
            if TikiBarDB[k] == nil then
                TikiBarDB[k] = v
            end
        end

        -- Build the settings panel now that the DB is ready
        TikiBar_BuildSettings()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- Initialize the bar
        bar:SetHeight(TikiBarDB.height)
        addon:InitializeWidgets()
        addon:RefreshLayout()
        addon:SuppressFrame(BagsBar)
        if TikiBarDB.DisableMicroMenu then
            addon:SuppressFrame(MicroMenu)
        else
            addon:UnsuppressFrame(MicroMenu)
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    end

end)

-- ============================================================
-- Refresh the bar and rerender
-- ============================================================

function addon:RegisterWidgetFont(fontString)
    table.insert(self.widgetFonts, fontString)
    self:ApplyWidgetFontSize(fontString)
end

function addon:UnregisterWidgetFont(fontString)
    for i = #self.widgetFonts, 1, -1 do
        if self.widgetFonts[i] == fontString then
            table.remove(self.widgetFonts, i)
            break
        end
    end
end

function addon:RemoveWidget(widget, anchor)
    anchor = anchor or "LEFT"
    local group = self.widgetGroups[anchor]
    for i = #group, 1, -1 do
        if group[i] == widget then
            table.remove(group, i)
            break
        end
    end
    for i = #self.widgets, 1, -1 do
        if self.widgets[i] == widget then
            table.remove(self.widgets, i)
            break
        end
    end
end

function addon:ApplyWidgetFontSize(fontString)
    local font, _, flags = fontString:GetFont()
    if not font then return end
    local size = (TikiBarDB and TikiBarDB.fontSize) or self.DEFAULTS.fontSize
    fontString:SetFont(font, size, flags)
end

function addon:RefreshWidgetFonts()
    for _, fs in ipairs(self.widgetFonts) do
        self:ApplyWidgetFontSize(fs)
    end
    if self.hearthWidget and self.hearthWidget.RefreshPopupLayout then
        self.hearthWidget:RefreshPopupLayout()
    end
    if self.mythicWidget and self.mythicWidget.RefreshPopupLayout then
        self.mythicWidget:RefreshPopupLayout()
    end
    self:RefreshLayout()
end

function addon:RefreshLayout()
    for _, widget in ipairs(self.widgets) do
        widget:UpdateLayout()
    end
    self:LayoutGroups()
end

function addon:ScheduleLayoutRefresh()
    if self._layoutPending then return end
    self._layoutPending = true
    C_Timer.After(0, function()
        self._layoutPending = false
        self:RefreshLayout()
    end)
end
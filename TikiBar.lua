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
    hearthToyID = 0,
}
addon.widgets = {}
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
-- Initialisation (runs after SavedVariables are loaded)
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= addon.ADDON_NAME then return end

    -- Initialise DB, preserving any saved values and setting default values for nil keys
    TikiBarDB = TikiBarDB or {}
    for k, v in pairs(addon.DEFAULTS) do
        if TikiBarDB[k] == nil then
            TikiBarDB[k] = v
        end
    end

    -- Initialize the bar
    bar:SetHeight(TikiBarDB.height)
    -- Hide the Blizzard bag bar and micro menu, and suppress any attempts
    -- by Blizzard's layout code to show them again.
    local function HideAndSuppressFrame(frame)
        if not frame then return end
        frame:Hide()
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        hooksecurefunc(frame, "Show", function(self)
            self:Hide()
            self:SetAlpha(0)
        end)
    end

    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function(self)
        HideAndSuppressFrame(BagsBar)
        HideAndSuppressFrame(MicroMenu)
        self:UnregisterEvent("PLAYER_LOGIN")
    end)

    addon:InitializeWidgets()
    addon:RefreshLayout()


    -- Build the settings panel now that the DB is ready
    TikiBar_BuildSettings()

    self:UnregisterEvent("ADDON_LOADED")
end)

-- ============================================================
-- Refresh the bar and rerender
-- ============================================================

function addon:RefreshLayout()
    for _, widget in ipairs(self.widgets) do
        widget:UpdateLayout()
    end
    self:LayoutGroups()
end
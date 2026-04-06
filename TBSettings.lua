local addon = TikiBar


-- ============================================================
-- Settings panel  (Dragonflight+ Vertical Layout Settings API)
-- ============================================================

function TikiBar_BuildSettings()
    local category = Settings.RegisterVerticalLayoutCategory(addon.ADDON_TITLE)

    -- ============================================================
    -- Bar Height Slider
    -- ============================================================
    do
        local name = "Bar Height"
        local variable = "Height_Slider"
        local defaultValue = addon.DEFAULTS.height
        local minValue = 12
        local maxValue = 48
        local step = 1

        local function GetValue()
            return TikiBarDB and TikiBarDB.height or addon.DEFAULTS.height
        end

        local function SetValue(value)
            TikiBarDB.height = value
            addon.bar:SetHeight(value)
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)

        local tooltip = "Adjust the pixel height of TikiBar."
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, tooltip)
    end

    -- ============================================================
    -- Widget Padding Slider
    -- ============================================================
    do
        local name = "Widget Padding"
        local variable = "Padding_Slider"
        local defaultValue = addon.DEFAULTS.padding
        local minValue = 0
        local maxValue = 16
        local step = 1

        local function GetValue()  
            return TikiBarDB and TikiBarDB.padding or addon.DEFAULTS.padding
        end

        local function SetValue(value)
            TikiBarDB.padding = value
            addon:RefreshLayout()
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)

        local tooltip = "Adjust the padding between widgets."
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, tooltip)
    end

    -- ============================================================
    -- Preferred Hearthstone Dropdown
    -- ============================================================
    do
        local name         = "Preferred Hearthstone"
        local variable     = "HearthToy_Dropdown"
        local defaultValue = addon.DEFAULTS.hearthToyID  -- 0

        local function GetValue()
            return TikiBarDB and TikiBarDB.hearthToyID or 0
        end

        local function SetValue(value)
            TikiBarDB.hearthToyID = value
        end

        local setting = Settings.RegisterProxySetting(
            category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue
        )

        local function BuildOptions()
            local container = Settings.CreateControlTextContainer()
            for _, opt in ipairs(addon.HEARTH_TOY_OPTIONS) do
                container:Add(opt.id, opt.name)
            end
            return container:GetData()
        end

        local tooltip = "Choose a cosmetic hearthstone toy to use in place of the standard "
                     .. "Hearthstone. The toy must be in your collection for it to work; "
                     .. "if it is not owned, the standard Hearthstone will be used as a fallback."
        Settings.CreateDropdown(category, setting, BuildOptions, tooltip)
    end
    

    Settings.RegisterAddOnCategory(category)
end